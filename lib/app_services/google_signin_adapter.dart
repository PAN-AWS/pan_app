// Adapter con import condizionali: web vs mobile/desktop.
import 'package:firebase_auth/firebase_auth.dart';

// Se siamo su web viene preso il file *_web.dart, altrimenti *_mobile.dart
import 'google_signin_impl_web.dart'
if (dart.library.io) 'google_signin_impl_mobile.dart' as impl;

class GoogleSigninAdapter {
  static Future<UserCredential> signIn() => impl.signIn();
  static Future<void> signOut() => impl.signOut();
}
