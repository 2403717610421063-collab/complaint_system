import 'package:flutter/material.dart';

import 'aee_home.dart';
import 'aee_profile.dart';

class AeeRoot extends StatefulWidget {
  const AeeRoot({super.key});

  @override
  State<AeeRoot> createState() => _AeeRootState();
}

class _AeeRootState extends State<AeeRoot> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AEEHome(mode: AeeHomeMode.dashboard),
          AEEHome(mode: AeeHomeMode.complaints),
          AeeProfilePage(),
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