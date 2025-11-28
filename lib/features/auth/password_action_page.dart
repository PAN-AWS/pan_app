import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Gestisce i link d’azione inviati via email da Firebase:
/// - resetPassword
/// - verifyEmail
/// - recoverEmail
///
/// La pagina legge `mode` e `oobCode` dalla URL (Uri.base) e mostra l’UI adeguata.
class PasswordActionPage extends StatefulWidget {
  const PasswordActionPage({super.key});

  @override
  State<PasswordActionPage> createState() => _PasswordActionPageState();
}

class _PasswordActionPageState extends State<PasswordActionPage> {
  String? _mode;
  String? _oobCode;
  String? _error;
  bool _busy = false;

  final _pwd1 = TextEditingController();
  final _pwd2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    _mode = uri.queryParameters['mode'];
    _oobCode = uri.queryParameters['oobCode'];
  }

  @override
  void dispose() {
    _pwd1.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyEmail() async {
    if (_oobCode == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.applyActionCode(_oobCode!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verificata. Ora puoi accedere dall’app.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRecoverEmail() async {
    if (_oobCode == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.applyActionCode(_oobCode!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email ripristinata.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (_oobCode == null) return;
    final p1 = _pwd1.text.trim();
    final p2 = _pwd2.text.trim();
    if (p1.length < 6) { setState(() => _error = 'La password deve avere almeno 6 caratteri.'); return; }
    if (p1 != p2)       { setState(() => _error = 'Le password non coincidono.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(code: _oobCode!, newPassword: p1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata. Ora puoi accedere dall’app.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode ?? '';
    final c = Theme.of(context).colorScheme;

    Widget body;
    if (_oobCode == null || _mode == null) {
      body = const Center(child: Text('Link non valido.'));
    } else if (mode == 'verifyEmail') {
      body = _ActionCard(
        title: 'Verifica email',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Premi il pulsante per confermare la verifica.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _handleVerifyEmail,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified),
              label: Text(_busy ? 'Verifica…' : 'Verifica'),
            ),
          ],
        ),
      );
    } else if (mode == 'recoverEmail') {
      body = _ActionCard(
        title: 'Ripristino email',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Premi per completare il ripristino.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _handleRecoverEmail,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.mark_email_read),
              label: Text(_busy ? 'Ripristino…' : 'Conferma ripristino'),
            ),
          ],
        ),
      );
    } else if (mode == 'resetPassword') {
      body = _ActionCard(
        title: 'Reimposta password',
        child: Column(
          children: [
            TextField(
              controller: _pwd1,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nuova password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwd2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Conferma password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _handleResetPassword,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_reset),
                label: Text(_busy ? 'Aggiornamento…' : 'Aggiorna password'),
              ),
            ),
          ],
        ),
      );
    } else {
      body = const Center(child: Text('Azione non riconosciuta.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PAN — Azione account')),
      body: Stack(
        children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Padding(padding: const EdgeInsets.all(16), child: body))),
          if (_error != null)
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Material(
                color: c.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: c.onErrorContainer)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ActionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
