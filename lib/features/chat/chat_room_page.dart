import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../marketplace/public_profile_page.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const ChatRoomPage({super.key, required this.chatId, required this.otherUid});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _text = TextEditingController();
  final FocusNode _rawFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();

  Future<void> _markAsRead() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    await chatRef.set({
      'readBy': { me.uid: FieldValue.serverTimestamp() }
    }, SetOptions(merge: true));
  }

  Future<void> _send({required String text}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final msgRef = chatRef.collection('messages').doc();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': me.uid,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(chatRef, {
        'lastMessage': trimmed,
        'lastSenderId': me.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    _text.clear();
    _textFocus.requestFocus();
    await _markAsRead();
  }

  bool _isEnterWithoutShift(RawKeyEvent e) {
    if (e is! RawKeyDownEvent) return false;
    final isEnter = e.logicalKey == LogicalKeyboardKey.enter;
    if (!isEnter) return false;
    return !e.isShiftPressed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rawFocus.requestFocus();
      _textFocus.requestFocus();
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _rawFocus.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final messagesQuery = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true);

    final otherUserStream =
    FirebaseFirestore.instance.collection('public_profiles').doc(widget.otherUid).snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: otherUserStream,
      builder: (context, snapUser) {
        String title = widget.otherUid;
        if (snapUser.hasData && snapUser.data!.exists) {
          final u = snapUser.data!.data() as Map<String, dynamic>;
          title = (u['displayName'] ?? widget.otherUid) as String;
        }

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PublicProfilePage(uid: widget.otherUid)),
                );
              },
              child: Text(title),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: messagesQuery.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Errore: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;

                    if (docs.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final mine = data['senderId'] == me.uid;
                        final text = (data['text'] ?? '') as String;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(text),
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
                  child: RawKeyboardListener(
                    focusNode: _rawFocus,
                    onKey: (e) async {
                      final isDesktopWeb = kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS;
                      if (isDesktopWeb && _isEnterWithoutShift(e)) {
                        final t = _text.text;
                        if (t.trim().isNotEmpty) {
                          await _send(text: t);
                        }
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            focusNode: _textFocus,
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
                          onPressed: () => _send(text: _text.text),
                          icon: const Icon(Icons.send),
                          label: const Text('Invia'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
