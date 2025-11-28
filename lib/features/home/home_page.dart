// lib/features/home/home_page.dart
import 'package:flutter/material.dart';

import '../../app/app.dart'; // per Routes
import '../../app/widgets/app_nav_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) return; // già qui
    AppNavBar.navigateTo(context, index);
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
              onTap: () => _onNavTap(context, 1),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Marketplace'),
              subtitle: const Text('Profili pubblici e annunci'),
              onTap: () => _onNavTap(context, 2),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifiche'),
              onTap: () => _onNavTap(context, 3),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profilo'),
              onTap: () => _onNavTap(context, 4),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 0),
    );
  }
}
