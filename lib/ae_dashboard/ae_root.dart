import 'package:flutter/material.dart';

import 'ae_dashboard_screen.dart';
import 'ae_profile.dart';

class AeRoot extends StatefulWidget {
  const AeRoot({super.key});

  @override
  State<AeRoot> createState() => _AeRootState();
}

class _AeRootState extends State<AeRoot> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AeDashboardScreen(mode: AeHomeMode.dashboard),
          AeDashboardScreen(mode: AeHomeMode.complaints),
          AeProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}