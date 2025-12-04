import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_room_page.dart';
import 'group_chat_page.dart';
import '../marketplace/public_profile_page.dart';
import '../../app/widgets/app_nav_bar.dart';

String chatIdFor(String a, String b) {
  final x = [a, b]..sort();
  return '${x[0]}_${x[1]}';
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index != 0 && _selected.isNotEmpty) {
        setState(_selected.clear);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _deleteChatCascade(String chatId) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    while (true) {
      final msgs = await chatRef.collection('messages').limit(300).get();
      if (msgs.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final m in msgs.docs) {
        batch.delete(m.reference);
      }
      await batch.commit();
    }
    await chatRef.delete();
  }

  Future<void> _deleteSelectedChats(BuildContext context) async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare le chat selezionate?'),
        content: Text(
          _selected.length == 1
              ? 'Verrà rimossa anche la cronologia della conversazione.'
              : 'Verranno rimosse anche le cronologie di ${_selected.length} conversazioni.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(_, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;

    for (final id in _selected) {
      await _deleteChatCascade(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.length} chat eliminate')),
      );
      setState(_selected.clear);
    }
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
        final showTrash = _tab.index == 0 && _selected.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Chat'),
            bottom: TabBar(
              controller: _tab,
              tabs: const [Tab(text: 'Conversazioni'), Tab(text: 'Gruppi')],
            ),
            actions: [
              if (showTrash)
                IconButton(
                  tooltip: 'Elimina chat selezionate',
                  onPressed: () => _deleteSelectedChats(context),
                  icon: const Icon(Icons.delete),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tab,
            children: [
              _DmList(
                meUid: me.uid,
                selected: _selected,
                onToggleSelect: (id) {
                  setState(() {
                    if (_selected.contains(id)) {
                      _selected.remove(id);
                    } else {
                      _selected.add(id);
                    }
                  });
                },
                onClearSelection: () => setState(_selected.clear),
                onDeleteSingle: (id) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Eliminare la chat?'),
                      content: const Text('Verranno rimossi anche i messaggi. Operazione irreversibile.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Annulla')),
                        FilledButton(onPressed: () => Navigator.pop(_, true), child: const Text('Elimina')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await _deleteChatCascade(id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Conversazione eliminata')),
                      );
                    }
                  }
                },
              ),
              _GroupsList(meUid: me.uid),
            ],
          ),
          floatingActionButton: _tab.index == 0 && _selected.isEmpty
              ? FloatingActionButton(
            tooltip: 'Nuova chat',
            onPressed: () => _startChatByName(context, me.uid),
            child: const Icon(Icons.add),
          )
              : null,
          bottomNavigationBar: const AppNavBar(currentIndex: 1),
        );
      },
    );
  }

  Future<void> _startChatByName(BuildContext context, String myUid) async {
    final searchCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuova conversazione'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cerca per nome',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 420,
                  height: 260,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: (searchCtrl.text.trim().isEmpty)
                        ? FirebaseFirestore.instance
                        .collection('public_profiles')
                        .orderBy('displayName')
                        .limit(20)
                        .snapshots()
                        : FirebaseFirestore.instance
                        .collection('public_profiles')
                        .orderBy('displayName')
                        .startAt([searchCtrl.text.trim()])
                        .endAt(['${searchCtrl.text.trim()}\uf8ff'])
                        .limit(20)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('Errore: ${snap.error}'));
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final me = FirebaseAuth.instance.currentUser!.uid;
                      final docs = snap.data!.docs.where((d) => d.id != me).toList();
                      if (docs.isEmpty) return const Center(child: Text('Nessun risultato'));
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final uid = docs[i].id;
                          final name = (data['displayName'] ?? 'Utente') as String;
                          final role = (data['role'] ?? '') as String;
                          final firestoreAvatar =
                              (data['avatarUrl'] is String && (data['avatarUrl'] as String).trim().isNotEmpty)
                                  ? (data['avatarUrl'] as String).trim()
                                  : '';
                          final authPhoto = FirebaseAuth.instance.currentUser?.photoURL ?? '';
                          final avatarUrlToShow =
                              (firestoreAvatar.isNotEmpty) ? firestoreAvatar : authPhoto;
                          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  (avatarUrlToShow.isNotEmpty) ? NetworkImage(avatarUrlToShow) : null,
                              child: (avatarUrlToShow.isEmpty) ? Text(initials) : null,
                            ),
                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              final chatId = chatIdFor(myUid, uid);
                              await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
                                'members': [myUid, uid],
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                              if (context.mounted) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatRoomPage(chatId: chatId, otherUid: uid),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
            ],
          );
        });
      },
    );
  }
}

class _DmList extends StatelessWidget {
  final String meUid;
  final Set<String> selected;
  final void Function(String chatId) onToggleSelect;
  final VoidCallback onClearSelection;
  final Future<void> Function(String chatId) onDeleteSingle;

  const _DmList({
    required this.meUid,
    required this.selected,
    required this.onToggleSelect,
    required this.onClearSelection,
    required this.onDeleteSingle,
  });

