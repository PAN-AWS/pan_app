import 'package:firebase_auth/firebase_auth.dart';

/// Stub temporaneo per emulatori/Android:
/// - Disattiva Google Sign-In su mobile per permettere il run senza configurazioni extra.
/// - Continua a funzionare login email/password.
/// - La UI mostrerà l'errore catturato in try/catch (già gestito nelle tue pagine).
Future<UserCredential> googleSignIn() async {
  throw FirebaseAuthException(
    code: 'unimplemented',
    message:
    'Accesso Google temporaneamente disattivato su Android emulator. Usa Email/Password per accedere.',
  );
}

Future<void> googleSignOutIfNeeded() async {
  // Logout standard Firebase (niente GoogleSignIn su questo stub)
  await FirebaseAuth.instance.signOut();
}
