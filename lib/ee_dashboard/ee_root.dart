import 'package:flutter/material.dart';

import 'ee_home.dart';
import 'ee_complaints_intent.dart';
import 'ee_official_theme.dart';
import 'ee_profile_page.dart';

class EERoot extends StatefulWidget {
  const EERoot({super.key});

  @override
  State<EERoot> createState() => _EERootState();
}

class _EERootState extends State<EERoot> {
  int _index = 0;
  final ValueNotifier<EeComplaintsIntent?> _complaintsIntent = ValueNotifier(null);

  void _openComplaints(EeComplaintsIntent intent) {
    _complaintsIntent.value = intent;
    setState(() => _index = 1);
  }

  @override
  void dispose() {
    _complaintsIntent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: eeOfficialTheme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: IndexedStack(
              index: _index,
              children: [
                EEHome(
                  mode: EeHomeMode.dashboard,
                  onOpenComplaints: _openComplaints,
                ),
                EEHome(
                  mode: EeHomeMode.complaints,
                  complaintsIntent: _complaintsIntent,
                ),
                const EEProfilePage(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (v) => setState(() => _index = v),
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
        },
      ),
    );
  }
}
