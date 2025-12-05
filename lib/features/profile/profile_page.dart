import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/widgets/app_nav_bar.dart';
import '../../app/widgets/profile_avatar.dart';
import '../../utils/sync_status.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickAndUpload() async {
    final user = _auth.currentUser;
    if (user == null) {
      _snack('Devi essere autenticato.');
      SyncStatusController.instance.add(
        title: 'Check login',
        message: 'Current user: nessuno',
        success: false,
        category: 'auth',
      );
      return;
    }

    try {
      setState(() => _busy = true);
      debugPrint('[PROFILE] start pick');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'Current user: ${user.uid}',
        success: true,
        category: 'storage',
      );

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (picked == null) {
        debugPrint('[PROFILE] pick cancelled');
        _snack('Selezione annullata.');
        SyncStatusController.instance.add(
          title: 'Upload immagine',
          message: 'Selezione annullata',
          success: false,
          category: 'storage',
        );
        return;
      }

      debugPrint('[PROFILE] picked: name=${picked.name}, bytes?');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'File scelto: ${picked.name}',
        success: true,
        category: 'storage',
      );

      final Uint8List bytes = await picked.readAsBytes();
      final _StandardAvatar avatar = await _standardizeAvatar(bytes);

      final bucket = Firebase.app().options.storageBucket;

      final FirebaseStorage storage = (bucket != null && bucket.isNotEmpty)
          ? FirebaseStorage.instanceFor(bucket: bucket)
          : FirebaseStorage.instance;

      final ref = storage
          .ref()
          .child('public_profiles')
          .child(user.uid)
          .child('avatar.png');

      final metadata = SettableMetadata(contentType: 'image/png');

      debugPrint('[AVATAR] storage bucket=${storage.bucket}');
      debugPrint(
        '[PROFILE] upload to ${ref.fullPath} contentType=${metadata.contentType} size=${avatar.bytes.lengthInBytes}',
      );

      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'Invio a ${ref.fullPath}',
        success: true,
        category: 'storage',
      );

      try {
        final task = ref.putData(avatar.bytes, metadata);

        task.snapshotEvents.listen(
          (s) {
            final total = (s.totalBytes == 0 ? 1 : s.totalBytes);
            final pct =
                (s.bytesTransferred / total * 100).toStringAsFixed(0);
            debugPrint(
              '[PROFILE] upload state=${s.state} $pct% '
              '(${s.bytesTransferred}/$total)',
            );
          },
          onError: (Object e, StackTrace st) {
            debugPrint('[PROFILE] upload error: $e');
          },
        );

        await task.whenComplete(() => null);
        debugPrint('Upload avatar: COMPLETATO');

        SyncStatusController.instance.add(
          title: 'Upload immagine',
          message: 'Upload completato',
          success: true,
          category: 'storage',
        );
      } on FirebaseException catch (e) {
        debugPrint('ERRORE UPLOAD AVATAR: ${e.code} - ${e.message}');
        SyncStatusController.instance.add(
          title: 'Upload immagine',
          message: 'Errore upload: ${e.code} (bucket ${ref.bucket})',
          success: false,
          category: 'storage',
        );
        rethrow;
      }

      final url = await ref.getDownloadURL();
      debugPrint('[PROFILE] got URL: $url');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'URL ottenuto',
        success: true,
        category: 'storage',
      );

      await user.updatePhotoURL(url);

      await Future.wait([
        _db.collection('public_profiles').doc(user.uid).set(
          {
            'avatarUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
        _db.collection('users').doc(user.uid).set(
          {
            'photoURL': url,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
      ]);

      debugPrint('[AVATAR-UPLOAD] uid=${user.uid} url=$url bucket=${ref.bucket} path=${ref.fullPath}');

      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'Profilo aggiornato online',
        success: true,
        category: 'storage',
      );

      ProfileAvatar.invalidate(user.uid);

      await user.reload();
      if (!mounted) return;
      _snack('Immagine profilo aggiornata.');
    } on FirebaseException catch (e) {
      debugPrint('[PROFILE][FIREBASE-ERROR] code=${e.code} message=${e.message}');
      final hint = (e.code == 'permission-denied' ||
              e.code == 'unauthorized')
          ? 'Autorizzazione negata: verifica che le regole Firebase permettano a ${_auth.currentUser?.uid} '
              'di scrivere in public_profiles/${_auth.currentUser?.uid}.'
          : (e.message ?? e.code);
      _snack('Errore Firebase: $hint');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: hint,
        success: false,
        category: 'storage',
      );
    } catch (e) {
      debugPrint('[PROFILE][ERROR] $e');
      _snack('Errore: $e');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: e.toString(),
        success: false,
        category: 'storage',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<_StandardAvatar> _standardizeAvatar(Uint8List source) async {
    final codec = await ui.instantiateImageCodec(source);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    codec.dispose();

    if (byteData == null) {
      throw Exception('Impossibile convertire l\'immagine');
    }

    return _StandardAvatar(
      bytes: byteData.buffer.asUint8List(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, sAuth) {
        final user = sAuth.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profilo')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Accedi per gestire il profilo.'),
              ),
            ),
            bottomNavigationBar: const AppNavBar(currentIndex: 4),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profilo')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SyncStatusPanel(title: 'Controlli online'),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  children: [
                    ProfileAvatar(uid: user.uid, radius: 54),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: FloatingActionButton.small(
                        heroTag: 'edit_photo',
                        onPressed: _busy ? null : _pickAndUpload,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.email ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Modifica immagine profilo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Seleziona un’immagine dalla Galleria'),
            ],
          ),
          bottomNavigationBar: const AppNavBar(currentIndex: 4),
        );
      },
    );
  }
}

class _StandardAvatar {
  final Uint8List bytes;

  const _StandardAvatar({
    required this.bytes,
  });
}
