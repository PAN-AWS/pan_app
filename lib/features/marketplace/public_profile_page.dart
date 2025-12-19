import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/widgets/profile_avatar.dart';
import '../chat/chat_room_page.dart';
import '../../utils/chat_ids.dart';

class PublicProfilePage extends StatelessWidget {
  final String uid;
  const PublicProfilePage({super.key, required this.uid});

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
          final company = (d['company']?.toString() ?? '');
          final bio = (d['bio']?.toString() ?? '');
          final prov = (d['provinceName']?.toString().isNotEmpty == true)
              ? '${d['provinceName']} (${d['provinceCode'] ?? ''})'
              : (d['provinceCode']?.toString() ?? '-');
          final products = (d['products'] as List?)?.cast<String>() ?? const <String>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ProfileAvatar(uid: uid, radius: 28),
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
                          if (company.isNotEmpty) Chip(label: Text(company)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(bio),
              ],
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
                    final chatId = dmChatIdFor(myUid, uid);
                    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                    await FirebaseFirestore.instance.runTransaction((tx) async {
                      final snap = await tx.get(chatRef);
                      if (!snap.exists) {
                        tx.set(chatRef, {
                          'type': 'dm',
                          'members': [myUid, uid],
                          'createdBy': myUid,
                          'createdAt': FieldValue.serverTimestamp(),
                          'lastMessageAt': FieldValue.serverTimestamp(),
                        });
                      }
                    });
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
