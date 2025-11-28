import 'package:firebase_auth/firebase_auth.dart';

/// Fallback: non dovrebbe essere chiamato su piattaforme supportate.
/// Lo teniamo solo per far compilare se la piattaforma non è html o io.
Future<UserCredential> googleSignIn() {
  throw UnimplementedError('googleSignIn non implementato per questa piattaforma');
}

Future<void> googleSignOutIfNeeded() async {
  // niente da fare
}
