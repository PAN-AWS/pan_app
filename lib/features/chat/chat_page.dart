import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/profile_avatar.dart';
import 'chat_room_page.dart';
import 'group_chat_page.dart';
import '../marketplace/public_profile_page.dart';
import '../../app/widgets/app_nav_bar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final me = snap.data;
        if (me == null) {
          return const Scaffold(
            body: Center(child: Text('Accedi per usare la chat.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Chat'),
            bottom: TabBar(
              controller: _tab,
              tabs: const [Tab(text: 'Conversazioni'), Tab(text: 'Gruppi')],
            ),
          ),
          body: TabBarView(
            controller: _tab,
            children: [
              _DmList(
                meUid: me.uid,
              ),
              _GroupsList(meUid: me.uid),
            ],
          ),
          bottomNavigationBar: const AppNavBar(currentIndex: 1),
        );
      },
    );
  }
}

class _DmList extends StatelessWidget {
  final String meUid;

  const _DmList({
    required this.meUid,
  });

  // Recupera nome/ruolo dal profilo pubblico
  Future<Map<String, String>> _getUserDisplay(String uid) async {
    try {
      final db = FirebaseFirestore.instance;

      final pub = await db.collection('public_profiles').doc(uid).get();
      if (pub.exists) {
        final u = pub.data() as Map<String, dynamic>;
        final name = (u['displayName'] ?? '').toString();
        final role = (u['role'] ?? '').toString();
        if (name.trim().isNotEmpty) {
          return {'name': name, 'role': role};
        }
      }

      // Estremo fallback: UID
      return {'name': uid, 'role': ''};
    } catch (_) {
      return {'name': uid, 'role': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('members', arrayContains: meUid)
        .orderBy('lastMessageAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Errore: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snap.data!.docs;
        if (chats.isEmpty) {
          return const Center(child: Text('Nessuna conversazione.'));
        }

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final doc = chats[i];
            final d = doc.data() as Map<String, dynamic>;
            final members = List<String>.from(d['members'] ?? const <String>[]);
            final otherUid = members.firstWhere((u) => u != meUid, orElse: () => '');
            final lastText = (d['lastMessageText'] ?? '') as String;
            final lastType = (d['lastMessageType'] ?? '') as String;
            final ts = d['lastMessageAt'] as Timestamp?;
            final when = ts?.toDate();
            final lastSummary = lastText.isNotEmpty
                ? lastText
                : (lastType == 'image'
                    ? '[Foto]'
                    : lastType == 'video'
                        ? '[Video]'
                        : '');
            final trailing =
                when != null ? Text(TimeOfDay.fromDateTime(when).format(context)) : const SizedBox.shrink();

            final tileInner = FutureBuilder<Map<String, String>>(
              future: _getUserDisplay(otherUid),
              builder: (context, uSnap) {
                final title = uSnap.data?['name'] ?? otherUid;
                final subtitle2 = uSnap.data?['role'] ?? '';
                return ListTile(
                  leading: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PublicProfilePage(uid: otherUid)),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ProfileAvatar(uid: otherUid),
                      ],
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [lastSummary, subtitle2].where((s) => s.isNotEmpty).join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: subtitle2.isNotEmpty,
                  trailing: trailing,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: doc.id, otherUid: otherUid)),
                    );
                  },
                );
              },
            );

            return tileInner;
          },
        );
      },
    );
  }
}

class _GroupsList extends StatelessWidget {
  final String meUid;
  const _GroupsList({required this.meUid});

  static const prodotti = [
    'Agli','Aglione','Albicocche','Albicocche secche','Anacardi','Ananas','Angurie','Arance','Asparagi','Avocado',
    'Banane','Basilico','Bietole','Broccoli','Cachi','Carciofi','Carote','Castagne','Cavolfiore','Cavoli',
    'Cetrioli','Cicoria','Ciliegie','Cime di Rapa','Cipolle','Clementine','Cocco','Datteri','Fagioli','Fagiolini',
    'Fave','Fichi','Fichi d\'india','Fichi secchi','Finocchi','Fragole','Fragole di bosco','Frutto della passione',
    'Funghi','Gelso','Kiwi','Lamponi','Lattughe','Lime','Limoni','Mandarini','Mandorle','Manghi','Melanzane',
    'Mele','Melograno','Meloni','Mirtilli','Misto di bosco','More','Nespole','Nocciole','Noci','Olive','Papaia',
    'Patate','Peperoni','Pere','Pesche','Pinoli','Piselli','Pistacchi','Pomodoro','Pompelmi','Porri','Prezzemolo',
    'Prugne','Radicchio','Rape','Ravanelli','Ribes','Rosmarino','Rucola','Salvia','Sedani','Semi di zucca',
    'Spinaci','Susine','Tartufo','Uva da tavola','Uva da vino','Uva secca','Zenzero','Zucche','Zucchine',
  ];

  String _gidFor(String name) =>
      'prod_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  Future<void> _toggleFav(String gid, bool add) async {
    final ref = FirebaseFirestore.instance.collection('users_private').doc(meUid);
    await ref.set({
      'favGroups': add ? FieldValue.arrayUnion([gid]) : FieldValue.arrayRemove([gid]),
    }, SetOptions(merge: true));
  }

  Future<void> _enterGroup(BuildContext context, String gid, String title) async {
    final ref = FirebaseFirestore.instance.collection('groups').doc(gid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'members': FieldValue.arrayUnion([meUid]),
      });
    } else {
      await ref.set({
        'type': 'group',
        'name': title,
        'members': [meUid],
        'admins': [meUid],
        'createdBy': meUid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupId: gid, title: title)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users_private').doc(meUid);
    final groupsQuery = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: meUid)
        .orderBy('lastMessageAt', descending: true);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        final fav = <String>{};
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          fav.addAll(List<String>.from(data['favGroups'] ?? const <String>[]));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: groupsQuery.snapshots(),
          builder: (context, groupSnap) {
            if (groupSnap.hasError) {
              return Center(child: Text('Errore: ${groupSnap.error}'));
            }
            if (!groupSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = groupSnap.data!.docs;
            if (groups.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Non sei ancora in nessun gruppo.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _showGroupPicker(context),
                        child: const Text('Entra in un gruppo'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final doc = groups[i];
                final data = doc.data() as Map<String, dynamic>;
                final gid = doc.id;
                final title = (data['name'] ?? gid) as String;
                final lastText = (data['lastMessageText'] ?? '') as String;
                final lastType = (data['lastMessageType'] ?? '') as String;
                final summary = lastText.isNotEmpty
                    ? lastText
                    : lastType == 'image'
                        ? '[Foto]'
                        : lastType == 'video'
                            ? '[Video]'
                            : '';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups)),
                  title: Text(title),
                  subtitle: summary.isNotEmpty ? Text(summary) : null,
                  trailing: IconButton(
                    tooltip: fav.contains(gid) ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
                    icon: Icon(fav.contains(gid) ? Icons.star : Icons.star_border),
                    onPressed: () => _toggleFav(gid, !fav.contains(gid)),
                  ),
                  onTap: () => _enterGroup(context, gid, title),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showGroupPicker(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) {
        final items = [...prodotti]..sort((a, b) => a.compareTo(b));
        return AlertDialog(
          title: const Text('Seleziona un gruppo'),
          content: SizedBox(
            width: 420,
            height: 320,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final title = items[i];
                final gid = _gidFor(title);
                return ListTile(
                  title: Text(title),
                  onTap: () async {
                    await _enterGroup(context, gid, title);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
          ],
        );
      },
    );
  }
}
