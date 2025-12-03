import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Raccoglie gli eventi di comunicazione online/offline per mostrarli in UI.
class SyncStatusController {
  SyncStatusController._();
  static final SyncStatusController instance = SyncStatusController._();

  final ValueNotifier<List<SyncStatusEntry>> _events =
      ValueNotifier<List<SyncStatusEntry>>(<SyncStatusEntry>[]);

  ValueListenable<List<SyncStatusEntry>> get events => _events;

  /// Aggiunge una nuova riga di log nel quadro di controllo.
  void add({
    required String title,
    required String message,
    required bool success,
    String category = 'generale',
  }) {
    final entry = SyncStatusEntry(
      title: title,
      message: message,
      success: success,
      timestamp: DateTime.now(),
      category: category,
    );
    final current = _events.value;
    final updated = <SyncStatusEntry>[entry, ...current];
    // Limita il numero di voci per non gonfiare lo stato della UI.
    _events.value = updated.take(10).toList();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    debugPrint('[SYNC][${success ? 'OK' : 'ERR'}][$category] ${entry.title} -> ${entry.message} (uid=$uid)');
  }

  void clear() {
    _events.value = <SyncStatusEntry>[];
  }
}

class SyncStatusEntry {
  final String title;
  final String message;
  final bool success;
  final DateTime timestamp;
  final String category;

  const SyncStatusEntry({
    required this.title,
    required this.message,
    required this.success,
    required this.timestamp,
    required this.category,
  });
}

/// Pannello riassuntivo da mostrare nelle schermate che fanno chiamate online.
class SyncStatusPanel extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry margin;
  const SyncStatusPanel({
    super.key,
    this.title = 'Quadro di controllo',
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Svuota log',
                  onPressed: SyncStatusController.instance.clear,
                ),
              ],
            ),
            _AuthStatusRow(colorScheme: cs),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<SyncStatusEntry>>(
              valueListenable: SyncStatusController.instance.events,
              builder: (context, events, _) {
                if (events.isEmpty) {
                  return Text(
                    'Nessuna attività registrata. Le chiamate online mostreranno esiti e dettagli qui.',
                    style: TextStyle(color: cs.outline),
                  );
                }
                return Column(
                  children: [
                    for (final e in events)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          e.success ? Icons.check_circle : Icons.error,
                          color: e.success ? cs.primary : cs.error,
                        ),
                        title: Text('${e.title} (${e.category})'),
                        subtitle: Text(
                          '${_formatTime(e.timestamp)} — ${e.message}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _AuthStatusRow extends StatelessWidget {
  final ColorScheme colorScheme;
  const _AuthStatusRow({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        final logged = user != null;
        return Row(
          children: [
            Icon(
              logged ? Icons.verified_user : Icons.no_accounts,
              color: logged ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    logged
                        ? 'Utente collegato: ${user!.uid}'
                        : 'Nessun utente autenticato',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    logged
                        ? 'Email: ${user.email ?? 'n/d'}'
                        : 'Accedi per iniziare le comunicazioni sicure.',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
