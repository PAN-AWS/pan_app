import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../marketplace/public_profile_page.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String title;
  const GroupChatPage({super.key, required this.groupId, required this.title});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _text = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final text = _text.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final msgRef = groupRef.collection('messages').doc();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': me.uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(groupRef, {
        'lastMessage': text,
        'lastSenderId': me.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    _text.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final q = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Errore: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final senderId = (d['senderId'] ?? '') as String;
                    final mine = senderId == me.uid;
                    final text = (d['text'] ?? '') as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Column(
                        crossAxisAlignment:
                        mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // NOME MITTENTE (cliccabile → profilo pubblico)
                          _SenderName(
                            uid: senderId,
                            alignEnd: mine,
                          ),
                          const SizedBox(height: 4),
                          // BUBBLE
                          Align(
                            alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 520),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    : Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(text),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Scrivi un messaggio…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: const Text('Invia'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget che mostra il displayName dell'utente (cliccabile) usando public_profiles.
/// Se il profilo non esiste, mostra l'UID come fallback.
class _SenderName extends StatelessWidget {
  final String uid;
  final bool alignEnd;
  const _SenderName({required this.uid, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(uid)
          .get(),
      builder: (context, snap) {
        String title = uid; // fallback
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data() as Map<String, dynamic>;
          title = (u['displayName'] ?? uid) as String;
        }

        final textWidget = Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        );

        return Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicProfilePage(uid: uid),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: textWidget,
            ),
          ),
        );
      },
    );
  }
}
