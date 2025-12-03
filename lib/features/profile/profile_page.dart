import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/widgets/app_nav_bar.dart';
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
  /// URL locale (con cache bust) dell’avatar appena caricato.
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _avatarUrl = user?.photoURL;
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

      // 1) Scegli immagine
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

      // 2) Bytes + metadata
      final Uint8List bytes = await picked.readAsBytes();

      // Bucket corretto preso dalla console Storage
      const String targetBucket = 'pan-nativa-progetto.firebasestorage.app';

      // Istanziamo FirebaseStorage puntando esplicitamente a quel bucket
      final FirebaseStorage storage = FirebaseStorage.instanceFor(bucket: targetBucket);

      // ref sul percorso public_profiles/<uid>/avatar.jpg
      final ref = storage
          .ref()
          .child('public_profiles')
          .child(user.uid)
          .child('avatar.jpg');

      // metadata (content-type)
      final metadata = SettableMetadata(
        contentType: _inferContentType(picked.name),
      );

      // log di debug utili
      final configuredBucket = Firebase.app().options.storageBucket;
      debugPrint('[PROFILE] storage bucket configured=$configuredBucket');
      debugPrint('[AVATAR] storage bucket=${storage.bucket}');
      debugPrint('[PROFILE] upload to ${ref.fullPath} contentType=${metadata.contentType} size=${bytes.lengthInBytes}');

      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'Invio a ${ref.fullPath}',
        success: true,
        category: 'storage',
      );

      // 3) Upload
      try {
        debugPrint('Upload avatar: inizio');
        debugPrint('Upload avatar: bucket=${ref.bucket} path=${ref.fullPath}');

        final task = ref.putData(bytes, metadata);

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

      // 4) URL di download
      final url = await ref.getDownloadURL();
      debugPrint('[PROFILE] got URL: $url');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'URL ottenuto',
        success: true,
        category: 'storage',
      );

      // 5) Aggiorna Auth + Firestore (public profile consigliato)
      await user.updatePhotoURL(url);

      await Future.wait([
        _db.collection('public_profiles').doc(user.uid).set({
          'avatarUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        _db.collection('users').doc(user.uid).set({
          'photoURL': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);

      debugPrint('[PROFILE] auth+firestore (private+public) updated');
      SyncStatusController.instance.add(
        title: 'Upload immagine',
        message: 'Profilo aggiornato online',
        success: true,
        category: 'storage',
      );

      // 6) Refresh UI e cache-busting
      await user.reload();
      if (!mounted) return;
      setState(() {
        _avatarUrl = '$url?ts=${DateTime.now().millisecondsSinceEpoch}';
      });
      _snack('Immagine profilo aggiornata.');
    } on FirebaseException catch (e) {
      debugPrint(
          '[PROFILE][FIREBASE-ERROR] code=${e.code} message=${e.message}');
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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

        final docRef = _db.collection('public_profiles').doc(user.uid);
        return StreamBuilder<DocumentSnapshot>(
          stream: docRef.snapshots(),
          builder: (context, sDoc) {
            final data = (sDoc.data?.data() as Map<String, dynamic>?) ?? {};
            final String firestoreAvatar =
                (data['avatarUrl'] is String && (data['avatarUrl'] as String).trim().isNotEmpty)
                    ? (data['avatarUrl'] as String).trim()
                    : '';
            final String displayAvatar = _avatarUrl ??
                (firestoreAvatar.isNotEmpty
                    ? firestoreAvatar
                    : (user.photoURL ?? ''));

            final String photoUrl = displayAvatar;

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
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceVariant,
                          backgroundImage: (photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 48,
                                )
                              : null,
                        ),
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
              bottomNavigationBar:
                  const AppNavBar(currentIndex: 4),
            );
          },
        );
      },
    );
  }
}

String _inferContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'application/octet-stream';
}
