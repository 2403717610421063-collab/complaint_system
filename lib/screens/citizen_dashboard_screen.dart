import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:complaint_system/screens/nearby_complaints_screen.dart';
import 'package:complaint_system/screens/track_complaint_screen.dart';
import 'package:complaint_system/screens/add_complaint_screen.dart';
import 'package:complaint_system/screens/ProfileScreen.dart';
import 'package:complaint_system/screens/login_screen.dart';
import 'package:complaint_system/screens/BillingCalculatorPage.dart';
import 'package:complaint_system/location/tneb_lookup_screen.dart';
import 'package:complaint_system/models/complaint_model.dart';
import 'package:complaint_system/complaint_card.dart';
import 'package:complaint_system/screens/chat_list_screen.dart';
import '../theme/app_theme.dart';
import '../services/app_localizations.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() =>
      _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen>
    with SingleTickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  // ─── Status Tab Controller ────────────────────────────────────────────────────
  late TabController _statusTabController;

  /// Status filter tabs: label → list of status strings to match (lowercase)
  static const _statusTabs = [
    {
      'label': 'All',
      'key': 'all',
      'icon': Icons.list_alt_rounded,
      'color': Color(0xFF7B1FA2),
    },
    {
      'label': 'Pending',
      'key': 'pending',
      'icon': Icons.hourglass_empty_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'label': 'Assigned',
      'key': 'assigned',
      'icon': Icons.assignment_ind_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'label': 'In Progress',
      'key': 'in progress',
      'icon': Icons.pending_actions_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'label': 'Resolved',
      'key': 'resolved',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'label': 'Closed',
      'key': 'closed',
      'icon': Icons.lock_rounded,
      'color': Color(0xFF6B7280),
    },
    {
      'label': 'Rejected',
      'key': 'rejected',
      'icon': Icons.cancel_rounded,
      'color': Color(0xFFEF4444),
    },
  ];

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B1FA2);
  static const _purpleDark  = Color(0xFF4A148C);
  static const _purpleDeep  = Color(0xFF2D0060);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _bg          = Color(0xFFF4F3F9);

  @override
  void initState() {
    super.initState();
    _statusTabController = TabController(
      length: _statusTabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _statusTabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        FadeSlideRoute(page: const LoginScreen()),
            (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.translate('logout_confirm_title') ??
                  'Sign Out?',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.translate('logout_confirm_msg') ??
                  'Are you sure you want to sign out\nof your account?',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)?.translate('cancel') ??
                            'Cancel',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)?.translate('logout') ??
                            'Sign Out',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  List<Widget> get _screens => [
    _homeScreen(),
    const NearbyComplaintsScreen(),
    const TrackComplaintScreen(),
    BillingCalculatorPage(),
    const TNEBLookupScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _screens[_selectedIndex],
            ),
          ),

          if (_selectedIndex != 0)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16),
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') _showLogoutDialog();
                    },
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    elevation: 12,
                    shadowColor: const Color(0xFF4A148C).withOpacity(0.2),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.logout_rounded,
                                  color: Color(0xFFEF4444), size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)
                                  ?.translate('logout') ??
                                  'Sign Out',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C),
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A148C).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.more_vert_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────────────────
      floatingActionButton: _selectedIndex == 0
          ? Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_purple, _purpleDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.42),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            FadeSlideRoute(page: const AddComplaintScreen()),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            AppLocalizations.of(context)
                ?.translate('new_complaint') ??
                'New Complaint',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      )
          : null,

      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final loc = AppLocalizations.of(context);
    final items = [
      {
        'icon': Icons.home_outlined,
        'sel': Icons.home_rounded,
        'label': loc?.translate('home') ?? 'Home'
      },
      {
        'icon': Icons.location_on_outlined,
        'sel': Icons.location_on_rounded,
        'label': loc?.translate('nearby_complaints') ?? 'Nearby'
      },
      {
        'icon': Icons.radar_outlined,
        'sel': Icons.radar_rounded,
        'label': loc?.translate('track') ?? 'Track'
      },
      {
        'icon': Icons.bolt_outlined,
        'sel': Icons.bolt_rounded,
        'label': loc?.translate('bill') ?? 'Bill'
      },
      {
        'icon': Icons.electric_meter_outlined,
        'sel': Icons.electric_meter_rounded,
        'label': loc?.translate('tneb') ?? 'TNEB'
      },
      {
        'icon': Icons.person_outline_rounded,
        'sel': Icons.person_rounded,
        'label': loc?.translate('profile') ?? 'Profile'
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = _selectedIndex == i;
              final item = items[i];
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 14 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                      colors: [_purple, _purpleDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                        color: _purple.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected
                            ? item['sel'] as IconData
                            : item['icon'] as IconData,
                        size: 20,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFB0A8C8),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 5),
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── Home Screen ──────────────────────────────────────────────────────────────

  Widget _homeScreen() {
    return Column(
      children: [
        _buildHeader(),
        _buildStatusTabBar(),
        Expanded(child: _buildFilteredComplaintList()),
      ],
    );
  }

  // ─── Status Tab Bar ───────────────────────────────────────────────────────────

  Widget _buildStatusTabBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Count per status key
        final Map<String, int> counts = {
          for (final tab in _statusTabs) tab['key'] as String: 0
        };
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final status = ((doc.data() as Map)['status'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            counts['all'] = (counts['all'] ?? 0) + 1;
            for (final tab in _statusTabs) {
              final key = tab['key'] as String;
              if (key != 'all' && status.contains(key)) {
                counts[key] = (counts[key] ?? 0) + 1;
                break;
              }
            }
          }
        }

        return Container(
          color: Colors.white,
          child: TabBar(
            controller: _statusTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            labelPadding: const EdgeInsets.only(right: 8),
            onTap: (_) => setState(() {}),
            tabs: List.generate(_statusTabs.length, (i) {
              final tab = _statusTabs[i];
              final key = tab['key'] as String;
              final color = tab['color'] as Color;
              final icon = tab['icon'] as IconData;
              final label = tab['label'] as String;
              final count = counts[key] ?? 0;

              return _StatusTab(
                label: label,
                icon: icon,
                count: count,
                color: color,
                isSelected: _statusTabController.index == i,
              );
            }),
          ),
        );
      },
    );
  }

  // ─── Filtered Complaint List ──────────────────────────────────────────────────

  Widget _buildFilteredComplaintList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_purple),
              strokeWidth: 2.5,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final activeTabKey =
        _statusTabs[_statusTabController.index]['key'] as String;

        // Filter docs by active tab
        final allDocs = snapshot.data!.docs;
        final filtered = activeTabKey == 'all'
            ? allDocs
            : allDocs.where((doc) {
          final status = ((doc.data() as Map)['status'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          return status.contains(activeTabKey);
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyStateForStatus(
            _statusTabs[_statusTabController.index]['label'] as String,
            _statusTabs[_statusTabController.index]['color'] as Color,
            _statusTabs[_statusTabController.index]['icon'] as IconData,
          );
        }

        final complaints = filtered
            .map((doc) =>
            Complaint.fromFirestore(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          itemCount: complaints.length,
          itemBuilder: (context, index) => ComplaintCard(
            complaint: complaints[index],
            animIndex: index,
          ),
        );
      },
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _purpleDark, _purpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
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
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(
            bottom: 10, right: 80,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB06AFF).withOpacity(0.18)),
            ),
          ),
          Positioned(
            top: 50, left: -15,
            child: Container(
              width: 55, height: 55,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data =
                  snapshot.data?.data() as Map<String, dynamic>?;
                  final name = (data?['name'] ?? 'Citizen').toString();
                  final url = data?['url'] as String?;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${AppLocalizations.of(context)?.translate('welcome') ?? "Welcome back"} 👋',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color:
                                            Colors.white.withOpacity(0.4),
                                            width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                        Colors.white.withOpacity(0.2),
                                        backgroundImage: url != null
                                            ? NetworkImage(url)
                                            : null,
                                        child: url == null
                                            ? const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 20)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      name,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  AppLocalizations.of(context)?.translate(
                                      'dashboard') ??
                                      'Track and manage your complaints',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<dynamic>(
                            onSelected: (value) {
                              if (value == 'logout') {
                                _showLogoutDialog();
                              } else if (value is int) {
                                setState(() => _selectedIndex = value);
                              }
                            },
                            offset: const Offset(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.white,
                            elevation: 12,
                            itemBuilder: (context) => [
                              // --- Navigation Screens (The red lines will disappear once you add the helper below) ---

                              _buildPopupMenuItem(0, Icons.home_rounded, 'Home', const Color(0xFF7B1FA2)),
                          _buildPopupMenuItem(1, Icons.location_on_rounded, 'Nearby Complaints', const Color(0xFF10B981)),
                          _buildPopupMenuItem(2, Icons.radar_rounded, 'Track My Complaint', const Color(0xFF8B5CF6)),

                             const PopupMenuDivider(height: 1),

                          // --- Utility Tools ---
                          _buildPopupMenuItem(3, Icons.bolt_rounded, 'Bill Calculator', const Color(0xFFF59E0B)),
                          _buildPopupMenuItem(4, Icons.electric_meter_rounded, 'TNEB Lookup', const Color(0xFF3B82F6)),
                          _buildPopupMenuItem(5, Icons.person_rounded, 'My Profile', const Color(0xFF64748B)),

                             const PopupMenuDivider(height: 1),



                              const PopupMenuDivider(height: 1),

                              // --- Logout Action ---
                              PopupMenuItem<dynamic>(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Sign Out',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.25)),
                              ),
                              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildQuickStatsBanner(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats Banner ───────────────────────────────────────────────────────

  Widget _buildQuickStatsBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, resolved = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;
          resolved = docs
              .where((d) =>
          (d.data() as Map)['status']
              .toString()
              .toLowerCase()
              .contains('resolved') ||
              (d.data() as Map)['status']
                  .toString()
                  .toLowerCase()
                  .contains('closed'))
              .length;
          pending = total - resolved;
        }

        return Row(
          children: [
            _miniStat(
                total.toString(),
                AppLocalizations.of(context)?.translate('total') ?? 'Total'),
            const SizedBox(width: 8),
            _miniStat(
                pending.toString(),
                AppLocalizations.of(context)?.translate('pending') ??
                    'Pending'),
            const SizedBox(width: 8),
            _miniStat(
                resolved.toString(),
                AppLocalizations.of(context)?.translate('resolved') ??
                    'Resolved'),
          ],
        );
      },
    );
  }

  Widget _miniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<dynamic> _buildPopupMenuItem(int index, IconData icon, String label, Color iconColor) {
    return PopupMenuItem<dynamic>(
      value: index,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E0A3C),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty States ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _purpleLight,
                shape: BoxShape.circle,
              ),
              child:
              const Icon(Icons.inbox_rounded, color: _purple, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)?.translate('no_complaints') ??
                  'No Complaints Yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.translate('tap_plus') ??
                  'Tap "New Complaint" below to file\nyour first civic issue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateForStatus(
      String status, Color color, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'No $status Complaints',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no complaints\nwith "$status" status.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Tab Widget ────────────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  final bool isSelected;

  const _StatusTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected ? Colors.white : color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : color,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


}