import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Import your existing components
import 'package:complaint_system/models/complaint_model.dart';
import 'package:complaint_system/screens/JobDetailsScreen.dart';
import 'package:complaint_system/screens/login_screen.dart';

// Make sure you link to the new EditProfileScreen file you will create below
import 'edit_profile_screen.dart';

// --- SHARED THEME CONSTANTS ---
const Color _purple = Color(0xFF7B2FBE);
const Color _purpleDark = Color(0xFF4A1680);
const Color _purpleDeep = Color(0xFF2D0E5E);
const Color _purpleLight = Color(0xFFF3E8FF);
const Color _bg = Color(0xFFF3F0FA);

// --- SHARED LOGOUT METHOD ---
void _performLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Sign Out?"),
      content: const Text("Are you sure you want to log out?"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
            }
          },
          child: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. MAIN NAVIGATION WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class FieldWorkerMainScreen extends StatefulWidget {
  const FieldWorkerMainScreen({super.key});

  @override
  State<FieldWorkerMainScreen> createState() => _FieldWorkerMainScreenState();
}

class _FieldWorkerMainScreenState extends State<FieldWorkerMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const ComplaintsListTab(),
    const DashboardTab(),
    const LeaveTab(), // <-- NEW LEAVE TAB
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: _purple,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Jobs'),
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            // NEW LEAVE TAB ICON
            BottomNavigationBarItem(icon: Icon(Icons.edit_calendar_outlined), activeIcon: Icon(Icons.edit_calendar), label: 'Leave'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. COMPLAINTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class ComplaintsListTab extends StatefulWidget {
  const ComplaintsListTab({super.key});

  @override
  State<ComplaintsListTab> createState() => _ComplaintsListTabState();
}

class _ComplaintsListTabState extends State<ComplaintsListTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String workerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Users').doc(workerId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: _purple));
        final workerData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _PremiumHeader(
                title: workerData['officialRole'] ?? "Field Official",
                subtitle: workerData['name'] ?? 'Worker',
                icon: Icons.engineering_rounded,
                onLogout: () => _performLogout(context),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                height: 70.0,
                child: Container(
                  color: _bg,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _buildTabBar(),
                ),
              ),
            ),
            _buildJobList(workerId),
          ],
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _purple),
        labelColor: Colors.white, unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [Tab(text: "Active Jobs"), Tab(text: "Resolved History")],
      ),
    );
  }

  Widget _buildJobList(String workerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('complaints').where('assignedWorkerIds', arrayContains: workerId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _purple)));

        final docs = snapshot.data!.docs.where((doc) {
          final s = doc['status'].toString().toLowerCase();
          final isDone = s.contains('resolved') || s.contains('closed');
          return _tabCtrl.index == 0 ? !isDone : isDone;
        }).toList();

        if (docs.isEmpty) {
          return SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox_rounded, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text("All caught up!", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          ])));
        }

        docs.sort((a, b) => (b['createdAt'] as Timestamp? ?? Timestamp.now()).compareTo(a['createdAt'] as Timestamp? ?? Timestamp.now()));

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final comp = Complaint.fromWorkerFirestore(docs[i].data() as Map<String, dynamic>, docs[i].id);
              return _JobCard(complaint: comp);
            }, childCount: docs.length),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. DASHBOARD TAB
