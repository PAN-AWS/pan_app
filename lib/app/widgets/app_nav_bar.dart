import 'package:flutter/material.dart';

import '../app.dart';

/// Barra di navigazione comune alle sezioni principali dell'app.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.currentIndex});

  /// Indice attuale: 0=Home, 1=Chat, 2=Market, 3=Notifiche, 4=Profilo
  final int currentIndex;

  static void navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, Routes.home);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, Routes.chatList);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, Routes.market);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, Routes.notifications);
        break;
      case 4:
        Navigator.pushReplacementNamed(context, Routes.profile);
        break;
    }
  }

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    navigateTo(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications),
          label: 'Notifiche',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profilo',
        ),
      ],
    );
  }
}
