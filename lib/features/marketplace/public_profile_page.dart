import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../chat/chat_room_page.dart';

class PublicProfilePage extends StatelessWidget {
  final String uid;
  const PublicProfilePage({super.key, required this.uid});

  String _chatIdFor(String a, String b) {
    final x = [a, b]..sort();
    return '${x[0]}_${x[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final isMe = me?.uid == uid;

    final docRef = FirebaseFirestore.instance.collection('public_profiles').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo pubblico')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Profilo non trovato.'));
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final name = (d['displayName']?.toString() ?? 'Utente');
          final role = (d['role']?.toString() ?? '-');
          final prov = (d['provinceName']?.toString().isNotEmpty == true)
              ? '${d['provinceName']} (${d['provinceCode'] ?? ''})'
              : (d['provinceCode']?.toString() ?? '-');
          final products = (d['products'] as List?)?.cast<String>() ?? const <String>[];
          final firestoreAvatar =
              (d['avatarUrl'] is String && (d['avatarUrl'] as String).trim().isNotEmpty)
                  ? (d['avatarUrl'] as String).trim()
                  : '';
          final authPhoto = isMe ? (FirebaseAuth.instance.currentUser?.photoURL ?? '') : '';
          final avatarUrlToShow =
              (firestoreAvatar.isNotEmpty) ? firestoreAvatar : authPhoto;
          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        (avatarUrlToShow.isNotEmpty) ? NetworkImage(avatarUrlToShow) : null,
                    child: (avatarUrlToShow.isEmpty) ? Text(initials) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: -6, children: [
                          Chip(label: Text(role)),
                          if (prov.isNotEmpty) Chip(label: Text(prov)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Prodotti trattati', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (products.isEmpty)
                const Text('Nessun prodotto indicato.')
              else
                Wrap(
                  spacing: 6,
                  runSpacing: -8,
                  children: products.map((p) => Chip(label: Text(p))).toList(),
                ),
              const SizedBox(height: 24),

              if (!isMe)
                FilledButton.icon(
                  icon: const Icon(Icons.chat),
                  label: Text(me == null ? 'Accedi per inviare un messaggio' : 'Avvia conversazione'),
                  onPressed: () async {
                    final curr = FirebaseAuth.instance.currentUser;
                    if (curr == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accedi per inviare un messaggio.')),
                      );
                      return;
                    }
                    final myUid = curr.uid;
                    final chatId = _chatIdFor(myUid, uid);
                    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
                      'members': [myUid, uid],
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: chatId, otherUid: uid)),
                      );
                    }
                  },
                ),

              if (isMe)
                const Text('Questo è il tuo profilo pubblico.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          );
        },
      ),
    );
  }
}
