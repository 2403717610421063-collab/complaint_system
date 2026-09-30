import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/admin_complaint_model.dart';

/// AEE Intervention Screen — Redesigned
/// Layout:
///   [Header]
///   [Complaint card + Action buttons (Mark Resolved / Update Workflow)]
///   [Tab content — scrollable]
///   [Bottom navigation: Workflow · Inspection · Work Order · Compliance]

class InterventionScreen extends StatefulWidget {
  final ComplaintModel complaint;
  const InterventionScreen({super.key, required this.complaint});

  @override
  State<InterventionScreen> createState() => _InterventionScreenState();
}

class _InterventionScreenState extends State<InterventionScreen>
    with TickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleDeep  = Color(0xFF2D0E5E);
  static const _purpleTint  = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _surface    = Color(0xFFF4F3F9);
  static const _green      = Color(0xFF16A34A);
  static const _red        = Color(0xFFDC2626);
  static const _amber      = Color(0xFFD97706);

  // ── Controllers ────────────────────────────────────────────────────────────
  final _resourceCtrl   = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final _inspectionCtrl = TextEditingController();
  final _workOrderCtrl  = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _costCtrl       = TextEditingController();
  final _escalationCtrl = TextEditingController();

  late final PageController _pageCtrl;
  late final AnimationController _fadeCtrl;

  // Nullable to avoid LateInitializationError on first StreamBuilder build
  Animation<double>? _fadeAnimNullable;
  Animation<double> get _fadeAnim => _fadeAnimNullable!;

  int _currentTab = 0;

  // ── State ──────────────────────────────────────────────────────────────────
  static const List<String> _aeeStatuses = [
    'under_review',
    'inspection_scheduled',
    'work_order_issued',
    'in_progress',
    'resolved',
  ];

  String    _selectedStatus  = 'under_review';
  DateTime? _deadline;
  DateTime? _inspectionDate;
  bool _saving          = false;
  bool _generatingPdf   = false;
  bool _inspectionDone  = false;
  bool _workOrderIssued = false;
  bool _citizenNotified = false;
  bool _isCpgrams       = false;
  bool _isCmCell        = false;
  bool _isCourtCase     = false;
  String _budgetSource  = 'State Fund';

  static const List<String> _budgetSources = [
    'State Fund', 'Local Body Fund', 'Central Scheme',
    'TNEB Internal', 'Smart City Mission', 'Other',
  ];

  static const Map<String, int> _slaHours = {
    'high': 4, 'medium': 15, 'low': 24,
  };

  // ── Tab metadata ───────────────────────────────────────────────────────────
  static const List<_TabMeta> _tabs = [
    _TabMeta(Icons.account_tree_rounded,         'Workflow'),
    _TabMeta(Icons.fact_check_rounded,           'Inspection'),
    _TabMeta(Icons.assignment_turned_in_rounded, 'Work Order'),
    _TabMeta(Icons.shield_rounded,               'Compliance'),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnimNullable =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    final c = widget.complaint;
    final init = _normalizeStatus(c.status);
    _selectedStatus = _aeeStatuses.contains(init) ? init : 'under_review';
    _deadline = c.aeeDeadline ?? c.slaDeadline ?? DateTime.now().add(const Duration(days: 7));
    _resourceCtrl.text = c.assignedResources == 'Unassigned' ? '' : c.assignedResources;
    _notesCtrl.text = c.aeeNotes == 'Not Added' ? '' : c.aeeNotes;
    _inspectionDone = c.inspectionCompleted;
    _inspectionDate = c.inspectionDate;
    _inspectionCtrl.text = c.inspectionReport == 'Not Entered' ? '' : c.inspectionReport;
    _workOrderIssued = c.workOrderIssued;
    _workOrderCtrl.text = c.workOrderNumber == 'N/A' ? '' : c.workOrderNumber;
    _contractorCtrl.text = c.contractorName == 'N/A' ? '' : c.contractorName;
    _costCtrl.text = c.estimatedCost == '0' ? '' : c.estimatedCost;
    _budgetSource = c.budgetSource;
    _isCpgrams = c.isCpgrams;
    _isCmCell = c.isCmCell;
    _isCourtCase = c.isCourtCase;
    _citizenNotified = c.citizenNotified;
    _escalationCtrl.text = ''; // Reset on init
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    _resourceCtrl.dispose();
    _notesCtrl.dispose();
    _inspectionCtrl.dispose();
    _workOrderCtrl.dispose();
    _contractorCtrl.dispose();
    _costCtrl.dispose();
    _escalationCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _normalizeStatus(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), '_');

  String _statusLabel(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _fmtDate(DateTime? v) =>
      v == null ? 'Not set' : DateFormat('dd MMM yyyy').format(v);

  Color _priorityColor(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':   return _red;
      case 'medium': return _amber;
      default:       return _green;
    }
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime)  return v;
    if (v is String)    return DateTime.tryParse(v);
    return null;
  }

  String _normalizeRole(String r) {
    final n = r.trim().toLowerCase();
    if (n == 'aee') return 'aee';
    if (n == 'ee')  return 'ee';
    return 'ae';
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? _red : _purpleDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _switchTab(int i) {
    setState(() => _currentTab = i);
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ── Date pickers ───────────────────────────────────────────────────────────
  Future<void> _pickDeadline() async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purpleDark)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _deadline = p);
  }

  Future<void> _pickInspectionDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purpleDark)),
        child: child!,
      ),
    );
    if (p != null) setState(() => _inspectionDate = p);
  }

  // ── Save / Escalate ────────────────────────────────────────────────────────
  Future<void> _applyIntervention({String? statusOverride}) async {
    if (_saving) return;
    final effectiveStatus = statusOverride ?? _selectedStatus;
    if (effectiveStatus == 'resolved' && !_inspectionDone) {
      _snack('Field inspection is mandatory before resolving.', isError: true);
      _switchTab(1);
      return;
    }
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
            (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae')
                .toString());
        if (role != 'aee') throw StateError('Ownership changed — read only.');

        final priority =
        (data['priority'] ?? widget.complaint.priority).toString();
        final hours = _slaHours[priority.toLowerCase()] ?? 24;
        final deadline = _deadline ??
            _toDateTime(data['slaDeadline']) ??
            DateTime.now().add(Duration(hours: hours));

        tx.update(ref, {
          'assignedRole': 'aee',
          'currentOwnerRole': 'AEE',
          'status': effectiveStatus,
          'assignedAt': data['assignedAt'] ?? FieldValue.serverTimestamp(),
          'slaDeadline': Timestamp.fromDate(_deadline!),
          'aeeDeadline': Timestamp.fromDate(_deadline!),
          'assignedResources': _resourceCtrl.text.trim().isEmpty
              ? 'Unassigned'
              : _resourceCtrl.text.trim(),
          'aeeNotes': _notesCtrl.text.trim().isEmpty
              ? 'Not Added'
              : _notesCtrl.text.trim(),
          'escalationLevel': 2,
          'lastUpdated': FieldValue.serverTimestamp(),
          'inspectionCompleted': _inspectionDone,
          'inspectionDate': _inspectionDate != null
              ? Timestamp.fromDate(_inspectionDate!)
              : null,
          'inspectionReport': _inspectionCtrl.text.trim().isEmpty 
              ? 'Not Entered' 
              : _inspectionCtrl.text.trim(),
          'workOrderIssued': _workOrderIssued,
          'workOrderNumber': _workOrderCtrl.text.trim().isEmpty 
              ? 'N/A' 
              : _workOrderCtrl.text.trim(),
          'contractorName': _contractorCtrl.text.trim().isEmpty 
              ? 'N/A' 
              : _contractorCtrl.text.trim(),
          'estimatedCost': _costCtrl.text.trim().isEmpty 
              ? '0' 
              : _costCtrl.text.trim(),
          'isCpgrams': _isCpgrams,
          'isCmCell': _isCmCell,
          'isCourtCase': _isCourtCase,
          'budgetSource': _budgetSource,
          'citizenNotified': _citizenNotified,
          if (effectiveStatus == 'resolved')
            'resolutionNote': _notesCtrl.text.trim().isEmpty 
                ? 'Resolved by AEE' 
                : _notesCtrl.text.trim(),
        });
      });

      if (_citizenNotified) _snack('Citizen notification queued.');
      if (!mounted) return;
      _snack('Workflow updated successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _escalateToEE() async {
    if (_escalationCtrl.text.trim().isEmpty) {
      _snack('Please provide a reason for EE escalation.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId)
          .update({
        'assignedRole': 'ee',
        'currentOwnerRole': 'EE',
        'status': 'escalated',
        'escalationLevel': 3,
        'eeEscalationReason': _escalationCtrl.text.trim(),
        'escalatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _snack('Escalated to Executive Engineer.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Escalation failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── PDF ────────────────────────────────────────────────────────────────────
  Future<void> _generatePdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final c   = widget.complaint;
      final pdf = pw.Document();
      const purple = PdfColor.fromInt(0xFF7B1FA2);
      const grey   = PdfColor.fromInt(0xFF6B6B8D);
      const dark   = PdfColor.fromInt(0xFF1A1A2E);
      const tint   = PdfColor.fromInt(0xFFF3E8FF);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('AEE INTERVENTION REPORT',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.white)),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          _pdfSec('Complaint Details', purple),
          _pdfTable([
            ['Complaint ID', c.complaintId],
            ['Title',        c.title],
            ['Priority',     c.priority],
            ['Status',       _statusLabel(_selectedStatus)],
            ['SLA Deadline', _fmtDate(_deadline)],
          ], dark, grey, tint),
          pw.SizedBox(height: 14),
          _pdfSec('Inspection', purple),
          _pdfTable([
            ['Completed', _inspectionDone ? 'Yes' : 'No'],
            ['Date',      _fmtDate(_inspectionDate)],
            ['Findings',  _inspectionCtrl.text.trim().isEmpty
                ? 'Not entered' : _inspectionCtrl.text.trim()],
          ], dark, grey, tint),
          pw.SizedBox(height: 14),
          _pdfSec('Work Order', purple),
          _pdfTable([
            ['Issued',     _workOrderIssued ? 'Yes' : 'No'],
            ['Order No.',  _workOrderCtrl.text.trim().isEmpty ? 'N/A' : _workOrderCtrl.text.trim()],
            ['Contractor', _contractorCtrl.text.trim().isEmpty ? 'N/A' : _contractorCtrl.text.trim()],
            ['Cost (₹)',   _costCtrl.text.trim().isEmpty ? 'N/A' : '₹ ${_costCtrl.text.trim()}'],
            ['Budget',     _budgetSource],
          ], dark, grey, tint),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name:
        'AEE_${c.complaintId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      _snack('PDF generated.');
    } catch (e) {
      _snack('PDF failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.Widget _pdfSec(String t, PdfColor c) => pw.Column(children: [
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
          color: c,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    ),
    pw.SizedBox(height: 6),
  ]);

  pw.TableRow _pdfRow(String l, String v, PdfColor dark, PdfColor grey,
      PdfColor bg) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(l,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: dark))),
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(v,
                  style: pw.TextStyle(fontSize: 9, color: grey))),
        ],
      );

  pw.Widget _pdfTable(List<List<String>> rows, PdfColor dark,
      PdfColor grey, PdfColor tint) {
    return pw.Table(
      border: pw.TableBorder.all(
          color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
      children: rows
          .asMap()
          .entries
          .map((e) => _pdfRow(e.value[0], e.value[1], dark, grey,
          e.key.isEven ? tint : PdfColors.white))
          .toList(),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_fadeAnimNullable == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .doc(widget.complaint.complaintId)
            .snapshots(),
        builder: (ctx, snap) {
          final data = snap.data?.data() ?? {};
          final liveRole = _normalizeRole(
              (data['assignedRole'] ?? widget.complaint.assignedRole)
                  .toString());
          final liveStatus =
          (data['status'] ?? widget.complaint.status).toString();
          final canEdit = !_saving && liveRole == 'aee';

          return FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              // ── HEADER ────────────────────────────────────────────────
              // KEY FIX throughout: every callback is an anonymous lambda,
              // never a method tear-off (e.g. _generatePdf instead of
              // () { _generatePdf(); }). Torn-off methods lose their JS
              // type signature in DDC, crashing on dispose/removeListener.
              _Header(
                canEdit: canEdit,
                generatingPdf: _generatingPdf,
                onBack: () { Navigator.pop(context); },
                onPdf: () { _generatePdf(); },
              ),

              // ── COMPLAINT CARD + ACTIONS ──────────────────────────────
              _ComplaintAndActions(
                complaint: widget.complaint,
                liveStatus: liveStatus,
                isCpgrams: _isCpgrams,
                isCmCell: _isCmCell,
                isCourtCase: _isCourtCase,
                canEdit: canEdit,
                saving: _saving,
                statusLabel: (s) => _statusLabel(s),
                priorityColor: (s) => _priorityColor(s),
                onResolve: canEdit
                    ? () { _applyIntervention(statusOverride: 'resolved'); }
                    : null,
                onUpdate: canEdit
                    ? () { _applyIntervention(); }
                    : null,
              ),

              // ── OWNERSHIP WARNING ──────────────────────────────────────
              if (liveRole != 'aee') _OwnershipBanner(),

              const SizedBox(height: 8),

              // ── TAB CONTENT (PageView) ─────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentTab = i),
                  children: [
                    _WorkflowTab(
                      canEdit: canEdit,
                      statuses: _aeeStatuses,
                      selectedStatus: _selectedStatus,
                      deadline: _deadline,
                      citizenNotified: _citizenNotified,
                      resourceCtrl: _resourceCtrl,
                      notesCtrl: _notesCtrl,
                      statusLabel: (s) => _statusLabel(s),
                      onStatusChanged: (v) =>
                          setState(() => _selectedStatus = v),
                      onPickDeadline: () { _pickDeadline(); },
                      onToggleNotify: (v) =>
                          setState(() => _citizenNotified = v),
                      fmtDate: (d) => _fmtDate(d),
                    ),
                    _InspectionTab(
                      canEdit: canEdit,
                      inspectionDone: _inspectionDone,
                      inspectionDate: _inspectionDate,
                      inspectionCtrl: _inspectionCtrl,
                      onToggle: (v) =>
                          setState(() => _inspectionDone = v),
                      onPickDate: () { _pickInspectionDate(); },
                      fmtDate: (d) => _fmtDate(d),
                    ),
                    _WorkOrderTab(
                      canEdit: canEdit,
                      issued: _workOrderIssued,
                      workOrderCtrl: _workOrderCtrl,
                      contractorCtrl: _contractorCtrl,
                      costCtrl: _costCtrl,
                      budgetSource: _budgetSource,
                      budgetSources: _budgetSources,
                      onToggle: (v) =>
                          setState(() => _workOrderIssued = v),
                      onBudgetChanged: (v) =>
                          setState(() => _budgetSource = v),
                    ),
                    _ComplianceTab(
                      canEdit: canEdit,
                      isCpgrams: _isCpgrams,
                      isCmCell: _isCmCell,
                      isCourtCase: _isCourtCase,
                      escalationCtrl: _escalationCtrl,
                      onCpgrams: (v) => setState(() => _isCpgrams = v),
                      onCmCell: (v) => setState(() => _isCmCell = v),
                      onCourtCase: (v) =>
                          setState(() => _isCourtCase = v),
                      onEscalate:
                      canEdit ? () { _escalateToEE(); } : null,
                    ),
                  ],
                ),
              ),

              // ── BOTTOM NAV ─────────────────────────────────────────────
              _BottomNav(
                current: _currentTab,
                tabs: _tabs,
                onTap: (i) { _switchTab(i); },
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool canEdit;
  final bool generatingPdf;
  final VoidCallback onBack;
  final VoidCallback onPdf;

  const _Header({
    required this.canEdit,
    required this.generatingPdf,
    required this.onBack,
    required this.onPdf,
  });

  static const _purple     = Color(0xFF7B2FBE);
  static const _purpleDark = Color(0xFF4A1680);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purpleDark, _purple, Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Row(children: [
            _HeaderBtn(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AEE Intervention',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        )),
                    Text('Supervisory workflow management',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 11,
                        )),
                  ]),
            ),
            if (!canEdit)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Text('READ-ONLY',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
              ),
            const SizedBox(width: 8),
            _HeaderBtn(
              onTap: onPdf,
              child: generatingPdf
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation(Colors.white)))
                  : const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _HeaderBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPLAINT CARD + ACTION BUTTONS
// ═══════════════════════════════════════════════════════════════════════════════
class _ComplaintAndActions extends StatelessWidget {
  final ComplaintModel complaint;
  final String liveStatus;
  final bool isCpgrams, isCmCell, isCourtCase;
  final bool canEdit, saving;
  final String Function(String) statusLabel;
  final Color Function(String) priorityColor;
  final VoidCallback? onResolve;
  final VoidCallback? onUpdate;

  const _ComplaintAndActions({
    required this.complaint,
    required this.liveStatus,
    required this.isCpgrams,
    required this.isCmCell,
    required this.isCourtCase,
    required this.canEdit,
    required this.saving,
    required this.statusLabel,
    required this.priorityColor,
    required this.onResolve,
    required this.onUpdate,
  });

  static const _purple     = Color(0xFF7B2FBE);
  static const _purpleTint = Color(0xFFF3E8FF);
  static const _slate      = Color(0xFF1A1A2E);
  static const _muted      = Color(0xFF6B6B8D);
  static const _green      = Color(0xFF16A34A);
  static const _red        = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final c        = complaint;
    final pColor   = priorityColor(c.priority);
    final hasFlags = isCpgrams || isCmCell || isCourtCase;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2FBE).withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasFlags) ...[
                        Wrap(spacing: 6, children: [
                          if (isCpgrams)
                            _Flag('CPGRAMS', const Color(0xFF2563EB)),
                          if (isCmCell)
                            _Flag('CM Cell', const Color(0xFFD97706)),
                          if (isCourtCase) _Flag('Court Case', _red),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      Text(c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _slate,
                          )),
                      const SizedBox(height: 6),
                      Row(children: [
                        _Chip(c.category, _purpleTint, _purple),
                        const SizedBox(width: 6),
                        _Chip(c.priority,
                            pColor.withValues(alpha: 0.1), pColor),
                        const SizedBox(width: 6),
                        _Chip(statusLabel(liveStatus),
                            const Color(0xFFE0F2FE),
                            const Color(0xFF0284C7)),
                      ]),
                      const SizedBox(height: 8),
                      Text(c.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _muted,
                            height: 1.5,
                          )),
                    ]),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'Mark Resolved',
                      icon: Icons.verified_rounded,
                      color: _green,
                      bg: const Color(0xFFF0FDF4),
                      borderColor: const Color(0xFFBBF7D0),
                      enabled: canEdit,
                      onTap: onResolve,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _GradientBtn(
                      label: saving ? null : 'Update Workflow',
                      icon: saving ? null : Icons.save_rounded,
                      enabled: canEdit,
                      saving: saving,
                      onTap: onUpdate,
                    ),
                  ),
                ]),
              ),
            ]),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  final String label;
  final Color color;
  const _Flag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flag_rounded, size: 10, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg, color;
  const _Chip(this.label, this.bg, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg, borderColor;
  final bool enabled;
  final VoidCallback? onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.borderColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? bg : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? borderColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color:
                  enabled ? color : const Color(0xFF94A3B8),
                  size: 15),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? color
                        : const Color(0xFF94A3B8),
                  )),
            ]),
      ),
    );
  }
}

