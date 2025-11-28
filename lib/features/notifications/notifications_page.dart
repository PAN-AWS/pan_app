import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/app_nav_bar.dart';

/// Modalità di notifica disponibili.
/// Valori salvati su Firestore in: users/{uid}.notifications.mode
enum NotificationMode {
  off,            // nessuna notifica
  appOnly,        // solo notifiche "di sistema/app"
  dmOnly,         // solo chat 1-1
  dmAndFavGroups, // chat 1-1 + gruppi preferiti (stellina)
  all,            // tutto (dm + tutti i gruppi + app)
}

const _modeToString = {
  NotificationMode.off: 'off',
  NotificationMode.appOnly: 'appOnly',
  NotificationMode.dmOnly: 'dmOnly',
  NotificationMode.dmAndFavGroups: 'dmAndFavGroups',
  NotificationMode.all: 'all',
};

NotificationMode _stringToMode(String? s) {
  switch (s) {
    case 'off':
      return NotificationMode.off;
    case 'appOnly':
      return NotificationMode.appOnly;
    case 'dmOnly':
      return NotificationMode.dmOnly;
    case 'dmAndFavGroups':
      return NotificationMode.dmAndFavGroups;
    case 'all':
    default:
      return NotificationMode.all;
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationMode? _modeEditing; // stato locale mentre si modifica
  bool _saving = false;

  Future<void> _save(NotificationMode mode) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(me.uid).set({
        'notifications': {
          'mode': _modeToString[mode],
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferenze notifica salvate')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Accedi per gestire le notifiche.')),
        bottomNavigationBar: AppNavBar(currentIndex: 3),
      );
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(me.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Notifiche')),
            body: Center(child: Text('Errore: ${snap.error}')),
            bottomNavigationBar: const AppNavBar(currentIndex: 3),
          );
        }
        if (!snap.hasData) {
          // <-- TOLTO const QUI
          return Scaffold(
            appBar: AppBar(title: const Text('Notifiche')),
            body: const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: const AppNavBar(currentIndex: 3),
          );
        }

        final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
        final savedMode = _stringToMode(
          (data['notifications'] as Map<String, dynamic>?)?['mode'] as String?,
        );

        final current = _modeEditing ?? savedMode;

        return Scaffold(
          appBar: AppBar(title: const Text('Notifiche')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(context),
              const SizedBox(height: 12),
              _radio(
                title: 'Disattiva tutte',
                subtitle: 'Non riceverai nessuna notifica.',
                value: NotificationMode.off,
                groupValue: current,
              ),
              _radio(
                title: 'Solo dall’app',
                subtitle:
                'Ricevi avvisi dall’amministrazione (es. meteo, documenti, aggiornamenti). Nessuna chat.',
                value: NotificationMode.appOnly,
                groupValue: current,
              ),
              _radio(
                title: 'Solo chat 1-1',
                subtitle: 'Notifiche dalle conversazioni private; nessun gruppo.',
                value: NotificationMode.dmOnly,
                groupValue: current,
              ),
              _radio(
                title: 'Chat 1-1 + gruppi preferiti',
                subtitle:
                'Ricevi notifiche dalle chat private e dai gruppi che hai contrassegnato con la stellina.',
                value: NotificationMode.dmAndFavGroups,
                groupValue: current,
              ),
              _radio(
                title: 'Tutte le notifiche',
                subtitle: 'Chat private, tutti i gruppi e avvisi dall’app.',
                value: NotificationMode.all,
                groupValue: current,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Salvataggio…' : 'Salva impostazioni'),
                  onPressed: _saving ? null : () => _save(current),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _explain(current),
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
          bottomNavigationBar: const AppNavBar(currentIndex: 3),
        );
      },
    );
  }

  Widget _headerCard(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12, top: 2),
              child: Icon(Icons.notifications_active),
            ),
            const Expanded(
              child: Text(
                'Scegli cosa vuoi essere notificato. '
                    'Le preferenze valgono su tutti i dispositivi. '
                    'I gruppi preferiti si gestiscono dalla sezione Chat → Gruppi (icona ⭐).',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radio({
    required String title,
    required String subtitle,
    required NotificationMode value,
    required NotificationMode groupValue,
  }) {
    return RadioListTile<NotificationMode>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: (v) => setState(() => _modeEditing = v),
    );
  }

  String _explain(NotificationMode m) {
    switch (m) {
      case NotificationMode.off:
        return 'Nessuna notifica verrà inviata.';
      case NotificationMode.appOnly:
        return 'Solo avvisi pubblici dall’app/amministrazione.';
      case NotificationMode.dmOnly:
        return 'Riceverai notifiche solo dalle chat private.';
      case NotificationMode.dmAndFavGroups:
        return 'Riceverai notifiche da chat private e dai gruppi con ⭐ nelle tue preferenze.';
      case NotificationMode.all:
        return 'Riceverai tutte le notifiche (chat, gruppi e app).';
    }
  }
}
