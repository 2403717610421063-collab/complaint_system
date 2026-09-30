import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'create_official_screen.dart';
import 'manage_officers_screen.dart';
import 'routing_sync_screen.dart';
import 'manage_leaves_screen.dart'; // <-- NEW IMPORT

class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});

  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AdminDashboardScreen(),
          CreateOfficialScreen(),
          ManageOfficersScreen(),
          ManageLeavesScreen(), // <-- NEW SCREEN ADDED HERE
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
            icon: Icon(Icons.person_add_alt_1_outlined),
            selectedIcon: Icon(Icons.person_add_alt_1_rounded),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Officers',
          ),
          // NEW LEAVES TAB
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar_rounded),
            label: 'Leaves',
          ),
        ],
      ),
    );
  }
}