import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> googleSignIn() async {
  final provider = GoogleAuthProvider();
  // Popup-based sign-in per Web
  return FirebaseAuth.instance.signInWithPopup(provider);
}

Future<void> googleSignOutIfNeeded() async {
  await FirebaseAuth.instance.signOut();
}
