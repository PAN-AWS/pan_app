// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme.dart';

// FEATURES (cartelle come da tuo progetto)
import '../features/auth/auth_page.dart';
import '../features/auth/password_action_page.dart';

import '../features/home/home_page.dart';

import '../features/chat/chat_page.dart';
import '../features/chat/chat_room_page.dart';
import '../features/chat/group_chat_page.dart';

import '../features/marketplace/marketplace_page.dart';
import '../features/marketplace/public_profile_page.dart';

import '../features/notifications/notifications_page.dart';

import '../features/profile/profile_page.dart';
import '../features/profile/profile_setup_page.dart';

class PanApp extends StatelessWidget {
  const PanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAN',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,

      // Localizzazione
      locale: const Locale('it'),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      onGenerateRoute: _onGenerateRoute,
      home: const _Root(),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(builder: (_) => HomePage(), settings: settings);

      case Routes.auth:
        return MaterialPageRoute(builder: (_) => AuthPage(), settings: settings);

    // Lista conversazioni (DM + gruppi)
      case Routes.chatList:
        return MaterialPageRoute(builder: (_) => ChatPage(), settings: settings);

    // Lista gruppi (se hai una pagina dedicata, sostituisci qui)
      case Routes.groupList:
        return MaterialPageRoute(builder: (_) => ChatPage(), settings: settings);

      case Routes.market:
        return MaterialPageRoute(builder: (_) => MarketplacePage(), settings: settings);

      case Routes.notifications:
        return MaterialPageRoute(builder: (_) => NotificationsPage(), settings: settings);

      case Routes.profile:
        return MaterialPageRoute(builder: (_) => ProfilePage(), settings: settings);

      case Routes.profileSetup:
        return MaterialPageRoute(builder: (_) => ProfileSetupPage(), settings: settings);

      case Routes.publicProfile: {
        final args = settings.arguments;
        String uid = '';
        if (args is String) {
          uid = args;
        } else if (args is PublicProfileArgs) {
          uid = args.uid;
        } else if (args is Map) {
          uid = (args['uid'] as String?) ?? '';
        }
        return MaterialPageRoute(
          builder: (_) => PublicProfilePage(uid: uid),
          settings: settings,
        );
      }

      case Routes.chatRoom: {
        final args = settings.arguments;
        String chatId = '';
        String otherUid = '';
        if (args is ChatRoomArgs) {
          chatId = args.chatId;
          otherUid = args.otherUid;
        } else if (args is Map) {
          chatId = (args['chatId'] as String?) ?? '';
          otherUid = (args['otherUid'] as String?) ?? '';
        } else if (args is String) {
          chatId = args;
        }
        return MaterialPageRoute(
          builder: (_) => ChatRoomPage(chatId: chatId, otherUid: otherUid),
          settings: settings,
        );
      }

      case Routes.groupRoom: {
        final args = settings.arguments;
        String groupId = '';
        String title = 'Gruppo';
        if (args is GroupRoomArgs) {
          groupId = args.groupId;
          title = args.title;
        } else if (args is Map) {
          groupId = (args['groupId'] as String?) ?? '';
          title = (args['title'] as String?) ?? 'Gruppo';
        }
        return MaterialPageRoute(
          builder: (_) => GroupChatPage(groupId: groupId, title: title),
          settings: settings,
        );
      }

      case Routes.passwordReset:
        return MaterialPageRoute(builder: (_) => PasswordActionPage(), settings: settings);

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Pagina non trovata')),
          ),
          settings: settings,
        );
    }
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) {
          return AuthPage();
        }
        return HomePage();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Nomi route centralizzati
abstract class Routes {
  static const home = '/home';
  static const auth = '/auth';
  static const chatList = '/chat';
  static const groupList = '/groups';
  static const market = '/market';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const profileSetup = '/profile/setup';
  static const publicProfile = '/profile/public';
  static const chatRoom = '/chat/room';
  static const groupRoom = '/group/room';
  static const passwordReset = '/password/reset';
}

/// Args helper
class ChatRoomArgs {
  final String chatId;
  final String otherUid;
  const ChatRoomArgs({required this.chatId, required this.otherUid});
}

class GroupRoomArgs {
  final String groupId;
  final String title;
  const GroupRoomArgs({required this.groupId, required this.title});
}

class PublicProfileArgs {
  final String uid;
  const PublicProfileArgs({required this.uid});
}