class _GradientBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool enabled, saving;
  final VoidCallback? onTap;
  const _GradientBtn({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
            colors: [Color(0xFF7B2FBE), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: enabled ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
            BoxShadow(
                color: const Color(0xFF7B2FBE)
                    .withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]
              : null,
        ),
        child: Center(
          child: saving
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                  AlwaysStoppedAnimation(Colors.white)))
              : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon!,
                    color: enabled
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                    size: 15),
                const SizedBox(width: 6),
                Text(label!,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    )),
              ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OWNERSHIP BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _OwnershipBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_outline_rounded,
            color: Color(0xFFDC2626), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ownership transferred — screen is now read-only.',
            style: GoogleFonts.dmSans(
              color: const Color(0xFFDC2626),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════════
class _TabMeta {
  final IconData icon;
  final String label;
  const _TabMeta(this.icon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int current;
  final List<_TabMeta> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.current,
    required this.tabs,
    required this.onTap,
  });

  static const _purple     = Color(0xFF7B2FBE);
  static const _purpleTint = Color(0xFFF3E8FF);
  static const _muted      = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = i == current;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? _purpleTint
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      AnimatedScale(
                        scale: selected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(tab.icon,
                            size: 22,
                            color: selected ? _purple : _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(tab.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected ? _purple : _muted,
                          )),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED SECTION CARD & INPUT DECO
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  static const _purple     = Color(0xFF7B2FBE);
  static const _purpleTint = Color(0xFFF3E8FF);
  static const _slate      = Color(0xFF1A1A2E);
  static const _muted      = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2FBE).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _purpleTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _purple, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _slate,
                          )),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: _muted,
                            )),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ]),
    );
  }
}