  Widget _bigUnreadDot(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
      ),
    );
  }

  // Recupera nome/ruolo con fallback a `users` se manca `public_profiles`
  Future<Map<String, String>> _getUserDisplay(String uid) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1) Provo public_profiles
      final pub = await db.collection('public_profiles').doc(uid).get();
      if (pub.exists) {
        final u = pub.data() as Map<String, dynamic>;
        final name = (u['displayName'] ?? '').toString();
        final role = (u['role'] ?? '').toString();
        final avatar = (u['avatarUrl'] is String && (u['avatarUrl'] as String).trim().isNotEmpty)
            ? (u['avatarUrl'] as String).trim()
            : '';
        if (name.trim().isNotEmpty) {
          return {'name': name, 'role': role, 'avatar': avatar};
        }
      }

      // 2) Fallback a users
      final priv = await db.collection('users').doc(uid).get();
      if (priv.exists) {
        final d = priv.data() as Map<String, dynamic>;
        final first = (d['firstName'] ?? d['name'] ?? '').toString().trim();
        final last  = (d['lastName']  ?? d['surname'] ?? '').toString().trim();
        final role  = (d['role'] ?? '').toString();
        final avatar =
            (d['photoURL'] is String && (d['photoURL'] as String).trim().isNotEmpty)
                ? (d['photoURL'] as String).trim()
                : '';
        final composed = '$first $last'.trim();
        if (composed.isNotEmpty) {
          return {'name': composed, 'role': role, 'avatar': avatar};
        }
      }

      // 3) Estremo fallback: UID
      return {'name': uid, 'role': '', 'avatar': ''};
    } catch (_) {
      return {'name': uid, 'role': '', 'avatar': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: meUid)
        .orderBy('updatedAt', descending: true);

    final selectionMode = selected.isNotEmpty;

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
          if (selectionMode) onClearSelection();
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
            final last = (d['lastMessage'] ?? '') as String;
            final ts = d['updatedAt'] as Timestamp?;
            final when = ts?.toDate();
            final isSelected = selected.contains(doc.id);

            // Non letto
            final lastSenderId = d['lastSenderId'] as String?;
            final readBy = (d['readBy'] is Map) ? Map<String, dynamic>.from(d['readBy']) : <String, dynamic>{};
            final readTs = readBy[meUid] is Timestamp ? (readBy[meUid] as Timestamp) : null;

            bool unread = false;
            if (ts != null) {
              final updatedAfterRead = (readTs == null) || ts.toDate().isAfter(readTs.toDate());
              unread = updatedAfterRead && (lastSenderId != meUid);
            }

            Widget trailing;
            if (selectionMode) {
              trailing = Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelect(doc.id),
              );
            } else {
              trailing = when != null ? Text(TimeOfDay.fromDateTime(when).format(context)) : const SizedBox.shrink();
            }

            final tileInner = FutureBuilder<Map<String, String>>(
              future: _getUserDisplay(otherUid),
              builder: (context, uSnap) {
                final title = uSnap.data?['name'] ?? otherUid;
                final subtitle2 = uSnap.data?['role'] ?? '';
                final firestoreAvatar = uSnap.data?['avatar'] ?? '';
                final authPhoto = FirebaseAuth.instance.currentUser?.photoURL ?? '';
                final avatarUrlToShow =
                    (firestoreAvatar.isNotEmpty) ? firestoreAvatar : authPhoto;
                final initials = title.isNotEmpty ? title[0].toUpperCase() : '?';

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
                        CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          backgroundImage: (avatarUrlToShow.isNotEmpty)
                              ? NetworkImage(avatarUrlToShow)
                              : null,
                          child: (avatarUrlToShow.isEmpty)
                              ? Text(initials)
                              : null,
                        ),
                        if (unread) Positioned(right: 0, bottom: 0, child: _bigUnreadDot(context)),
                      ],
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: unread
                        ? TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    )
                        : null,
                  ),
                  subtitle: Text(
                    [last, subtitle2].where((s) => s.isNotEmpty).join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: subtitle2.isNotEmpty,
                  trailing: trailing,
                  onTap: () {
                    if (selectionMode) {
                      onToggleSelect(doc.id);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatRoomPage(chatId: doc.id, otherUid: otherUid)),
                      );
                    }
                  },
                  onLongPress: () => onToggleSelect(doc.id),
                );
              },
            );

            final highlight = unread
                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35)
                : Colors.transparent;

            return Dismissible(
              key: ValueKey(doc.id),
              direction: selectionMode ? DismissDirection.none : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                await onDeleteSingle(doc.id);
                return false;
              },
              child: Container(color: highlight, child: tileInner),
            );
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
      'prod_${name.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_")}';

  Future<void> _toggleFav(String gid, bool add) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(meUid);
    await ref.set({
      'favGroups': add ? FieldValue.arrayUnion([gid]) : FieldValue.arrayRemove([gid]),
    }, SetOptions(merge: true));
  }

  Future<void> _enterGroup(BuildContext context, String gid, String title) async {
    final ref = FirebaseFirestore.instance.collection('groups').doc(gid);
    await ref.set({
      'groupId': gid,
      'title': title,
      'members': FieldValue.arrayUnion([meUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupId: gid, title: title)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(meUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, snap) {
        final fav = <String>{};
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          fav.addAll(List<String>.from(data['favGroups'] ?? const <String>[]));
        }

        final items = [...prodotti]..sort((a, b) => a.compareTo(b));
        final mapped = items.map((p) {
          final gid = _gidFor(p);
          return (gid: gid, title: p, isFav: fav.contains(gid));
        }).toList()
          ..sort((a, b) {
            if (a.isFav != b.isFav) return a.isFav ? -1 : 1;
            return a.title.compareTo(b.title);
          });

        return ListView.separated(
          itemCount: mapped.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = mapped[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.groups)),
              title: Text(it.title),
              trailing: IconButton(
                tooltip: it.isFav ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
                icon: Icon(it.isFav ? Icons.star : Icons.star_border),
                onPressed: () => _toggleFav(it.gid, !it.isFav),
              ),
              onTap: () => _enterGroup(context, it.gid, it.title),
            );
          },
        );
      },
    );
  }
}
