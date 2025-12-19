import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_page.dart';

class AuthGate extends StatelessWidget {
  final WidgetBuilder builder;
  final Widget? loading;
  final bool allowUnauthenticated;

  const AuthGate({
    super.key,
    required this.builder,
    this.loading,
    this.allowUnauthenticated = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return loading ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
        }
        final user = snap.data;
        if (user == null && !allowUnauthenticated) {
          return const AuthPage();
        }
        return builder(context);
      },
    );
  }
}