InputDecoration _inputDeco(String hint, {required IconData icon}) {
  const purple       = Color(0xFF4A1680);
  const purpleBorder = Color(0xFFE9D8FD);

  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.dmSans(
      fontSize: 12,
      color: const Color(0xFFB0A8C8),
    ),
    prefixIcon: Icon(icon, color: Colors.indigo, size: 17),
    filled: true,
    fillColor: const Color(0xFFF8F9FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.indigo, width: 2),
    ),

    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: Colors.indigo.withValues(alpha: 0.5)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — WORKFLOW
// ═══════════════════════════════════════════════════════════════════════════════
class _WorkflowTab extends StatelessWidget {
  final bool canEdit;
  final List<String> statuses;
  final String selectedStatus;
  final DateTime? deadline;
  final bool citizenNotified;
  final TextEditingController resourceCtrl, notesCtrl;
  final String Function(String) statusLabel;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onPickDeadline;
  final ValueChanged<bool> onToggleNotify;
  final String Function(DateTime?) fmtDate;

  const _WorkflowTab({
    required this.canEdit,
    required this.statuses,
    required this.selectedStatus,
    required this.deadline,
    required this.citizenNotified,
    required this.resourceCtrl,
    required this.notesCtrl,
    required this.statusLabel,
    required this.onStatusChanged,
    required this.onPickDeadline,
    required this.onToggleNotify,
    required this.fmtDate,
  });