// ─────────────────────────────────────────────────────────────────────────────

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  Future<Map<String, dynamic>> _fetchFullDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");

    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final sectionId = userData['section_id'] ?? '';
    Map<String, dynamic> sectionData = {};
    if (sectionId.isNotEmpty) {
      final secDoc = await FirebaseFirestore.instance.collection('sections').doc(sectionId).get();
      if (secDoc.exists) sectionData = secDoc.data()!;
    }
    return {'user': userData, 'section': sectionData};
  }

  void _navigateToOffice(dynamic lat, dynamic lng) async {
    final uri = Uri.parse("google.navigation:q=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng"));
    }
  }

  Widget _buildStatsRow(String workerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('complaints').where('assignedWorkerIds', arrayContains: workerId).snapshots(),
      builder: (context, snap) {
        int active = 0, resolved = 0;
        if (snap.hasData) {
          for (var doc in snap.data!.docs) {
            final s = doc['status'].toString().toLowerCase();
            if (s.contains('resolved') || s.contains('closed')) resolved++;
            else active++;
          }
        }
        return Row(children: [
          _statCard('Total', (active + resolved).toString(), Icons.assignment_rounded, _purple, _purpleLight),
          const SizedBox(width: 10),
          _statCard('Active', active.toString(), Icons.construction_rounded, Colors.blue, const Color(0xFFEFF6FF)),
          const SizedBox(width: 10),
          _statCard('Resolved', resolved.toString(), Icons.verified_rounded, Colors.green, const Color(0xFFF0FDF4)),
        ]);
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchFullDashboardData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _purple)));

        final u = snapshot.data!['user'];
        final s = snapshot.data!['section'];
        final workerId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return Scaffold(
          backgroundColor: _bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _PremiumHeader(
                  title: "Section Dashboard",
                  subtitle: u['section_id'] ?? 'General Overview',
                  icon: Icons.dashboard_rounded,
                  onLogout: () => _performLogout(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildStatsRow(workerId),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildInfoCard("Official Details", Icons.badge_rounded, [
                      _tile(Icons.person, "Name", u['name']),
                      _tile(Icons.email, "Email", u['email']),
                      _tile(Icons.work_outline, "Role", u['officialRole']),
                      _tile(Icons.phone, "Phone", u['phone']),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard("Jurisdiction: ${u['section_id'] ?? 'N/A'}", Icons.map_rounded, [
                      _tile(Icons.account_balance, "Section", s['section_name']),
                      _tile(Icons.account_tree, "Subdivision", s['subdivision_name']),
                      _tile(Icons.business, "Division", s['division_name']),
                      const Divider(height: 24),
                      _tile(
                          Icons.location_on,
                          "Coordinates",
                          (s['office_lat'] != null && s['office_lon'] != null)
                              ? "${s['office_lat']}, ${s['office_lon']}"
                              : "Not Available"
                      ),
                      const SizedBox(height: 12),
                      if (s['office_lat'] != null && s['office_lon'] != null && s['office_lat'].toString().isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: () => _navigateToOffice(s['office_lat'], s['office_lon']),
                          icon: const Icon(Icons.navigation_rounded),
                          label: Text("Navigate to Office", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
                        )
                    ]),
                  ]),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, IconData headerIcon, List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _purpleLight, borderRadius: BorderRadius.circular(10)), child: Icon(headerIcon, color: _purple, size: 18)),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: _purple, fontSize: 16)),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]),
  );

  Widget _tile(IconData icon, String label, String? val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey.shade400),
      const SizedBox(width: 12),
      Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
      Expanded(child: Text(val ?? "N/A", style: const TextStyle(color: Colors.black54, fontSize: 13))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. LEAVE MANAGEMENT TAB (NEW)
// ─────────────────────────────────────────────────────────────────────────────

class LeaveTab extends StatelessWidget {
  const LeaveTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final docId = (user?.email != null && user!.email!.isNotEmpty) ? user.email! : user?.uid;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _PremiumHeader(
              title: "Leave Management",
              subtitle: "Request & Track",
              icon: Icons.event_note_rounded,
              onLogout: () => _performLogout(context),
            ),
          ),
          if (docId != null)
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('leave_requests').doc(docId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                      child: _buildLeaveRequestButton(context, isUpdate: false),
                    );
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final status = data['status'] as String? ?? 'pending';
                  final startTs = data['startDate'] as Timestamp?;
                  final endTs = data['endDate'] as Timestamp?;
                  final reason = data['reason'] as String? ?? '';
                  final substitute = data['substituteAssigned'] as String?;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _leaveStatusCard(status, startTs, endTs, reason, substitute),
                        const SizedBox(height: 16),
                        _buildLeaveRequestButton(context, isUpdate: true),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaveStatusCard(String status, Timestamp? start, Timestamp? end, String reason, String? substitute) {
    Color statusColor;
    Color statusBg;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusBg = Colors.green.shade50;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusBg = Colors.red.shade50;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusBg = Colors.orange.shade50;
        statusText = 'Pending Approval';
    }

    final startStr = start != null ? DateFormat('MMM dd').format(start.toDate()) : 'N/A';
    final endStr = end != null ? DateFormat('MMM dd, yyyy').format(end.toDate()) : 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Text('Current Request', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E0A3C))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusText, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text('$startStr - $endStr', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E0A3C))),
          const SizedBox(height: 6),
          Text('Reason: $reason', style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600)),
          if (status == 'approved' && substitute != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.handshake_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Duties covered by: $substitute',
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade700)
                      )
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildLeaveRequestButton(BuildContext context, {required bool isUpdate}) {
    return GestureDetector(
      onTap: () => _showLeaveRequestDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUpdate
                ? [Colors.white, Colors.white]
                : const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: isUpdate ? Border.all(color: const Color(0xFFE2E8F0)) : null,
          boxShadow: isUpdate ? [] : [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isUpdate ? Icons.edit_calendar_rounded : Icons.event_busy_rounded,
                color: isUpdate ? const Color(0xFF64748B) : Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              isUpdate ? 'Update / Request New Leave' : 'Request Leave',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isUpdate ? const Color(0xFF64748B) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveRequestDialog(BuildContext context) {
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickDate(bool isStart) async {
              final initialDate = isStart
                  ? (startDate ?? DateTime.now())
                  : (endDate ?? startDate ?? DateTime.now());

              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: _purple,
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF1E0A3C),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setState(() {
                  if (isStart) {
                    startDate = picked;
                    if (endDate != null && endDate!.isBefore(startDate!)) {
                      endDate = null;
                    }
                  } else {
                    endDate = picked;
                  }
                });
              }
            }

            void showSnack(String msg, {bool isError = false}) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                  backgroundColor: isError ? Colors.red : Colors.green,
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Request Leave',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFF1E0A3C),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => pickDate(true),
                            child: _dateBox('Start Date', startDate),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: startDate == null
                                ? () => showSnack('Please pick a start date first.', isError: true)
                                : () => pickDate(false),
                            child: _dateBox('End Date', endDate),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reason for Leave',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: GoogleFonts.nunito(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'E.g., Medical leave, family function...',
                        hintStyle: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (startDate == null || endDate == null) {
                            showSnack('Please select both dates.', isError: true);
                            return;
                          }
                          if (reasonController.text.trim().isEmpty) {
                            showSnack('Please provide a reason.', isError: true);
                            return;
                          }

                          setState(() => isSubmitting = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              // Use email as docID, fallback to UID
                              final docId = (user.email != null && user.email!.isNotEmpty) ? user.email! : user.uid;

                              // 1. Fetch user data dynamically to ensure role and section_id are attached
                              final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
                              final sectionId = userDoc.data()?['section_id'] ?? 'N/A';
                              final officialRole = userDoc.data()?['officialRole'] ?? 'worker';

                              // 2. Submit Leave Request
                              await FirebaseFirestore.instance.collection('leave_requests').doc(docId).set({
                                'uid': user.uid,
                                'email': user.email ?? 'No Email',
                                'role': officialRole, // e.g., Foreman or Lineman
                                'section_id': sectionId,
                                'startDate': Timestamp.fromDate(startDate!),
                                'endDate': Timestamp.fromDate(endDate!),
                                'reason': reasonController.text.trim(),
                                'status': 'pending',
                                'substituteAssigned': null,
                                'requestedAt': FieldValue.serverTimestamp(),
                              });

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              showSnack('Leave request submitted!');
                            }
                          } catch (e) {
                            showSnack('Failed to submit: $e', isError: true);
                          } finally {
                            if (context.mounted) setState(() => isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : Text(
                          'Submit',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dateBox(String label, DateTime? date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(date),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: date == null ? const Color(0xFF94A3B8) : const Color(0xFF1E0A3C),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _purple));
          final data = snapshot.data!.data() as Map<String, dynamic>;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _PremiumHeader(
                  title: "My Profile",
                  subtitle: data['name'] ?? 'Worker',
                  icon: Icons.person,
                  onLogout: () => _performLogout(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        children: [
                          _profItem("Phone", data['phone']),
                          _profItem("Email", data['email']),
                          _profItem("Gender", data['gender']),
                          _profItem("Date of Birth", data['dob']),
                          _profItem("Aadhar Number", data['aadhar']),
                          _profItem("Blood Group", data['bloodGroup']),
                          _profItem("Address", data['address'], isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(userData: data)));
                      },
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: Text("Edit Contact Info", style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ]),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _profItem(String label, dynamic val, {bool isLast = false}) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 20),
            Flexible(child: Text(val?.toString() ?? "Not Provided", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: Color(0xFFF1EDF9)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. HELPER COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onLogout;

  const _PremiumHeader({required this.title, required this.subtitle, required this.icon, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_purple, _purpleDark, _purpleDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white.withOpacity(0.35), width: 2)),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                tooltip: "Logout",
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Complaint complaint;
  const _JobCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final bool isCrew = complaint.assignedWorkerIds.length > 1;

    Color pColor; Color pBg;
    switch (complaint.priority.toLowerCase()) {
      case 'high':   pColor = const Color(0xFFEF4444); pBg = const Color(0xFFFEF2F2); break;
      case 'medium': pColor = const Color(0xFFF97316); pBg = const Color(0xFFFFF7ED); break;
      default:       pColor = const Color(0xFF22C55E); pBg = const Color(0xFFF0FDF4); break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(task: complaint))),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 5))]),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: pBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: pColor.withOpacity(0.25))),
                      child: Icon(isCrew ? Icons.groups_outlined : Icons.build_circle_outlined, color: pColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCrew) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("CREW ASSIGNED", style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w800, color: _purple, letterSpacing: 0.5))),
                          Text(complaint.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E0A3C), height: 1.3)),
                          const SizedBox(height: 4),
                          Text(DateFormat('MMM d, yyyy').format(complaint.date), style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _purpleLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _purple)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(12)),
                  child: Text(complaint.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 12.5, color: const Color(0xFF475569), fontWeight: FontWeight.w500, height: 1.5)),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1EDF9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: pBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: pColor.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(complaint.priority, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: pColor)),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child, required this.height});
  final Widget child;
  final double height;

  @override double get minExtent => height;
  @override double get maxExtent => height;

  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(height: height, child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}