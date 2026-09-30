import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:complaint_system/services/officer_management_service.dart';
import 'officer_action_screen.dart';
import 'package:flutter/material.dart';
import 'package:complaint_system/screens/login_screen.dart';

class ManageOfficersScreen extends StatefulWidget {
  const ManageOfficersScreen({super.key});

  @override
  State<ManageOfficersScreen> createState() => _ManageOfficersScreenState();
}

class _ManageOfficersScreenState extends State<ManageOfficersScreen> {
  static const _purple = Color(0xFF7B2FBE);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _bg = Color(0xFFF5F1FA);



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar:AppBar(
        title: Text(
          'Manage Officers',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _purple,
        elevation: 0,
        automaticallyImplyLeading: false,
        // Use the actions property to add icons to the right side of the AppBar
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0), // Adds space from the right edge
            child: Center( // Vertically centers the container inside the AppBar
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context, FadeSlideRoute(page: const LoginScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: OfficerManagementService.getAllOfficers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No officers registered yet',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final officers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: officers.length,
            itemBuilder: (context, index) {
              final officer = officers[index];
              return _buildOfficerCard(context, officer);
            },
          );
        },
      ),
    );
  }

  Widget _buildOfficerCard(
    BuildContext context,
    Map<String, dynamic> officer,
  ) {
    final name = officer['name'] ?? 'Unknown';
    final email = officer['email'] ?? '';
    final role = officer['officialRole'] ?? 'N/A';
    final section = officer['section_id'] ?? 'N/A';
    final subdivision = officer['subdivision'] ?? 'N/A';
    final division = officer['division'] ?? 'N/A';
    Color roleColor = role == 'AE'
        ? const Color(0xFF7B2FBE)
        : role == 'AEE'
            ? const Color(0xFF0EA5E9)
        : role == 'EE'
          ? const Color(0xFF166534)
          : const Color(0xFF334155);

    Color roleBg = role == 'AE'
        ? const Color(0xFFF3E8FF)
        : role == 'AEE'
            ? const Color(0xFFE0F2FE)
        : role == 'EE'
          ? const Color(0xFFDCFCE7)
          : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Name + Role badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E0A3C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Jurisdiction details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F5FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _purpleLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                    _jurisdictionRow('Section', section),

                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                _actionButton(
                  context,
                  'Change Role',
                  Icons.edit,
                  const Color(0xFF0369A1),
                  () => _navigateToAction(context, officer, 'role'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  context,
                  'Change Jurisdiction',
                  Icons.location_on,
                  const Color(0xFF15803D),
                  () => _navigateToAction(context, officer, 'jurisdiction'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  context,
                  'Delete',
                  Icons.delete,
                  const Color(0xFFB91C1C),
                  () => _navigateToAction(context, officer, 'delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _jurisdictionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E0A3C),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _navigateToAction(
    BuildContext context,
    Map<String, dynamic> officer,
    String action,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficerActionScreen(
          officer: officer,
          action: action,
          onComplete: () {
            // Refresh the officers list
            setState(() {});
          },
        ),
      ),
    );
  }
}


class FadeSlideRoute extends PageRouteBuilder {
  final Widget page;

  FadeSlideRoute({required this.page})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide animation (starts slightly lower and moves to original position)
      const beginOffset = Offset(0.0, 0.05);
      const endOffset = Offset.zero;
      final offsetTween = Tween(begin: beginOffset, end: endOffset)
          .chain(CurveTween(curve: Curves.easeOutCubic));

      // Fade animation (goes from transparent to opaque)
      final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn));

      return SlideTransition(
        position: animation.drive(offsetTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
  );
}