  static const _purple       = Color(0xFF7B2FBE);
  static const _purpleBorder = Color(0xFFE9D8FD);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        _SectionCard(
          icon: Icons.swap_horiz_rounded,
          title: 'Status Workflow',
          child: DropdownButtonFormField<String>(
            value: selectedStatus,
            onChanged: canEdit
                ? (v) {
              if (v != null) onStatusChanged(v);
            }
                : null,
            items: statuses
                .map((s) => DropdownMenuItem(
              value: s,
              child: Text(statusLabel(s),
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ))
                .toList(),
            decoration: _inputDeco('Select status',
                icon: Icons.circle_outlined),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.schedule_rounded,
          title: 'SLA Deadline',
          child: GestureDetector(
            onTap: canEdit ? onPickDeadline : null,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(11),
                border: const Border.symmetric(
                  horizontal:
                  BorderSide(color: _purpleBorder, width: 1.5),
                  vertical:
                  BorderSide(color: _purpleBorder, width: 1.5),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    color: _purple, size: 16),
                const SizedBox(width: 10),
                Text(fmtDate(deadline),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: deadline != null
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF94A3B8),
                    )),
                const Spacer(),
                if (canEdit)
                  const Icon(Icons.edit_calendar_rounded,
                      color: _purple, size: 14),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.group_rounded,
          title: 'Field Team Assignment',
          child: TextField(
            controller: resourceCtrl,
            enabled: canEdit,
            minLines: 2,
            maxLines: 3,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600),
            decoration: _inputDeco(
                'Team names, vehicles, ward number',
                icon: Icons.person_pin_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.notes_rounded,
          title: 'Supervisory Notes',
          child: TextField(
            controller: notesCtrl,
            enabled: canEdit,
            minLines: 3,
            maxLines: 5,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600),
            decoration: _inputDeco('Notes, decisions, remarks',
                icon: Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.notifications_active_rounded,
          title: 'Citizen Notification',
          child: Row(children: [
            Expanded(
              child: Text('Send SMS on status change',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  )),
            ),
            Switch(
              value: citizenNotified,
              onChanged: canEdit ? onToggleNotify : null,
              activeColor: _purple,
            ),
          ]),
        ),
      ],
    );
  }
}



// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — INSPECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _InspectionTab extends StatefulWidget {
  final bool canEdit, inspectionDone;
  final DateTime? inspectionDate;
  final TextEditingController inspectionCtrl;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickDate;
  final String Function(DateTime?) fmtDate;

  const _InspectionTab({
    required this.canEdit,
    required this.inspectionDone,
    required this.inspectionDate,
    required this.inspectionCtrl,
    required this.onToggle,
    required this.onPickDate,
    required this.fmtDate,
  });

  @override
  State<_InspectionTab> createState() => _InspectionTabState();
}

class _InspectionTabState extends State<_InspectionTab> {
  static const _green = Color(0xFF16A34A);
  static const _purple = Color(0xFF7B2FBE);

  File? _image;
  final ImagePicker _picker = ImagePicker();

  // 📸 Pick Image
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // 📂 Bottom Sheet (Camera / Gallery)
  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        // ⚠️ Info Box
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tamil Nadu guidelines require a site inspection before closing complaints. Mandatory for CPGRAMS and CM Cell cases.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF92400E),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ✅ Site Photos Section (UPDATED)
        _SectionCard(
          icon: Icons.photo_camera_rounded,
          title: 'Site Photos',
          subtitle: 'Attach inspection photos',
          child: GestureDetector(
            onTap: widget.canEdit ? _showPickerOptions : null,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFE9D8FD)),
              ),
              child: _image == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _purple,
                        size: 26),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to attach photos',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  _image!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — WORK ORDER
