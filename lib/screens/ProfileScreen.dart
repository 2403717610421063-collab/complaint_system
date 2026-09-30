import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complaint_system/screens/edit_profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../services/app_localizations.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _primary     = AppColors.primary;
  static const _primaryDark = AppColors.primaryDark;
  static const _primaryMid  = AppColors.primaryMid;
  static const _primaryLight = Color(0xFFE3F0FF);
  static const _primaryBorder = Color(0xFFBDD8FF);

  Future<int> getComplaintCount(String uid, String status) async {
    try {
      QuerySnapshot snapshot;
      if (status == 'Resolved') {
        snapshot = await FirebaseFirestore.instance
            .collection('complaints')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: status)
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection('complaints')
            .where('userId', isEqualTo: uid)
            .where('status', isNotEqualTo: "Resolved")
            .get();
      }
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('Users')
            .doc(user?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                strokeWidth: 2.5,
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Error loading profile',
                style: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
              ),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final uid = user?.uid ?? '';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(context, userData, uid),
              ),

              // ── STATS ────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildStatsRow(uid, context),
                ),
              ),

              // ── PERSONAL DETAILS ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildSection(
                    icon: Icons.person_rounded,
                    title: AppLocalizations.of(context)?.translate('personal_details') ?? 'Personal Details',
                    child: Column(
                      children: [
                        _tile(Icons.phone_outlined, AppLocalizations.of(context)?.translate('phone_number') ?? 'Phone Number',
                            userData['phone']),
                        _tile(Icons.home_outlined, AppLocalizations.of(context)?.translate('address') ?? 'Home Address',
                            userData['address']),
                        _tile(Icons.cake_outlined, AppLocalizations.of(context)?.translate('date_of_birth') ?? 'Date of Birth',
                            userData['dob']),
                        _tile(Icons.badge_outlined, AppLocalizations.of(context)?.translate('aadhar_number') ?? 'Aadhar Number',
                            userData['aadhar']),
                        Row(
                          children: [
                            Expanded(
                              child: _tile(Icons.person_outline, AppLocalizations.of(context)?.translate('gender') ?? 'Gender',
                                  userData['gender'],
                                  compact: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _tile(Icons.water_drop_outlined,
                                  AppLocalizations.of(context)?.translate('blood_group') ?? 'Blood Group', userData['bloodGroup'],
                                  compact: true),
                            ),
                          ],
                        ),
                        if (userData['latitude'] != null)
                          _tile(
                            Icons.gps_fixed_rounded,
                            'Registered GPS Location',
                            'Lat: ${(userData['latitude'] as num).toStringAsFixed(4)}, '
                                'Lng: ${(userData['longitude'] as num).toStringAsFixed(4)}',
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── LANGUAGE ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildSection(
                    icon: Icons.language_rounded,
                    title: AppLocalizations.of(context)?.translate('language') ?? 'Language',
                    child: Consumer<LanguageProvider>(
                      builder: (context, lp, _) {
                        return Row(
                          children: [
                            _langChip(
                              context: context,
                              label: 'English',
                              locale: const Locale('en'),
                              lp: lp,
                            ),
                            const SizedBox(width: 10),
                            _langChip(
                              context: context,
                              label: 'தமிழ்',
                              locale: const Locale('ta'),
                              lp: lp,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── EDIT PROFILE BUTTON ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: _buildEditButton(context, userData),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, Map<String, dynamic> userData,
      String uid) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(top: -20, right: -30, child: Container(width: 170, height: 170, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
          Positioned(bottom: 30, right: 60, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.teal.withValues(alpha: 0.18)))),
          Positioned(top: 50, left: -15, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Top row: title + logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.translate('my_profile') ?? 'My Profile',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _signOut(context),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),

                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2.5),
                        ),
                      ),
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        backgroundImage: userData['url'] != null
                            ? NetworkImage(userData['url'])
                            : null,
                        child: userData['url'] == null
                            ? const Icon(Icons.person_rounded,
                            size: 46, color: AppColors.primary)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userData['name'] ?? 'Guest User',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      userData['email'] ?? '',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(String uid, BuildContext context) {
    return Row(
      children: [
        _statCard(uid, AppLocalizations.of(context)?.translate('pending') ?? 'Pending', Icons.hourglass_top_rounded,
            AppColors.warning, AppColors.warningLight),
        const SizedBox(width: 14),
        _statCard(uid, AppLocalizations.of(context)?.translate('resolved') ?? 'Resolved', Icons.verified_rounded,
            AppColors.success, AppColors.successLight),
      ],
    );
  }

  Widget _statCard(String uid, String status, IconData icon, Color color,
      Color bg) {
    return Expanded(
      child: FutureBuilder<int>(
        future: getComplaintCount(uid, status),
        builder: (context, snap) {
          final count = snap.data ?? 0;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    snap.connectionState == ConnectionState.waiting
                        ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(color)),
                    )
                        : Text(
                      count.toString(),
                      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1),
                    ),
                    const SizedBox(height: 3),
                    Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Section Card ─────────────────────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: _primary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── Profile Tile ─────────────────────────────────────────────────────────────

  Widget _tile(IconData icon, String label, String? value,
      {bool compact = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: _primary, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(
                  value ?? 'Not set',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: value != null ? AppColors.textPrimary : AppColors.borderColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Language Chip ────────────────────────────────────────────────────────────

  Widget _langChip({
    required BuildContext context,
    required String label,
    required Locale locale,
    required LanguageProvider lp,
  }) {
    final isSelected = lp.appLocale == locale;
    return Expanded(
      child: GestureDetector(
        onTap: () => lp.changeLanguage(locale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? AppGradients.warmGradient : null,
            color: isSelected ? null : _primaryLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? _primary : _primaryBorder, width: isSelected ? 0 : 1.5),
            boxShadow: isSelected ? [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.language_rounded, size: 16, color: isSelected ? Colors.white : _primary),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit Profile Button ──────────────────────────────────────────────────────

  Widget _buildEditButton(
      BuildContext context, Map<String, dynamic> userData) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(userData: userData),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: AppGradients.warmGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)?.translate('edit_profile') ?? 'Edit Profile',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}