import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'Auth_Wrapper.dart';
import 'services/app_localizations.dart';
import 'services/language_provider.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';

Future<void> runDailyLeaveSync() async {
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final leaveSnap = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('status', isEqualTo: 'approved')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    int reassignedCount = 0;

    for (var doc in leaveSnap.docs) {
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp?)?.toDate();
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      final substituteEmail = data['substituteAssigned'] as String?;
      final originalEmail = data['email'] as String? ?? doc.id;

      if (startDate != null && endDate != null && substituteEmail != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        if (today.compareTo(start) >= 0 && today.compareTo(end) <= 0) {
          final complaintsSnap = await FirebaseFirestore.instance
              .collection('complaints')
              .where('assignedTo', isEqualTo: originalEmail)
              .where('status', whereIn: ['pending', 'pending_assignment', 'classified', 'in_progress', 'escalated', 'reopened'])
              .get();
          for (var complaintDoc in complaintsSnap.docs) {
            batch.update(complaintDoc.reference, {'assignedTo': substituteEmail});
            reassignedCount++;
          }
        }
      }
    }

    if (reassignedCount > 0) {
      await batch.commit();
      debugPrint('✅ Daily Sync: Reassigned $reassignedCount complaints due to active leaves.');
    } else {
      debugPrint('✅ Daily Sync: No pending complaints needed reassignment today.');
    }
  } catch (e) {
    debugPrint('❌ Error running daily leave sync: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await runDailyLeaveSync();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Civic Connect',
          locale: languageProvider.appLocale,
          supportedLocales: const [Locale('en'), Locale('ta')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.theme,
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PREMIUM SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;
  late Animation<double> _ringExpand;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _ringCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _logoFade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.7, curve: Curves.elasticOut)));
    _textFade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _pulse     = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _ringExpand = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _ringCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    _navigate();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            seenOnboarding ? const AuthWrapper() : const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.splashGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative circles
              Positioned(top: -60, right: -60,
                child: _decorCircle(220, Colors.white.withValues(alpha: 0.04))),
              Positioned(bottom: 80, left: -80,
                child: _decorCircle(260, Colors.white.withValues(alpha: 0.04))),
              Positioned(top: 120, left: 20,
                child: _decorCircle(60, Colors.white.withValues(alpha: 0.06))),
              Positioned(bottom: 180, right: 30,
                child: _decorCircle(40, AppColors.teal.withValues(alpha: 0.3))),

              // Language selector
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Consumer<LanguageProvider>(
                    builder: (ctx, lp, _) => GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      borderRadius: 20,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: lp.appLocale?.languageCode ?? 'en',
                          dropdownColor: AppColors.primaryDark,
                          icon: const Icon(Icons.expand_more, color: Colors.white, size: 18),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('🌐 English', style: TextStyle(color: Colors.white, fontSize: 13))),
                            DropdownMenuItem(value: 'ta', child: Text('🌐 தமிழ்',   style: TextStyle(color: Colors.white, fontSize: 13))),
                          ],
                          onChanged: (v) {
                            if (v != null) ctx.read<LanguageProvider>().changeLanguage(Locale(v));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expanding ring + logo
                    AnimatedBuilder(
                      animation: Listenable.merge([_ringCtrl, _pulseCtrl, _logoCtrl]),
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer expanding ring
                          Transform.scale(
                            scale: _ringExpand.value,
                            child: Container(
                              width: 180, height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12 * _ringExpand.value),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Pulsing glow ring
                          Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 140, height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          // Logo container
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Container(
                                width: 110, height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.teal.withValues(alpha: 0.3),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_city_rounded, size: 52, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // App name + tagline
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                children: [
                                  const TextSpan(text: 'Civic', style: TextStyle(color: Colors.white)),
                                  TextSpan(text: ' Connect', style: TextStyle(color: AppColors.teal)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Empowering Citizens · Building Cities',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom version
              Positioned(
                bottom: 20,
                left: 0, right: 0,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'v1.0 · Smart City Platform',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}