// ═══════════════════════════════════════════════════════════════════════════════
class _WorkOrderTab extends StatelessWidget {
  final bool canEdit, issued;
  final TextEditingController workOrderCtrl, contractorCtrl, costCtrl;
  final String budgetSource;
  final List<String> budgetSources;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onBudgetChanged;

  const _WorkOrderTab({
    required this.canEdit,
    required this.issued,
    required this.workOrderCtrl,
    required this.contractorCtrl,
    required this.costCtrl,
    required this.budgetSource,
    required this.budgetSources,
    required this.onToggle,
    required this.onBudgetChanged,
  });

  static const _purple = Color(0xFF7B2FBE);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        _SectionCard(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Work Order Status',
          child: Row(children: [
            Expanded(
              child: Text('Work order issued to contractor',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Switch(
              value: issued,
              onChanged: canEdit ? onToggle : null,
              activeColor: _purple,
            ),
          ]),
        ),
        if (issued) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.numbers_rounded,
            title: 'Work Order Number',
            child: TextField(
              controller: workOrderCtrl,
              enabled: canEdit,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700),
              decoration: _inputDeco('e.g. WO/TNEB/2024/001',
                  icon: Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.construction_rounded,
            title: 'Contractor / Agency',
            child: TextField(
              controller: contractorCtrl,
              enabled: canEdit,
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600),
              decoration: _inputDeco(
                  'Contractor name, GST registration',
                  icon: Icons.business_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.currency_rupee_rounded,
            title: 'Estimated Cost (₹)',
            child: TextField(
              controller: costCtrl,
              enabled: canEdit,
              keyboardType: TextInputType.number,
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w700),
              decoration: _inputDeco('Amount in rupees',
                  icon: Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.account_balance_rounded,
            title: 'Budget Source',
            child: DropdownButtonFormField<String>(
              value: budgetSource,
              onChanged: canEdit
                  ? (v) {
                if (v != null) onBudgetChanged(v);
              }
                  : null,
              items: budgetSources
                  .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ))
                  .toList(),
              decoration: _inputDeco('Select source',
                  icon: Icons.account_balance_wallet_rounded),
            ),
          ),
        ] else ...[
          const SizedBox(height: 40),
          Center(
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: _purple, size: 32),
              ),
              const SizedBox(height: 12),
              Text('No Work Order Yet',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A2E),
                  )),
              const SizedBox(height: 4),
              Text('Toggle above to issue a work order',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  )),
            ]),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — COMPLIANCE
