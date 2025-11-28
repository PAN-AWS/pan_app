  // Sceglie automaticamente l’implementazione giusta:
  // - Web:    google_auth_web.dart
  // - Mobile: google_auth_mobile.dart
  // - Altro:  google_auth_stub.dart
  import 'google_auth_stub.dart'
  if (dart.library.html) 'google_auth_web.dart'
  if (dart.library.io) 'google_auth_mobile.dart' as impl;

  import 'package:firebase_auth/firebase_auth.dart';

  Future<UserCredential> googleSignIn() => impl.googleSignIn();
  Future<void> googleSignOutIfNeeded() => impl.googleSignOutIfNeeded();
