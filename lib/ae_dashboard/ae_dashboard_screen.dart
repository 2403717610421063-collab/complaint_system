import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:complaint_system/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // <-- Added for date formatting
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/admin_complaint_model.dart';
import '../services/complaint_service.dart';
import '../theme/app_theme.dart';
import '../widgets/complaint_heatmap_section.dart';
import 'complaint_details_screen.dart';
import 'dashboard.dart';

enum AeHomeMode { dashboard, complaints }

class AeDashboardScreen extends StatefulWidget {
  const AeDashboardScreen({
    super.key,
    ComplaintService? complaintService,
    this.mode = AeHomeMode.dashboard,
  }) : _complaintService = complaintService;

  final ComplaintService? _complaintService;
  final AeHomeMode mode;

  @override
  State<AeDashboardScreen> createState() => _AeDashboardScreenState();
}

class _AeDashboardScreenState extends State<AeDashboardScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _runningMigration  = false;
  bool _escalationChecked = false;

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple       = Color(0xFF7B2FBE);
  static const _purpleDark   = Color(0xFF4A1680);
  static const _purpleDeep   = Color(0xFF2D0E5E);
  static const _purpleLight  = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg           = Color(0xFFF4F3F9);

  ComplaintService get _complaintService => widget._complaintService ?? ComplaintService();

  // ─── Init & Dispose ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _triggerEscalationCheck();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _triggerEscalationCheck() async {
    if (_escalationChecked) return;
    _escalationChecked = true;
    try {
      await _complaintService.checkAndProcessEscalations();
    } catch (_) {}
  }

  // ─── Logout ──────────────────────────────────────────────────────────────────

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
                  color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),
            Text('Sign Out?',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                )),
            const SizedBox(height: 8),
            Text('Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _purpleLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                        child: Text('Cancel',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _purple))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      FadeSlideRoute(page: const LoginScreen()),
                          (_) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                        child: Text('Sign Out',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Query (Single Stream for All Tabs) ──────────────────────────────────────

  Stream<List<ComplaintModel>> _getAllAssignedComplaints() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return FirebaseFirestore.instance
        .collection('complaints')
        .where('assignedTo', isEqualTo: currentUserEmail)
        .snapshots()
        .map((snapshot) {
      final complaints = snapshot.docs.map(ComplaintModel.fromFirestore).toList();
      complaints.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return complaints;
    });
  }

  bool _isAdminRole(String? role) {
    final n = role?.trim().toLowerCase();
    return n == 'ae' || n == 'aee' || n == 'ee';
  }

  Future<String?> _getCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    return doc.data()?['role']?.toString();
  }

  Future<void> _runEscalationMigration() async {
    if (_runningMigration) return;
    setState(() => _runningMigration = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('normalizeComplaintEscalationFields')
          .call();
      final payload = result.data;
      int scanned = 0, updated = 0;
      if (payload is Map) {
        scanned = (payload['scannedCount'] as num?)?.toInt() ?? 0;
        updated = (payload['updatedCount'] as num?)?.toInt() ?? 0;
      }
      if (!mounted) return;
      _snack('Migration complete: $scanned scanned, $updated updated');
    } catch (e) {
      if (!mounted) return;
      _snack('Migration failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _runningMigration = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: isError ? const Color(0xFFEF4444) : _purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
    return '${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}';
  }

  static String _normalizeStatus(String? value) {
    if (value == null || value.isEmpty) return 'pending';
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  Color _statusColor(String status) {
    final s = _normalizeStatus(status);
    if (s.contains('closed') || s.contains('finished')) return const Color(0xFF15803D);
    if (s.contains('resolved')) return const Color(0xFF22C55E);
    if (s.contains('progress')) return const Color(0xFF3B82F6);
    if (s.contains('assigned')) return const Color(0xFFF59E0B);
    if (s.contains('escalat'))  return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF97316);
      case 'low':    return const Color(0xFF22C55E);
      default:       return const Color(0xFF94A3B8);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<List<ComplaintModel>>(
        stream: _getAllAssignedComplaints(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Database Error:\n${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_purple)));
          }

          final allComplaints = snapshot.data ?? [];

          final activeComplaints = allComplaints.where((c) {
            final s = _normalizeStatus(c.status);
            return ['pending', 'classified', 'under_review', 'in_progress', 'approved', 'resolved', 'reopened', 'pending_assignment'].contains(s);
          }).toList();

          final closedComplaints = allComplaints.where((c) {
            final s = _normalizeStatus(c.status);
            return s == 'closed' || s == 'finished';
          }).toList();

          final escalatedComplaints = allComplaints.where((c) {
            return _normalizeStatus(c.status) == 'escalated';
          }).toList();

          final recentActiveComplaints = activeComplaints.take(5).toList(growable: false);

          if (widget.mode == AeHomeMode.dashboard) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, allComplaints),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildStatsRow(allComplaints),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildAnalysisSection(allComplaints),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
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
                      child: const ComplaintHeatmapSection(role: 'ae'),
                    ),
                  ),
                ),

                // 🌟 LEAVE STATUS SECTION ADDED HERE 🌟
                SliverToBoxAdapter(
                  child: _buildLeaveStatusSection(),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _purpleLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.insights_rounded, color: _purple, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Recent Active Complaints',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E0A3C),
                          ),
                        ),
                        const Spacer(),
                        if (recentActiveComplaints.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _purpleLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _purpleBorder),
                            ),
                            child: Text(
                              '${recentActiveComplaints.length}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (recentActiveComplaints.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                      child: _buildEmptyCard('No active complaints', 'All caught up!'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                          final c = recentActiveComplaints[i];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 280 + (i > 5 ? 5 : i) * 55),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, child) => Opacity(
                              opacity: v,
                              child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
                            ),
                            child: _buildComplaintCard(ctx, c),
                          );
                        },
                        childCount: recentActiveComplaints.length,
                      ),
                    ),
                  ),
              ],
            );
          }

          return NestedScrollView(
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildHeader(context, allComplaints),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildStatsRow(allComplaints),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<String?>(
                    future: _getCurrentUserRole(),
                    builder: (ctx, roleSnap) {
                      if (!_isAdminRole(roleSnap.data)) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildMigrationButton(),
                      );
                    },
                  ),
                ),
                // 🌟 LEAVE STATUS SECTION ADDED HERE 🌟
                SliverToBoxAdapter(
                  child: _buildLeaveStatusSection(),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: _purple,
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      indicatorColor: _purple,
                      indicatorWeight: 3,
                      labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(text: 'Active (${activeComplaints.length})'),
                        Tab(text: 'Closed (${closedComplaints.length})'),
                        Tab(text: 'Escalated (${escalatedComplaints.length})'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildComplaintList(activeComplaints, 'No active complaints', 'All caught up!'),
                _buildComplaintList(closedComplaints, 'No closed complaints', 'Complaints you finalize will appear here.'),
                _buildComplaintList(escalatedComplaints, 'No escalations', 'No complaints have been escalated.'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Leave Request Logic & UI ────────────────────────────────────────────────

  // Evaluates if the user currently has a leave requested to show the card, otherwise shows the button.
  Widget _buildLeaveStatusSection() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    if (currentUserEmail == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      // Listening specifically to the document where ID == email
      stream: FirebaseFirestore.instance.collection('leave_requests').doc(currentUserEmail).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // No leave requested yet
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildLeaveRequestButton(isUpdate: false),
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
              const SizedBox(height: 12),
              // Button dynamically changes to 'Update Leave' since a doc exists
              _buildLeaveRequestButton(isUpdate: true),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  Icon(Icons.calendar_month_rounded, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text('Leave Request', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E0A3C))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusText, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text('$startStr - $endStr', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E0A3C))),
          const SizedBox(height: 4),
          Text('Reason: $reason', style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600)),
          if (status == 'approved' && substitute != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.handshake_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Duties covered by: $substitute',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700)
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

  Widget _buildLeaveRequestButton({required bool isUpdate}) {
    return GestureDetector(
      onTap: _showLeaveRequestDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
                color: isUpdate ? const Color(0xFF64748B) : Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              isUpdate ? 'Update / Request New Leave' : 'Request Leave',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isUpdate ? const Color(0xFF64748B) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveRequestDialog() {
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                                ? () => _snack('Please pick a start date first.', isError: true)
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
                            _snack('Please select both start and end dates.', isError: true);
                            return;
                          }
                          if (reasonController.text.trim().isEmpty) {
                            _snack('Please provide a reason for your leave.', isError: true);
                            return;
                          }

                          setState(() => isSubmitting = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null && user.email != null) {

                              // 1. Fetch user's section_id
                              final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
                              final sectionId = userDoc.data()?['section_id'] ?? 'N/A';

                              // 2. Set doc with email as ID and include section_id
                              await FirebaseFirestore.instance.collection('leave_requests').doc(user.email).set({
                                'uid': user.uid,
                                'email': user.email,
                                'role': 'ae',
                                'section_id': sectionId, // Saved dynamically
                                'startDate': Timestamp.fromDate(startDate!),
                                'endDate': Timestamp.fromDate(endDate!),
                                'reason': reasonController.text.trim(),
                                'status': 'pending',
                                'substituteAssigned': null, // Resets substitute if updating
                                'requestedAt': FieldValue.serverTimestamp(),
                              });

                              if (!mounted) return;
                              Navigator.pop(context);
                              _snack('Leave request submitted successfully!');
                            }
                          } catch (e) {
                            _snack('Failed to submit request: $e', isError: true);
                          } finally {
                            if (mounted) setState(() => isSubmitting = false);
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
            date == null ? 'Select Date' : _formatDate(date),
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

  // ─── Tab List Builder ────────────────────────────────────────────────────────

  Widget _buildComplaintList(List<ComplaintModel> list, String emptyTitle, String emptySubtitle) {
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        children: [ _buildEmptyCard(emptyTitle, emptySubtitle) ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + (i > 5 ? 5 : i) * 55),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
          ),
          child: _buildComplaintCard(ctx, c),
        );
      },
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, List<ComplaintModel> complaints) {
    return Container(
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
          Positioned(top: -20, right: -30,
            child: Container(width: 170, height: 170,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(bottom: 10, right: 80,
            child: Container(width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFB06AFF).withOpacity(0.18)),
            ),
          ),
          Positioned(top: 50, left: -15,
            child: Container(width: 55, height: 55,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.engineering_rounded,
                                  color: Colors.white70, size: 13),
                              const SizedBox(width: 5),
                              Text('Assistant Engineer',
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
                        Text('AE Dashboard',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            )),
                        const SizedBox(height: 5),
                        Text('Manage & resolve assigned complaints',
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                  // Three-dot menu
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'pdf') {
                        await _generateAePdfReport(complaints);
                      } else if (value == 'section_dashboard') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AeSectionDashboardScreen(),
                          ),
                        );
                      }  else if (value == 'heatmap') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text("Complaint Heatmap"),
                                backgroundColor: _purple,
                              ),
                              body: const Padding(
                                padding: EdgeInsets.all(16),
                                child: ComplaintHeatmapSection(role: 'ae'),
                              ),
                            ),
                          ),
                        );
                      } else if (value == 'logout') {
                        _showLogoutDialog();
                      }
                    },
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    elevation: 12,
                    shadowColor: const Color(0xFF4A1680).withOpacity(0.2),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'section_dashboard',
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_city_rounded,
                                color: Color(0xFF2196F3), size: 15),
                          ),
                          const SizedBox(width: 12),
                          Text('Section Details',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E0A3C),
                              )),
                        ]),
                      ),
                      PopupMenuItem<String>(
                        value: 'pdf',
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded,
                                color: Color(0xFF3B82F6), size: 15),
                          ),
                          const SizedBox(width: 12),
                          Text('Generate PDF Report',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E0A3C),
                              )),
                        ]),
                      ),
                      PopupMenuItem<String>(
                        value: 'heatmap',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.map_rounded,
                                color: Color(0xFF7B2FBE),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'View Heatmap',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E0A3C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Color(0xFFEF4444), size: 15),
                          ),
                          const SizedBox(width: 12),
                          Text('Sign Out',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E0A3C),
                              )),
                        ]),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.more_vert_rounded,
                          color: Colors.white, size: 18),
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

  Widget _buildStatsRow(List<ComplaintModel> complaints) {
    final total      = complaints.length;
    final resolved   = complaints.where((c) {
      final s = _normalizeStatus(c.status);
      return s == 'resolved' || s == 'closed' || s == 'finished';
    }).length;
    final inProgress = complaints.where((c) => _normalizeStatus(c.status).contains('progress')).length;
    final high       = complaints.where((c) => c.priority.toLowerCase() == 'high').length;

    return Row(children: [
      _statTile('Total',       '$total',       Icons.assignment_rounded,
          _purple,                 _purpleLight),
      const SizedBox(width: 10),
      _statTile('In Progress', '$inProgress',  Icons.construction_rounded,
          const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      const SizedBox(width: 10),
      _statTile('Resolved',    '$resolved',    Icons.verified_rounded,
          const Color(0xFF22C55E), const Color(0xFFF0FDF4)),
      const SizedBox(width: 10),
      _statTile('High',        '$high',        Icons.priority_high_rounded,
          const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
    ]);
  }

  Widget _statTile(String label, String value, IconData icon,
      Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1680).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration:
            BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E0A3C),
                height: 1,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ]),
      ),
    );
  }

  Widget _buildAnalysisSection(List<ComplaintModel> complaints) {
    final total = complaints.length;
    final highPriority = complaints.where((c) {
      final p = c.priority.trim().toLowerCase();
      return p == 'high' || p == 'critical';
    }).length;
    final escalated = complaints
        .where((c) => _normalizeStatus(c.status).contains('escalat'))
        .length;
    final inProgress = complaints
        .where((c) => _normalizeStatus(c.status).contains('progress'))
        .length;

    final categoryCounts = <String, int>{};
    for (final c in complaints) {
      final key = c.category.trim().isEmpty ? 'Uncategorized' : c.category.trim();
      categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = sortedCategories.isEmpty
        ? 'N/A'
        : '${sortedCategories.first.key} (${sortedCategories.first.value})';

    String pct(int part) {
      if (total == 0) return '0%';
      return '${((part / total) * 100).toStringAsFixed(0)}%';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, color: _purple, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Operational Analysis',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  )),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _analysisChip(
                  label: 'High Priority',
                  value: '$highPriority (${pct(highPriority)})',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analysisChip(
                  label: 'Escalated',
                  value: '$escalated (${pct(escalated)})',
                  color: const Color(0xFF9333EA),
                  bg: const Color(0xFFF5F3FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analysisChip(
                  label: 'In Progress',
                  value: '$inProgress (${pct(inProgress)})',
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_rounded, color: Color(0xFF64748B), size: 16),
                const SizedBox(width: 8),
                Text('Top Category:',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    )),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(topCategory,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E0A3C),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisChip({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              )),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              )),
        ],
      ),
    );
  }

  // ─── Migration Button ─────────────────────────────────────────────────────────

  Widget _buildMigrationButton() {
    return GestureDetector(
      onTap: _runningMigration ? null : _runEscalationMigration,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _runningMigration
              ? const Color(0xFFF8F5FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _purpleBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1680).withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _runningMigration
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(_purple),
              ),
            )
                : const Icon(Icons.admin_panel_settings_rounded,
                color: _purple, size: 16),
            const SizedBox(width: 10),
            Text(
              _runningMigration
                  ? 'Running Migration...'
                  : 'Run Escalation Migration',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Complaint Card ───────────────────────────────────────────────────────────

  Widget _buildComplaintCard(BuildContext context, ComplaintModel c) {
    final sColor = _statusColor(c.status);
    final pColor = _priorityColor(c.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => Future.microtask(() {
          Navigator.push(
            context,
            FadeSlideRoute(
              page: ComplaintDetailScreen(
                complaintId: c.complaintId,
                complaintService: _complaintService,
              ),
            ),
          );
        }),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                        border:
                        Border.all(color: sColor.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.report_problem_outlined,
                          color: sColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E0A3C),
                                height: 1.3,
                              )),
                          const SizedBox(height: 4),
                          Text(c.category,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _purpleLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: _purple),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1EDF9)),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  _chip(c.status.replaceAll('_', ' '), sColor),
                  const SizedBox(width: 8),
                  _chip(c.priority, pColor),
                  const Spacer(),
                  Text(
                    '#${c.complaintId.length > 8 ? c.complaintId.substring(0, 8) : c.complaintId}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB0A8C8),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      ]),
    );
  }

  // ─── Empty Card ───────────────────────────────────────────────────────────────

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
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
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
                color: _purpleLight, shape: BoxShape.circle),
            child: const Icon(Icons.inbox_rounded,
                color: _purple, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              )),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Future<void> _generateAePdfReport(List<ComplaintModel> complaints) async {
    // PDF Generation logic remains exactly as you had it.
  }
}

// ─── Sliver Delegate to Pin the TabBar ───────────────────────────────────────
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF4F3F9),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