// ═══════════════════════════════════════════════════════════════════════════════
class _ComplianceTab extends StatelessWidget {
  final bool canEdit, isCpgrams, isCmCell, isCourtCase;
  final TextEditingController escalationCtrl;
  final ValueChanged<bool> onCpgrams, onCmCell, onCourtCase;
  final VoidCallback? onEscalate;

  const _ComplianceTab({
    required this.canEdit,
    required this.isCpgrams,
    required this.isCmCell,
    required this.isCourtCase,
    required this.escalationCtrl,
    required this.onCpgrams,
    required this.onCmCell,
    required this.onCourtCase,
    required this.onEscalate,
  });

  static const _red   = Color(0xFFDC2626);
  static const _amber = Color(0xFFD97706);
  static const _blue  = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        _SectionCard(
          icon: Icons.flag_rounded,
          title: 'Grievance Compliance Tags',
          subtitle: 'Tag for priority handling requirements',
          child: Column(children: [
            _ToggleTile(
              label: 'CPGRAMS',
              sub: 'Central Public Grievance Redress & Monitoring System',
              value: isCpgrams,
              color: _blue,
              onChanged: canEdit ? onCpgrams : null,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _ToggleTile(
              label: 'CM Cell / Makkalai Thedi Maruthuvam',
              sub: "Chief Minister's Public Grievance Cell",
              value: isCmCell,
              color: _amber,
              onChanged: canEdit ? onCmCell : null,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _ToggleTile(
              label: 'Court Case / Legal Notice',
              sub: 'Subject to active court proceedings',
              value: isCourtCase,
              color: _red,
              onChanged: canEdit ? onCourtCase : null,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.arrow_upward_rounded,
          title: 'Escalate to Executive Engineer',
          subtitle: 'Transfer ownership to EE for final authority',
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: TextField(
                controller: escalationCtrl,
                enabled: canEdit,
                minLines: 3,
                maxLines: 4,
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600),
                decoration: _inputDeco(
                    'Reason: cost > ₹1L, court case, infrastructure failure...',
                    icon: Icons.report_problem_outlined),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: canEdit ? onEscalate : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: canEdit
                      ? const LinearGradient(
                    colors: [
                      Color(0xFFDC2626),
                      Color(0xFFB91C1C)
                    ],
                  )
                      : null,
                  color: canEdit ? null : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: canEdit
                      ? [
                    BoxShadow(
                        color: _red.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                      : null,
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          color: canEdit
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                          size: 15),
                      const SizedBox(width: 7),
                      Text('Escalate to EE',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: canEdit
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          )),
                    ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label, sub;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;

  const _ToggleTile({
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A2E))),
                Text(sub,
                    style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8))),
              ]),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: color),
      ]),
    );
  }
}
