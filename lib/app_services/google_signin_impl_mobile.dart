// Implementazione per ANDROID/iOS/Desktop: usa google_sign_in.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<UserCredential> signIn() async {
  final g = GoogleSignIn(scopes: ['email']);
  final account = await g.signIn();
  if (account == null) {
    throw FirebaseAuthException(code: 'canceled', message: 'Login annullato');
  }
  final gAuth = await account.authentication;
  final cred = GoogleAuthProvider.credential(
    accessToken: gAuth.accessToken, idToken: gAuth.idToken,
  );
  return await FirebaseAuth.instance.signInWithCredential(cred);
}

Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
  try { await GoogleSignIn().signOut(); } catch (_) {}
}
