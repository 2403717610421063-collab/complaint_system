import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/citizen_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/official_dashboard_screen.dart';
import 'admin/admin_root.dart';
import 'package:complaint_system/ae_dashboard/ae_root.dart';
import 'package:complaint_system/aee_dashboard/aee_root.dart';
import 'package:complaint_system/ee_dashboard/ee_root.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(user.uid).get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // If user logged in but no Firestore record exists, treat as Citizen
            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              return const CitizenDashboardScreen();
            }

            final data = roleSnapshot.data!.data() as Map<String, dynamic>;

            // Use .toUpperCase() and .trim() to prevent typos in DB from breaking the app
            String role = (data['role'] ?? 'CITIZEN').toString().trim().toUpperCase();
            String officialRole = (data['officialRole'] ?? '').toString().trim().toUpperCase();

            if (role == "ADMIN") {
              return const AdminRoot();
            }

            if (role == "CITIZEN") {
              return const CitizenDashboardScreen();
            }

            if (role == "OFFICIAL") {
              if (officialRole == "AE") return const AeRoot();
              if (officialRole == "AEE") return const AeeRoot();
              if (officialRole == "EE") return const EERoot();

              // For Lineman, Foreman, etc.
              return const FieldWorkerMainScreen();
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}