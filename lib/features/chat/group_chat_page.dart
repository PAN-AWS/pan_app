import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../marketplace/public_profile_page.dart';
import '../../app/widgets/app_nav_bar.dart';

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
  final _picker = ImagePicker();
  bool _sendingMedia = false;

  String _summaryFor({String? text, String? mediaType}) {
    if (text != null && text.trim().isNotEmpty) return text.trim();
    if (mediaType != null && mediaType.startsWith('video/')) return '[Video]';
    if (mediaType != null && mediaType.startsWith('image/')) return '[Foto]';
    return '[Allegato]';
  }

  Future<void> _send({String? mediaUrl, String? mediaType, String? fileName, String? messageId}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final text = _text.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    setState(() => _sending = true);
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final msgRef = messageId == null
        ? groupRef.collection('messages').doc()
        : groupRef.collection('messages').doc(messageId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': me.uid,
          'text': text,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
          'fileName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(groupRef, {
          'lastMessage': _summaryFor(text: text, mediaType: mediaType),
          'lastSenderId': me.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore invio: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendMedia({required bool isVideo}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      setState(() => _sendingMedia = true);
      final XFile? picked = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2))
          : await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (picked == null) return;

      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
      final msgId = groupRef.collection('messages').doc().id;
      final path = 'group_media/${widget.groupId}/$msgId/${picked.name}';
      final ref = FirebaseStorage.instance.ref(path);
      final bytes = await picked.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File troppo grande (max 20 MB).')),
          );
        }
        return;
      }
      final inferredType = _inferContentType(picked.name, isVideo: isVideo);
      final metadata = SettableMetadata(contentType: inferredType);

      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      await _send(
        mediaUrl: url,
        mediaType: inferredType,
        fileName: picked.name,
        messageId: msgId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  String _inferContentType(String name, {required bool isVideo}) {
    final n = name.toLowerCase();
    if (isVideo) return 'video/mp4';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Accedi per usare la chat di gruppo.')),
        bottomNavigationBar: AppNavBar(currentIndex: 1),
      );
    }
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
                    final mediaUrl = (d['mediaUrl'] ?? '') as String;
                    final mediaType = (d['mediaType'] ?? '') as String;
                    final fileName = (d['fileName'] ?? '') as String;
                    final hasImage = mediaUrl.isNotEmpty && mediaType.startsWith('image/');
                    final hasVideo = mediaUrl.isNotEmpty && mediaType.startsWith('video/');

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
                              child: Column(
                                crossAxisAlignment:
                                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (hasImage)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
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
                    onPressed: _sending ? null : () => _send(),
                    icon: const Icon(Icons.send),
                    label: const Text('Invia'),
                ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 1),
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
