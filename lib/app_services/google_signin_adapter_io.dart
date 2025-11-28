import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<UserCredential?> signInWithGoogleMobile() async {
  final account = await GoogleSignIn().signIn();
  if (account == null) return null; // annullato
  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: auth.accessToken,
    idToken: auth.idToken,
  );
  return FirebaseAuth.instance.signInWithCredential(credential);
}

Future<void> signOutGoogleMobile() async {
  try { await GoogleSignIn().signOut(); } catch (_) {}
}
