import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/language_provider.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: GradientAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          _sectionHeader('Account'),
          _tile(
            icon: Icons.person_outline_rounded,
            iconColor: AppColors.primary,
            label: 'Edit Profile',
            onTap: () {},
          ),
          _tile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.statusInProgress,
            label: 'Change Password',
            onTap: () {},
          ),

          const SizedBox(height: 20),

          // Preferences
          _sectionHeader('Preferences'),
          _switchTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.warning,
            label: 'Push Notifications',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          _switchTile(
            icon: Icons.dark_mode_outlined,
            iconColor: const Color(0xFF6366F1),
            label: 'Dark Mode',
            subtitle: 'Coming soon',
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),

          const SizedBox(height: 20),

          // Language
          _sectionHeader('Language'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _langOption(context, lp, 'en', '🇬🇧', 'English'),
                const Divider(height: 1, indent: 56),
                _langOption(context, lp, 'ta', '🇮🇳', 'தமிழ்'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Support
          _sectionHeader('Support'),
          _tile(icon: Icons.help_outline_rounded,    iconColor: AppColors.teal,         label: 'Help & FAQ',       onTap: () {}),
          _tile(icon: Icons.privacy_tip_outlined,    iconColor: AppColors.statusAssigned, label: 'Privacy Policy', onTap: () {}),
          _tile(icon: Icons.description_outlined,    iconColor: AppColors.textSecondary,  label: 'Terms of Service', onTap: () {}),
          _tile(icon: Icons.info_outline_rounded,    iconColor: AppColors.textSecondary,  label: 'About App',       trailing: 'v1.0', onTap: () {}),

          const SizedBox(height: 20),

          // Logout
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                FadeSlideRoute(page: const LoginScreen()),
                (_) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
  );

  Widget _tile({required IconData icon, required Color iconColor, required String label, String? trailing, String? subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)) : null,
        trailing: trailing != null
            ? Text(trailing, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  Widget _switchTile({required IconData icon, required Color iconColor, required String label, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)) : null,
        trailing: Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  Widget _langOption(BuildContext context, LanguageProvider lp, String code, String flag, String name) {
    final selected = (lp.appLocale?.languageCode ?? 'en') == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
          : null,
      onTap: () => lp.changeLanguage(Locale(code)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    );
  }
}
