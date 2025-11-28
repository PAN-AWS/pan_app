// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import '../../app/app.dart'; // per Routes

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  void _onNavTap(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    switch (index) {
      case 0: // Home
        break; // già qui
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PAN')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Benvenuto!', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Vai alle chat'),
              subtitle: const Text('Messaggi diretti e gruppi'),
              onTap: () => _onNavTap(1),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Marketplace'),
              subtitle: const Text('Profili pubblici e annunci'),
              onTap: () => _onNavTap(2),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifiche'),
              onTap: () => _onNavTap(3),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profilo'),
              onTap: () => _onNavTap(4),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onNavTap,
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
      ),
    );
  }
}
