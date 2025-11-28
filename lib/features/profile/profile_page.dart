import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/widgets/app_nav_bar.dart';

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

  Future<void> _pickAndUpload() async {
    final user = _auth.currentUser;
    if (user == null) {
      _snack('Devi essere autenticato.');
      return;
    }

    try {
      setState(() => _busy = true);
      debugPrint('[PROFILE] start pick');

      // 1) Scegli immagine
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );

      if (picked == null) {
        debugPrint('[PROFILE] pick cancelled');
        _snack('Selezione annullata.');
        return;
      }
      debugPrint('[PROFILE] picked: name=${picked.name}, bytes?');

      // 2) Bytes + metadata
      final Uint8List bytes = await picked.readAsBytes();

      // Le regole Firebase condivise per Storage/Firestore prevedono cartelle
      // per-utente sia private (users) sia pubbliche (public_profiles). Per le
      // immagini profilo manteniamo la versione pubblica così da essere
      // leggibile dal Marketplace e coerente con le regole di scrittura che
      // accettano solo il proprietario.
      final String storagePath = 'public_profiles/${user.uid}/avatar.jpg';
      final metadata = SettableMetadata(contentType: _inferContentType(picked.name));
      debugPrint('[PROFILE] upload to $storagePath contentType=${metadata.contentType} size=${bytes.lengthInBytes}');

      // 3) Upload
      final ref = FirebaseStorage.instance.ref(storagePath);
      final task = ref.putData(bytes, metadata);

      // opzionale: progress
      task.snapshotEvents.listen((s) {
        final pct = (s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes) * 100).toStringAsFixed(0);
        debugPrint('[PROFILE] upload state=${s.state} $pct%');
      });

      await task.whenComplete(() => null);
      debugPrint('[PROFILE] upload complete');

      // 4) URL
      final url = await ref.getDownloadURL();
      debugPrint('[PROFILE] got URL: $url');

      // 5) Aggiorna Auth + Firestore
      await user.updatePhotoURL(url);
      await Future.wait([
        _db.collection('users').doc(user.uid).set({
          'photoURL': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        _db.collection('public_profiles').doc(user.uid).set({
          'photoURL': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
      debugPrint('[PROFILE] auth+firestore (private+public) updated');

      // 6) Refresh UI
      await user.reload();
      if (!mounted) return;
      setState(() {});
      _snack('Immagine profilo aggiornata.');
    } on FirebaseException catch (e) {
      debugPrint('[PROFILE][FIREBASE-ERROR] code=${e.code} message=${e.message}');
      final hint = (e.code == 'permission-denied' || e.code == 'unauthorized')
          ? 'Autorizzazione negata: verifica che le regole Firebase permettano a ${user.uid} di scrivere in "public_profiles/${user.uid}/*" e che l’utente sia autenticato.'
          : (e.message ?? e.code);
      _snack('Errore Firebase: $hint');
    } catch (e) {
      debugPrint('[PROFILE][ERROR] $e');
      _snack('Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _inferContentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

        final docRef = _db.collection('users').doc(user.uid);
        return StreamBuilder<DocumentSnapshot>(
          stream: docRef.snapshots(),
          builder: (context, sDoc) {
            final data = (sDoc.data?.data() as Map<String, dynamic>?) ?? {};
            final String photoUrl = (data['photoURL'] is String && (data['photoURL'] as String).trim().isNotEmpty)
                ? (data['photoURL'] as String).trim()
                : (user.photoURL ?? '');

            return Scaffold(
              appBar: AppBar(title: const Text('Profilo')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          backgroundImage: (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                          child: (photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 48)
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                      user.email ?? 'Utente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_front_outlined),
                    title: const Text('Modifica immagine profilo'),
                    subtitle: const Text('Seleziona un’immagine dalla Galleria'),
                    trailing: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                    onTap: _busy ? null : _pickAndUpload,
                  ),
                ],
              ),
              bottomNavigationBar: const AppNavBar(currentIndex: 4),
            );
          },
        );
      },
    );
  }
}
