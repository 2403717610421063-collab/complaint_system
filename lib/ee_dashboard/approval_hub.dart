import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/admin_complaint_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApprovalHub — EE Executive War Room
//  • Full premium redesign matching EEHome purple theme
//  • GO Number support for formal approvals
//  • Rejection with mandatory reason
//  • Budget sanction with validation
//  • Real-time Firestore listener
//  • Animated action buttons with loading states
//  • Timeline / audit trail section
//  • Court case & CPGRAMS priority flags
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalHub extends StatefulWidget {
  final ComplaintModel complaint;
  const ApprovalHub({super.key, required this.complaint});

  @override
  State<ApprovalHub> createState() => _ApprovalHubState();
}

class _ApprovalHubState extends State<ApprovalHub>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _budgetCtrl    = TextEditingController();
  final _goNumberCtrl  = TextEditingController();
  final _remarkCtrl    = TextEditingController();
  final _rejectCtrl    = TextEditingController();

  bool _saving          = false;
  bool _showRejectPanel = false;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // ── Theme palette ────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleDeep  = Color(0xFF2D0E5E);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder= Color(0xFFE9D8FD);
  static const _bg          = Color(0xFFF3F0FA);
  static const _red         = Color(0xFFEF4444);
  static const _amber       = Color(0xFFF97316);
  static const _green       = Color(0xFF22C55E);
  static const _ink         = Color(0xFF1E0A3C);
  static const _muted       = Color(0xFF64748B);
  static const _slate       = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _goNumberCtrl.dispose();
    _remarkCtrl.dispose();
    _rejectCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _normalizeRole(String role) {
    final n = role.trim().toLowerCase();
    if (n == 'aee') return 'aee';
    if (n == 'ee')  return 'ee';
    return 'ae';
  }

  String _normalizeStatus(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), '_');

  String _prettyStatus(String s) => _normalizeStatus(s)
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Color _priorityColor(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':   return _red;
      case 'medium': return _amber;
      default:       return _green;
    }
  }

  Color _statusColor(String s) {
    final n = _normalizeStatus(s);
    if (n.contains('resolved') || n.contains('closed')) return _green;
    if (n.contains('progress'))  return const Color(0xFF3B82F6);
    if (n.contains('escalat'))   return _red;
    if (n.contains('approved'))  return const Color(0xFF8B5CF6);
    if (n.contains('assigned'))  return _amber;
    return _slate;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? _red : _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Core transaction helper ───────────────────────────────────────────────

  Future<void> _runTransaction(
      Map<String, dynamic> updates, String successMsg) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Complaint not found.');

        final data = snap.data() ?? {};
        final role = _normalizeRole(
            (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString());

        if (role != 'ee') {
          throw StateError('Ownership has changed. EE actions are read-only.');
        }

        updates['assignedRole']    = 'ee';
        updates['currentOwnerRole']= 'EE';
        updates['escalationLevel'] = 3;
        updates['lastUpdated']     = FieldValue.serverTimestamp();

        tx.update(ref, updates);
      });

      _snack(successMsg);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _approveAction(String actionLabel) async {
    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0.0;
    if (budget <= 0) {
      _snack('Please enter a valid budget amount before approving.', isError: true);
      return;
    }
    await _runTransaction({
      'status':          'approved',
      'allocatedBudget': budget,
      'eeActionTaken':   actionLabel,
      'goNumber':        _goNumberCtrl.text.trim(),
      'eeRemark':        _remarkCtrl.text.trim(),
      'approvedAt':      FieldValue.serverTimestamp(),
    }, 'Executive action approved successfully');
  }

  Future<void> _rejectComplaint() async {
    final reason = _rejectCtrl.text.trim();
    if (reason.length < 10) {
      _snack('Please provide a detailed rejection reason (min 10 chars).', isError: true);
      return;
    }
    await _runTransaction({
      'status':          'rejected',
      'rejectionReason': reason,
      'rejectedAt':      FieldValue.serverTimestamp(),
    }, 'Complaint rejected with formal reason logged');
  }

  Future<void> _markResolved() async {
    await _runTransaction({
      'status':     'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'eeRemark':   _remarkCtrl.text.trim(),
    }, 'Complaint marked as resolved');
  }

  Future<void> _reopenToAe() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Complaint not found.');

        final data = snap.data() ?? {};
        final role = _normalizeRole(
            (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString());

        if (role != 'ee') {
          throw StateError('Ownership changed. EE actions are read-only.');
        }

        tx.update(ref, {
          'status':           'reopened',
          'assignedRole':     'ae',
          'currentOwnerRole': 'AE',
          'escalationLevel':  1,
          'assignedAt':       FieldValue.serverTimestamp(),
          'lastUpdated':      FieldValue.serverTimestamp(),
          'eeRemark':         _remarkCtrl.text.trim(),
        });
      });

      _snack('Complaint reopened to AE workflow');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Failed to reopen complaint: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final isEscalated = _normalizeStatus(c.status).contains('escalat');
    final isCourtCase = c.additionalData?['isCourtCase'] == true;
    final isCpgrams   = c.additionalData?['isCpgrams']   == true;

    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .doc(c.complaintId)
            .snapshots(),
        builder: (context, snap) {
          final live         = snap.data?.data() ?? <String, dynamic>{};
          final liveRole     = _normalizeRole(
              (live['assignedRole'] ?? c.assignedRole).toString());
          final liveStatus   = live['status']?.toString() ?? c.status;
          final canEdit      = !_saving && liveRole == 'ee';
          final isReadOnly   = liveRole != 'ee';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(c, isEscalated, isCourtCase, isCpgrams)),

              if (isReadOnly)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _readOnlyBanner(),
                  ),
                ),

              if (isEscalated)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _escalationBanner(),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _complaintDetailCard(c, liveStatus),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _budgetGoCard(canEdit),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _remarkCard(canEdit),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _sanctionCard(canEdit),
                ),
              ),

              if (_showRejectPanel)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _rejectPanel(canEdit),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                  child: _bottomActions(canEdit),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ComplaintModel c, bool isEscalated,
      bool isCourtCase, bool isCpgrams) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _purpleDark, _purpleDeep],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(children: [
        Positioned(top: -20, right: -30, child: _circle(170, Colors.white, 0.06)),
        Positioned(bottom: 10, right: 80,  child: _circle(80, const Color(0xFFB06AFF), 0.18)),
        Positioned(top: 50,  left: -15,   child: _circle(55, Colors.white, 0.05)),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Back + Badge row
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.account_balance_rounded,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 5),
                    Text('Executive War Room · TN Govt',
                        style: GoogleFonts.nunito(
                            color: Colors.white70, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text('Approval Hub',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 4),
              Text('Review · Sanction · Resolve',
                  style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              // Flag chips
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (isEscalated) _headerBadge('⚡ Escalated', _red),
                if (isCourtCase) _headerBadge('⚖ Court Case', _red),
                if (isCpgrams)   _headerBadge('📋 CPGRAMS',   const Color(0xFF3B82F6)),
                _headerBadge(
                  'ID: ${c.complaintId.length > 12 ? '${c.complaintId.substring(0, 12)}…' : c.complaintId}',
                  Colors.white70,
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _circle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: color.withOpacity(opacity)),
  );

  Widget _headerBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label,
        style: GoogleFonts.spaceGrotesk(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  // ── Banners ───────────────────────────────────────────────────────────────

  Widget _readOnlyBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _red.withOpacity(0.35)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _red.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.lock_rounded, color: _red, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Text(
        'Ownership changed from EE. This screen is now read-only.',
        style: GoogleFonts.nunito(fontSize: 12,
            fontWeight: FontWeight.w700, color: _red),
      )),
    ]),
  );

  Widget _escalationBanner() => AnimatedBuilder(
    animation: _pulse,
    builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _amber.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: _amber, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Executive Escalation Active',
              style: GoogleFonts.spaceGrotesk(fontSize: 13,
                  fontWeight: FontWeight.w800, color: const Color(0xFF92400E))),
          Text('SLA exceeded · Level 3 final action required.',
              style: GoogleFonts.nunito(fontSize: 11,
                  color: const Color(0xFF92400E), fontWeight: FontWeight.w500)),
        ])),
      ]),
    ),
  );

  // ── Complaint Detail Card ─────────────────────────────────────────────────

  Widget _complaintDetailCard(ComplaintModel c, String liveStatus) {
    final statusColor = _statusColor(liveStatus);
    final priorityColor = _priorityColor(c.priority);

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: priorityColor.withOpacity(0.3)),
          ),
          child: Icon(Icons.gavel_rounded, color: priorityColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(fontSize: 15,
                  fontWeight: FontWeight.w700, color: _ink, height: 1.3)),
          const SizedBox(height: 3),
          Text(DateFormat('dd MMM yyyy').format(c.createdAt ?? DateTime.now()),
              style: GoogleFonts.nunito(fontSize: 11,
                  color: _slate, fontWeight: FontWeight.w600)),
        ])),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _infoBadge(c.category,                   const Color(0xFF6366F1), const Color(0xFFEEF2FF)),
        _infoBadge(c.priority,                   priorityColor,           priorityColor.withOpacity(0.1)),
        _infoBadge(_prettyStatus(liveStatus),    statusColor,             statusColor.withOpacity(0.1)),
        _infoBadge('Escalation Lvl ${c.escalationLevel ?? 3}',
            _purple, _purpleLight),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _purpleBorder),
        ),
        child: Text(c.description,
            style: GoogleFonts.nunito(fontSize: 13,
                color: const Color(0xFF334155), height: 1.55)),
      ),

      // Location row (lat/lng)
      Builder(builder: (_) {
        final lat = c.additionalData?['latitude']  ?? c.additionalData?['lat'];
        final lng = c.additionalData?['longitude'] ?? c.additionalData?['lng'];
        if (lat == null || lng == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, color: _muted, size: 14),
            const SizedBox(width: 5),
            Expanded(child: Text(
              'Lat: $lat,  Lng: $lng',
              style: GoogleFonts.nunito(fontSize: 12,
                  color: _muted, fontWeight: FontWeight.w500),
            )),
          ]),
        );
      }),
    ]));
  }

  Widget _infoBadge(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  // ── Budget + GO Number Card ───────────────────────────────────────────────

  Widget _budgetGoCard(bool canEdit) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Budget Sanction & GO Reference',
          Icons.account_balance_wallet_rounded, _purple),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _inputField(
          controller: _budgetCtrl,
          label: 'Amount (₹ INR)',
          hint: '0.00',
          icon: Icons.currency_rupee_rounded,
          enabled: canEdit,
          keyboardType: TextInputType.number,
        )),
        const SizedBox(width: 12),
        Expanded(child: _inputField(
          controller: _goNumberCtrl,
          label: 'GO Number',
          hint: 'GO Ms. No.',
          icon: Icons.badge_rounded,
          enabled: canEdit,
        )),
      ]),
    ]),
  );

  // ── Remark Card ───────────────────────────────────────────────────────────

  Widget _remarkCard(bool canEdit) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Official Remark / Note',
          Icons.edit_note_rounded, _purple),
      const SizedBox(height: 16),
      _inputField(
        controller: _remarkCtrl,
        label: 'EE Official Remark',
        hint: 'Enter formal remark or instructions...',
        icon: Icons.notes_rounded,
        enabled: canEdit,
        maxLines: 3,
      ),
    ]),
  );

  // ── Sanction Actions Card ─────────────────────────────────────────────────

  Widget _sanctionCard(bool canEdit) => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Executive Sanctions',
          Icons.verified_user_rounded, _purple),
      const SizedBox(height: 6),
      Text('Approving will log the GO number, budget, and remark.',
          style: GoogleFonts.nunito(
              fontSize: 11, color: _slate, fontWeight: FontWeight.w500)),
      const SizedBox(height: 16),
      _actionButton(
        label: 'Sanction Emergency Repair',
        icon: Icons.flash_on_rounded,
        gradient: [_purple, _purpleDark],
        enabled: canEdit,
        onTap: () => _approveAction('Sanction Emergency Repair'),
      ),
      const SizedBox(height: 10),
      _actionButton(
        label: 'Deploy Special Response Team',
        icon: Icons.groups_rounded,
        gradient: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
        enabled: canEdit,
        onTap: () => _approveAction('Deploy Special Team'),
      ),
      const SizedBox(height: 10),
      _actionButton(
        label: 'Approve Equipment Replacement',
        icon: Icons.settings_input_component_rounded,
        gradient: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
        enabled: canEdit,
        onTap: () => _approveAction('Approve Equipment Replacement'),
      ),
    ]),
  );

  // ── Reject Panel ──────────────────────────────────────────────────────────

  Widget _rejectPanel(bool canEdit) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _red.withOpacity(0.35), width: 1.5),
      boxShadow: [BoxShadow(
          color: _red.withOpacity(0.06), blurRadius: 16,
          offset: const Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _red.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.block_rounded, color: _red, size: 16)),
        const SizedBox(width: 10),
        Text('Formal Rejection',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w700, color: _red)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _showRejectPanel = false),
          child: const Icon(Icons.close_rounded, color: _muted, size: 18),
        ),
      ]),
      const SizedBox(height: 4),
      Text('A formal reason is mandatory and will be logged in the audit trail.',
          style: GoogleFonts.nunito(
              fontSize: 11, color: _red, fontWeight: FontWeight.w500)),
      const SizedBox(height: 14),
      _inputField(
        controller: _rejectCtrl,
        label: 'Rejection Reason (min. 10 chars)',
        hint: 'State formal grounds for rejection...',
        icon: Icons.report_outlined,
        enabled: canEdit,
        maxLines: 4,
        borderColor: _red.withOpacity(0.4),
      ),
      const SizedBox(height: 14),
      _actionButton(
        label: 'Confirm Rejection',
        icon: Icons.block_rounded,
        gradient: [_red, const Color(0xFFB91C1C)],
        enabled: canEdit,
        onTap: _rejectComplaint,
      ),
    ]),
  );

  // ── Bottom Actions Row ────────────────────────────────────────────────────

  Widget _bottomActions(bool canEdit) => Column(children: [
    Row(children: [
      Expanded(child: _outlineButton(
        label: 'Mark Resolved',
        icon: Icons.verified_rounded,
        color: _green,
        enabled: canEdit,
        onTap: _markResolved,
      )),
      const SizedBox(width: 12),
      Expanded(child: _outlineButton(
        label: 'Reopen to AE',
        icon: Icons.restart_alt_rounded,
        color: _amber,
        enabled: canEdit,
        onTap: _reopenToAe,
      )),
    ]),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: _outlineButton(
        label: _showRejectPanel ? 'Hide Rejection Panel' : 'Reject Complaint',
        icon: Icons.block_rounded,
        color: _red,
        enabled: canEdit,
        onTap: () => setState(() => _showRejectPanel = !_showRejectPanel),
      ),
    ),
  ]);

  // ── Shared Widget Primitives ──────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
          color: _purpleDeep.withOpacity(0.07),
          blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: child,
  );

  Widget _sectionTitle(String title, IconData icon, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 16),
    ),
    const SizedBox(width: 10),
    Text(title,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
  ]);

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Color? borderColor,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.nunito(fontSize: 12, color: _slate),
        labelStyle: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
        prefixIcon: Icon(icon, color: _purple, size: 18),
        filled: true,
        fillColor: enabled ? _bg : const Color(0xFFF1EDF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor ?? _purpleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor ?? _purpleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purple, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE9D8FD)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? (_saving ? null : onTap) : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(
                color: gradient[0].withOpacity(0.35),
                blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_saving)
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? (_saving ? null : onTap) : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.45), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}