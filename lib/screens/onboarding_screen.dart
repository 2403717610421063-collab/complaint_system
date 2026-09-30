import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  final _pages = const [
    _OnboardingData(
      icon: Icons.report_problem_rounded,
      iconBg: Color(0xFF1565C0),
      iconAccent: Color(0xFF42A5F5),
      gradient: [Color(0xFF0D47A1), Color(0xFF1976D2)],
      title: 'Report Issues Instantly',
      subtitle: 'Spot a civic problem? Report it in seconds with photos, location, and description — all from your phone.',
      badge: 'Fast & Easy',
    ),
    _OnboardingData(
      icon: Icons.radar_rounded,
      iconBg: Color(0xFF00838F),
      iconAccent: Color(0xFF26C6DA),
      gradient: [Color(0xFF00695C), Color(0xFF00ACC1)],
      title: 'Track in Real Time',
      subtitle: 'Follow your complaint\'s journey from submission to resolution with live status updates and official responses.',
      badge: 'Live Updates',
    ),
    _OnboardingData(
      icon: Icons.location_city_rounded,
      iconBg: Color(0xFF1B5E20),
      iconAccent: Color(0xFF4CAF50),
      gradient: [Color(0xFF1B5E20), Color(0xFF388E3C)],
      title: 'Build Better Cities',
      subtitle: 'Your voice matters. Every complaint you raise helps authorities improve infrastructure and quality of life.',
      badge: 'Make an Impact',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx);
    _iconCtrl.reset();
    _iconCtrl.forward();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(FadeSlideRoute(page: const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative shapes
          Positioned(top: -50, right: -50, child: _circle(200, Colors.white.withValues(alpha: 0.05))),
          Positioned(bottom: 200, left: -60, child: _circle(180, Colors.white.withValues(alpha: 0.04))),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _PageContent(
                      data: _pages[i],
                      iconScale: _iconScale,
                    ),
                  ),
                ),

                // Dots + CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Column(
                    children: [
                      SmoothPageIndicator(
                        controller: _pageCtrl,
                        count: _pages.length,
                        effect: ExpandingDotsEffect(
                          dotColor: Colors.white.withValues(alpha: 0.35),
                          activeDotColor: Colors.white,
                          dotHeight: 8,
                          dotWidth: 8,
                          expansionFactor: 3,
                          spacing: 6,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Next / Get Started
                      GestureDetector(
                        onTap: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            _finish();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage < _pages.length - 1 ? 'Continue' : 'Get Started',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: page.iconBg,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentPage < _pages.length - 1
                                      ? Icons.arrow_forward_rounded
                                      : Icons.rocket_launch_rounded,
                                  color: page.iconBg,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _PageContent extends StatelessWidget {
  final _OnboardingData data;
  final Animation<double> iconScale;

  const _PageContent({required this.data, required this.iconScale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          ScaleTransition(
            scale: iconScale,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(data.icon, size: 64, color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          // Badge chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              data.badge,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: Colors.white, height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final Color iconBg;
  final Color iconAccent;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardingData({
    required this.icon,
    required this.iconBg,
    required this.iconAccent,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}
