// Implementazione per WEB: nessuna dipendenza da google_sign_in.
import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> signIn() async {
  final auth = FirebaseAuth.instance;
  final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
  return await auth.signInWithPopup(provider);
}

Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
}
