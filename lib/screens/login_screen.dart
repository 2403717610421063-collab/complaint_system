import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:complaint_system/screens/citizen_dashboard_screen.dart';
import 'package:complaint_system/screens/official_dashboard_screen.dart';
import 'package:complaint_system/screens/register_screen.dart';

import '../admin/admin_root.dart';
import '../ae_dashboard/ae_root.dart';
import '../aee_dashboard/aee_root.dart';
import '../ee_dashboard/ee_root.dart';
import '../services/app_localizations.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading         = false;
  bool _obscurePassword = true;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Password Reset ─────────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final resetCtrl = TextEditingController(text: _emailCtrl.text);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Reset Password',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Enter your registered email to receive a reset link.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            TextField(
              controller: resetCtrl,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: () async {
                if (resetCtrl.text.trim().isEmpty) return;
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: resetCtrl.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset link sent! Check your email.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              height: 50,
              child: Text('Send Reset Link',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
    resetCtrl.dispose();
  }

  // ── Login Logic ────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (!mounted) return;

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(cred.user!.uid).get();
      if (!mounted) return;
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User record not found.')));
        return;
      }

      final role         = userDoc.get('role') ?? '';
      final officialRole = ((userDoc.data() as Map<String, dynamic>).containsKey('officialRole')
          ? userDoc.get('officialRole').toString().trim()
          : '');

      if (role == 'ADMIN') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const AdminRoot()));
        return;
      }
      if (role == 'CITIZEN') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const CitizenDashboardScreen()));
        return;
      }
      if (officialRole == 'AE') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const AeRoot()));
      } else if (officialRole == 'AEE') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const AeeRoot()));
      } else if (officialRole == 'EE') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const EERoot()));
      } else if (officialRole == 'Lineman' || officialRole == 'Foreman') {
        Navigator.pushReplacement(context, FadeSlideRoute(page: const FieldWorkerMainScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Role '$officialRole' not recognized")),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found')   message = 'No user found for this email.';
      if (e.code == 'wrong-password')   message = 'Wrong password provided.';
      if (e.code == 'invalid-credential') message = 'Invalid email or password.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Wave Header ──────────────────────────────────────────────────
            SizedBox(
              height: size.height * 0.38,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppGradients.headerGradient,
                    ),
                  ),
                  // Decorative circles
                  Positioned(top: -40, right: -40,
                      child: _deco(160, Colors.white.withValues(alpha: 0.06))),
                  Positioned(bottom: 30, left: -30,
                      child: _deco(120, AppColors.teal.withValues(alpha: 0.15))),
                  Positioned(top: 60, right: 60,
                      child: _deco(50, Colors.white.withValues(alpha: 0.08))),
                  // Wave clipper at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: ClipPath(
                      clipper: _WaveClipper(),
                      child: Container(height: 40, color: AppColors.surface),
                    ),
                  ),
                  // Logo + title
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 86, height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                              boxShadow: [
                                BoxShadow(color: AppColors.teal.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                              ],
                            ),
                            child: const Icon(Icons.location_city_rounded, size: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800),
                            children: [
                              const TextSpan(text: 'Civic', style: TextStyle(color: Colors.white)),
                              TextSpan(text: ' Connect', style: TextStyle(color: AppColors.teal)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.translate('signin_to_account') ?? 'Sign in to your account',
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Form Card ───────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      boxShadow: AppShadows.elevated,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.translate('welcome') ?? 'Welcome back 👋',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)?.translate('enter_credentials') ?? 'Enter your credentials to continue',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),

                        // Email
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('email') ?? 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.translate('password') ?? 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: Text(
                              AppLocalizations.of(context)?.translate('forgot_password') ?? 'Forgot Password?',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Sign In button
                        GradientButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  AppLocalizations.of(context)?.translate('login') ?? 'Sign In',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Register button
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            FadeSlideRoute(page: const RegisterScreen()),
                          ),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: Text(
                            AppLocalizations.of(context)?.translate('register') != null
                                ? 'Create Account · ${AppLocalizations.of(context)!.translate('register')}'
                                : 'Create a New Account',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deco(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.5);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}