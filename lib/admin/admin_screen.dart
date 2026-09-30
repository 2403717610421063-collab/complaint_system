import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complaint_system/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleDeep  = Color(0xFF2D0E5E);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg          = Color(0xFFF3F0FA);

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _sectionLabel(Icons.dashboard_rounded, 'System Overview'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildQuickStats(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _sectionLabel(Icons.pie_chart_rounded, 'Official Distribution'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildOfficialPieChart(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _sectionLabel(Icons.alt_route_rounded, 'Routing Capacity'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _buildRoutingStats(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
              child: _buildDashboardHint(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _purpleDark, _purpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -30,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 10, right: 80,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB06AFF).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            top: 50, left: -15,
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_rounded, color: Colors.white70, size: 13),
                              const SizedBox(width: 5),
                              Text('Administrator',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Admin Portal',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            )),
                        const SizedBox(height: 5),
                        Text('Manage officials, complaints & routing',
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                        context, FadeSlideRoute(page: const LoginScreen())),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Label ────────────────────────────────────────────────────────────

  Widget _sectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _purpleLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _purple, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            )),
      ],
    );
  }

  // ─── Quick Stats ──────────────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _shimmerRow();

        final total = snapshot.data!.docs.length;
        final officials = snapshot.data!.docs
            .where((d) => (d.data() as Map<String, dynamic>)['role'] == 'OFFICIAL')
            .length;
        final citizens = total - officials - 1;

        return Row(
          children: [
            _statTile(
              label: 'Citizens',
              value: citizens.toString(),
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF0EA5E9),
              bg: const Color(0xFFE0F2FE),
            ),
            const SizedBox(width: 14),
            _statTile(
              label: 'Officials',
              value: officials.toString(),
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFFF97316),
              bg: const Color(0xFFFFF7ED),
            ),
          ],
        );
      },
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1680).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E0A3C),
                      height: 1,
                    )),
                const SizedBox(height: 3),
                Text(label,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pie Chart ────────────────────────────────────────────────────────────────

  Widget _buildOfficialPieChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'OFFICIAL')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _loadingCard(height: 300);

        final docs = snapshot.data!.docs;
        final ae  = docs.where((d) => (d.data() as Map)['officialRole'] == 'AE').length;
        final aee = docs.where((d) => (d.data() as Map)['officialRole'] == 'AEE').length;
        final ee  = docs.where((d) => (d.data() as Map)['officialRole'] == 'EE').length;
        final total = docs.length;

        if (total == 0) return _emptyCard('No Officials Registered Yet');

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A1680).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 56,
                    sections: [
                      _pieSection(ae.toDouble(),  const Color(0xFF7B2FBE), 'AE'),
                      _pieSection(aee.toDouble(), const Color(0xFF0EA5E9), 'AEE'),
                      _pieSection(ee.toDouble(),  const Color(0xFF22C55E), 'EE'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('$total Officials',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  )),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF1EDF9)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legendTile('AE',  ae,  const Color(0xFF7B2FBE)),
                  _legendTile('AEE', aee, const Color(0xFF0EA5E9)),
                  _legendTile('EE',  ee,  const Color(0xFF22C55E)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  PieChartSectionData _pieSection(double value, Color color, String title) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? value.toInt().toString() : '',
      radius: 32,
      titleStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
    );
  }

  Widget _legendTile(String role, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(role,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
          ),
        ),
        const SizedBox(height: 6),
        Text('$count Staff',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            )),
      ],
    );
  }

  // ─── Routing Stats ────────────────────────────────────────────────────────────

  Widget _buildRoutingStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'FIELD_WORKER')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _loadingCard(height: 140);

        final docs = snapshot.data!.docs;
        int freeCount = 0, busyCount = 0, offlineCount = 0;
        int activeJobs = 0, totalCapacity = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'free').toString().toLowerCase();
          final jobs = (data['activeJobs'] ?? 0) is num
              ? (data['activeJobs'] as num).toInt()
              : int.tryParse((data['activeJobs'] ?? '0').toString()) ?? 0;
          final maxJobs = (data['maxJobs'] ?? 3) is num
              ? (data['maxJobs'] as num).toInt()
              : int.tryParse((data['maxJobs'] ?? '3').toString()) ?? 3;

          if (status == 'offline') offlineCount++;
          else if (status == 'busy') busyCount++;
          else freeCount++;

          activeJobs += jobs;
          totalCapacity += maxJobs;
        }

        final pct = totalCapacity > 0
            ? (activeJobs / totalCapacity).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A1680).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _workerTile('Free',    freeCount,    Icons.check_circle_rounded,
                      const Color(0xFF22C55E), const Color(0xFFF0FDF4)),
                  const SizedBox(width: 10),
                  _workerTile('Busy',    busyCount,    Icons.work_rounded,
                      const Color(0xFFF97316), const Color(0xFFFFF7ED)),
                  const SizedBox(width: 10),
                  _workerTile('Offline', offlineCount, Icons.block_rounded,
                      const Color(0xFF94A3B8), const Color(0xFFF1F5F9)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _purpleLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: _purple, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Active Jobs',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                )),
                            Text('$activeJobs / $totalCapacity',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _purple,
                                )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: _purpleBorder,
                            valueColor: const AlwaysStoppedAnimation(_purple),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _workerTile(String label, int count, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(count.toString(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1,
                )),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.8),
                )),
          ],
        ),
      ),
    );
  }

  // ─── Dashboard Hint ──────────────────────────────────────────────────────────

  Widget _buildDashboardHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _purpleLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.touch_app_rounded, color: _purple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Use the bottom tabs for Register and Officers. This page is the admin overview dashboard.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────────

  Widget _loadingCard({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_purple),
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _shimmerRow() {
    return Row(
      children: List.generate(2, (i) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: i == 0 ? 14 : 0),
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      )),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: _purpleLight, shape: BoxShape.circle),
            child: const Icon(Icons.analytics_outlined, color: _purple, size: 32),
          ),
          const SizedBox(height: 14),
          Text(message,
              style: GoogleFonts.nunito(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}