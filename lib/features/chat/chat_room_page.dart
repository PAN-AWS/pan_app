import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../marketplace/public_profile_page.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const ChatRoomPage({super.key, required this.chatId, required this.otherUid});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _VideoAttachment extends StatelessWidget {
  final String url;
  final String fileName;
  const _VideoAttachment({required this.url, required this.fileName});

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Impossibile aprire il video';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _text = TextEditingController();
  final FocusNode _rawFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();
  final _picker = ImagePicker();
  bool _sendingMedia = false;
  double? _uploadProgress;

  Future<void> _markAsRead() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    await chatRef.set({
      'readBy': { me.uid: FieldValue.serverTimestamp() }
    }, SetOptions(merge: true));
  }

  String _summaryFor({String? text, String? mediaType}) {
    if (text != null && text.trim().isNotEmpty) return text.trim();
    if (mediaType != null && mediaType.startsWith('video/')) return '[Video]';
    if (mediaType != null && mediaType.startsWith('image/')) return '[Foto]';
    return '[Allegato]';
  }

  Future<void> _send({required String text, String? messageId, String? mediaUrl, String? mediaType, String? fileName}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty && mediaUrl == null) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final msgRef = messageId == null
        ? chatRef.collection('messages').doc()
        : chatRef.collection('messages').doc(messageId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(msgRef, {
        'senderId': me.uid,
        'text': trimmed,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'fileName': fileName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(chatRef, {
        'lastMessage': _summaryFor(text: trimmed, mediaType: mediaType),
        'lastSenderId': me.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    _text.clear();
    _textFocus.requestFocus();
    await _markAsRead();
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      setState(() {
        _sendingMedia = true;
        _uploadProgress = 0;
      });
      final XFile? picked = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2))
          : await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (picked == null) return;

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final msgId = chatRef.collection('messages').doc().id;
      final path = 'chat_media/${widget.chatId}/$msgId/${picked.name}';
      final ref = FirebaseStorage.instance.ref(path);
      final bytes = await picked.readAsBytes();
      final inferredType = _inferContentType(picked.name, isVideo: isVideo);
      final metadata = SettableMetadata(contentType: inferredType);

      final task = ref.putData(bytes, metadata);
      task.snapshotEvents.listen((snap) {
        final pct = (snap.totalBytes == 0) ? 0.0 : snap.bytesTransferred / snap.totalBytes;
        if (mounted) {
          setState(() => _uploadProgress = pct);
        }
      });

      await task.whenComplete(() => null);
      final url = await ref.getDownloadURL();

      await _send(
        text: _text.text,
        messageId: msgId,
        mediaUrl: url,
        mediaType: inferredType,
        fileName: picked.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingMedia = false;
          _uploadProgress = null;
        });
      }
    }
  }

  String _inferContentType(String name, {required bool isVideo}) {
    final n = name.toLowerCase();
    if (isVideo) return 'video/mp4';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
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
                        final mediaUrl = (data['mediaUrl'] ?? '') as String;
                        final mediaType = (data['mediaType'] ?? '') as String;
                        final fileName = (data['fileName'] ?? '') as String;
                        final hasImage = mediaUrl.isNotEmpty && mediaType.startsWith('image/');
                        final hasVideo = mediaUrl.isNotEmpty && mediaType.startsWith('video/');
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
                            child: Column(
                              crossAxisAlignment:
                              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (hasImage)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(mediaUrl, fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                if (hasVideo)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _VideoAttachment(
                                      url: mediaUrl,
                                      fileName: fileName.isNotEmpty ? fileName : 'video',
                                    ),
                                  ),
                                if (text.isNotEmpty) Text(text),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_sendingMedia)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(
                    value: _uploadProgress != null
                        ? (_uploadProgress!.clamp(0.0, 1.0)).toDouble()
                        : null,
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
                        IconButton(
                          tooltip: 'Allega foto',
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: _sendingMedia ? null : () => _pickAndSendMedia(isVideo: false),
                        ),
                        IconButton(
                          tooltip: 'Allega video',
                          icon: const Icon(Icons.videocam_outlined),
                          onPressed: _sendingMedia ? null : () => _pickAndSendMedia(isVideo: true),
                        ),
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
