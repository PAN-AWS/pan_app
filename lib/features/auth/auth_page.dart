import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pan_app/services/auth/google_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this); // 0=Accedi, 1=Registrati
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      await googleSignIn();
      // Niente navigate: app.dart ascolta authStateChanges() e ricarica la UI.
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Errore di autenticazione Google.');
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accedi a PAN'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Accedi'),
            Tab(text: 'Registrati'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _EmailLogin(onError: _showError),
          _EmailRegister(onError: _showError),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Accedi con Google'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resterai collegato automaticamente su questo dispositivo.',
                style: TextStyle(color: cs.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailLogin extends StatefulWidget {
  final void Function(String message) onError;
  const _EmailLogin({required this.onError});

  @override
  State<_EmailLogin> createState() => _EmailLoginState();
}

class _EmailLoginState extends State<_EmailLogin> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      // app.dart ascolta authStateChanges().
    } on FirebaseAuthException catch (e) {
      widget.onError(_mapAuthError(e));
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      widget.onError('Inserisci la tua email per reimpostare la password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email inviata. Controlla la casella di posta.')),
      );
    } on FirebaseAuthException catch (e) {
      widget.onError(_mapAuthError(e));
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Utente non trovato.';
      case 'wrong-password':
        return 'Password errata.';
      case 'invalid-credential':
        return 'Credenziali non valide.';
      case 'invalid-email':
        return 'Email non valida.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova più tardi.';
      default:
        return e.message ?? 'Errore di accesso.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inserisci l’email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Minimo 6 caratteri' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text('Password dimenticata?'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _login,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: Text(_loading ? 'Accesso…' : 'Accedi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailRegister extends StatefulWidget {
  final void Function(String message) onError;
  const _EmailRegister({required this.onError});

  @override
  State<_EmailRegister> createState() => _EmailRegisterState();
}

class _EmailRegisterState extends State<_EmailRegister> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final pass = _password.text.trim();
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);

      // Invia verifica email
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione completata. Controlla l’email per la verifica.')),
      );

      // Ritorna al tab "Accedi"
      DefaultTabController.of(context)?.animateTo(0);
    } on FirebaseAuthException catch (e) {
      widget.onError(_mapAuthError(e));
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email già in uso.';
      case 'invalid-email':
        return 'Email non valida.';
      case 'weak-password':
        return 'Password troppo debole.';
      default:
        return e.message ?? 'Errore di registrazione.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inserisci l’email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Minimo 6 caratteri' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Ripeti password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v != _password.text) ? 'Le password non coincidono' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _register,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.app_registration),
                label: Text(_loading ? 'Registrazione…' : 'Registrati'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
