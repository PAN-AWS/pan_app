import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

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
  bool _diagnosticRunning = false;
  String? _lastDiagnosedUid;
  String? _lastAvatarBaseUrl;
  int _lastAvatarUpdateTs = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  FirebaseStorage _storageForConfiguredBucket({bool logWarnings = false}) {
    final bucket = Firebase.app().options.storageBucket;
    if (logWarnings) {
      if (bucket == null || bucket.isEmpty) {
        SyncStatusController.instance.add(
          title: 'Bucket guard',
          message: 'Bucket non configurato, uso default instance',
          success: false,
          category: 'avatar',
        );
      } else if (kDebugMode && !bucket.endsWith('.appspot.com')) {
        SyncStatusController.instance.add(
          title: 'Bucket guard',
          message: 'Bucket configurato non canonico: $bucket',
          success: false,
          category: 'avatar',
        );
      }
    }

    return FirebaseStorage.instance;
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

      final FirebaseStorage storage = _storageForConfiguredBucket();

      final ref = storage
          .ref()
          .child('public_profiles')
          .child(user.uid)
          .child('avatar.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');

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

        await task;
      } on FirebaseException catch (e) {
        debugPrint('ERRORE UPLOAD AVATAR: ${e.code} - ${e.message}');
        SyncStatusController.instance.add(
          title: 'Upload immagine',
          message: 'Errore upload: ${e.code} - ${e.message ?? ''}',
          success: false,
          category: 'storage',
        );
        rethrow;
      }

      await _cleanupLegacyAvatars(storage: storage, uid: user.uid);

      debugPrint('Upload avatar: COMPLETATO');

      SyncStatusController.instance.add(
        title: 'Upload avatar: COMPLETATO',
        message: 'Upload riuscito su ${ref.fullPath}',
        success: true,
        category: 'storage',
      );

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
      if (mounted) {
        setState(() {
          _lastAvatarUpdateTs = DateTime.now().millisecondsSinceEpoch;
        });
      }

      await _runAvatarDiagnostics(user);

      await user.reload();
      if (!mounted) return;
      _snack('Immagine profilo aggiornata.');
    } on FirebaseException catch (e) {
      debugPrint('[PROFILE][FIREBASE-ERROR] code=${e.code} message=${e.message}');
      final hint = (e.code == 'permission-denied' ||
              e.code == 'unauthorized')
          ? 'Autorizzazione negata: verifica che le regole Firebase permettano a ${_auth.currentUser?.uid} '
              'di scrivere in public_profiles/${_auth.currentUser?.uid}.'
          : '${e.code}: ${e.message ?? e.code}';
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
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw Exception('Impossibile convertire l\'immagine');
    }

    final jpegBytes = img.encodeJpg(decoded, quality: 88);

    return _StandardAvatar(
      bytes: Uint8List.fromList(jpegBytes),
    );
  }

  Future<void> _runAvatarDiagnostics(User user) async {
    if (_diagnosticRunning) return;
    _diagnosticRunning = true;
    _lastDiagnosedUid = user.uid;
    try {
      if (mounted) {
        setState(() {
          _lastAvatarBaseUrl = null;
        });
      }
      final configuredBucket = Firebase.app().options.storageBucket ?? '(default)';
      final storage = _storageForConfiguredBucket(logWarnings: true);
      final runtimeBucket = storage.bucket;
      final ref = storage
          .ref()
          .child('public_profiles')
          .child(user.uid)
          .child('avatar.jpg');

      SyncStatusController.instance.add(
        title: 'Avatar check (storage)',
        message:
            'Bucket configurato: $configuredBucket | runtime: $runtimeBucket | path: ${ref.fullPath}',
        success: true,
        category: 'avatar',
      );

      try {
        final metadata = await ref.getMetadata();
        SyncStatusController.instance.add(
          title: 'Metadata check',
          message:
              'contentType=${metadata.contentType ?? 'n/d'} size=${metadata.size ?? 0}',
          success: true,
          category: 'avatar',
        );
      } on FirebaseException catch (e) {
        SyncStatusController.instance.add(
          title: 'Metadata check',
          message: 'Errore: ${e.code}',
          success: false,
          category: 'avatar',
        );
      }

      String? baseUrl;
      try {
        baseUrl = await ref.getDownloadURL();
        if (mounted) {
          setState(() {
            _lastAvatarBaseUrl = baseUrl;
          });
        }
        SyncStatusController.instance.add(
          title: 'URL base check',
          message: 'URL ottenuto: $baseUrl',
          success: true,
          category: 'avatar',
        );
      } on FirebaseException catch (e) {
        SyncStatusController.instance.add(
          title: 'URL base check',
          message: 'Errore: ${e.code}',
          success: false,
          category: 'avatar',
        );
      }

      if (baseUrl == null || baseUrl.isEmpty) {
        SyncStatusController.instance.add(
          title: 'Precache check (base)',
          message: 'URL non disponibile',
          success: false,
          category: 'avatar',
        );
        return;
      }

      final baseUri = Uri.parse(baseUrl);
      final cbUrl = baseUri
          .replace(queryParameters: {...baseUri.queryParameters, 'cb': DateTime.now().millisecondsSinceEpoch.toString()})
          .toString();

      SyncStatusController.instance.add(
        title: 'URL cb check',
        message: 'URL con cache-buster: $cbUrl',
        success: true,
        category: 'avatar',
      );

      await _runUrlChecks(label: 'URL base', url: baseUrl);
      await _runUrlChecks(label: 'URL cb', url: cbUrl);
    } finally {
      _diagnosticRunning = false;
    }
  }

  Future<void> _runUrlChecks({required String label, required String url}) async {
    try {
      final uri = Uri.parse(url);
      final bundle = NetworkAssetBundle(uri);
      final data = await bundle.load(url);
      SyncStatusController.instance.add(
        title: '$label HTTP fetch check',
        message: 'Scaricati ${data.lengthInBytes} byte',
        success: true,
        category: 'avatar',
      );
    } catch (e) {
      SyncStatusController.instance.add(
        title: '$label HTTP fetch check',
        message: 'Errore: $e',
        success: false,
        category: 'avatar',
      );
    }

    try {
      await precacheImage(NetworkImage(url), context);
      SyncStatusController.instance.add(
        title: '$label precache check',
        message: 'Immagine precaricata con successo',
        success: true,
        category: 'avatar',
      );
    } catch (e) {
      SyncStatusController.instance.add(
        title: '$label precache check',
        message: 'Errore: $e',
        success: false,
        category: 'avatar',
      );
    }
  }

  Future<void> _cleanupLegacyAvatars({
    required FirebaseStorage storage,
    required String uid,
  }) async {
    final legacyNames = ['avatar.png', 'avatar.jpeg', 'avatar.webp'];

    for (final name in legacyNames) {
      final legacyRef = storage.ref().child('public_profiles').child(uid).child(name);

      try {
        await legacyRef.delete();
        debugPrint('[AVATAR] legacy removed: ${legacyRef.fullPath}');
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          debugPrint('[AVATAR] cleanup error ${e.code}: ${e.message}');
        }
      } catch (e) {
        debugPrint('[AVATAR] cleanup generic error: $e');
      }
    }
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
              Row(
                children: [
                  const Expanded(
                    child: SyncStatusPanel(title: 'Controlli online'),
                  ),
                  IconButton(
                    tooltip: 'Aggiorna diagnostica avatar',
                    onPressed: _busy
                        ? null
                        : () {
                            final currentUser = _auth.currentUser;
                            if (currentUser != null) {
                              _runAvatarDiagnostics(currentUser);
                            }
                          },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  children: [
                    ProfileAvatar(
                      key: ValueKey('avatar-${user.uid}-${_lastAvatarUpdateTs}'),
                      uid: user.uid,
                      radius: 54,
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
              if (kDebugMode && _lastAvatarBaseUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  'URL diagnostica: ${_lastAvatarBaseUrl!}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.network(
                    _lastAvatarBaseUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
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
