import 'package:complaint_system/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'ee_official_theme.dart';
import 'ee_complaints_intent.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/admin_complaint_model.dart';
import '../services/complaint_service.dart';
import '../theme/app_theme.dart' hide StatusBadge;
import '../widgets/complaint_heatmap_section.dart';
import 'approval_hub.dart';
import 'heatmap_dashboard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// New TN Govt EE Features:
//  1. PDF Executive Summary Report (EE letterhead)
//  2. Approval / Rejection with formal reason (GO Number support)
//  3. Budget Sanction tracking
//  4. SLA breach alerts (real-time color coding)
//  5. Contractor payment release stub
//  6. Court case & CPGRAMS priority queue
//  7. Real-time complaint counter with live filter tabs
// ─────────────────────────────────────────────────────────────────────────────

enum _EeSort {
  newest,
  oldest,
  priority,
  slaBreachFirst,
}

enum EeHomeMode { dashboard, complaints }

class EEHome extends StatefulWidget {
  const EEHome({
    super.key,
    required this.mode,
    this.onOpenComplaints,
    this.complaintsIntent,
  });

  final EeHomeMode mode;
  final void Function(EeComplaintsIntent intent)? onOpenComplaints;
  final ValueListenable<EeComplaintsIntent?>? complaintsIntent;

  @override
  State<EEHome> createState() => _EEHomeState();
}

class _EEHomeState extends State<EEHome> with SingleTickerProviderStateMixin {
  bool _escalationChecked = false;
  final ComplaintService _complaintService = ComplaintService();
  late Razorpay _razorpay;
  String? _payingComplaintId;
  bool _generatingPdf = false;

  // Search + sort
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _EeSort _sort = _EeSort.newest;

  EeQuickFilter _quickFilter = EeQuickFilter.none;

  // Filter tabs
  late TabController _tabCtrl;
  final List<String> _filterLabels = [
    'All', 'Escalated', 'Court/CPGRAMS', 'Pending Approval', 'Resolved'
  ];

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple       = Color(0xFF7B2FBE);
  static const _purpleDark   = Color(0xFF4A1680);
  static const _purpleLight  = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _razorpayKey  = 'rzp_test_YOUR_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filterLabels.length, vsync: this);
    _triggerEscalationCheck();
    if (!kIsWeb) {
      _initRazorpay();
    }

    widget.complaintsIntent?.addListener(_onComplaintsIntent);
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    widget.complaintsIntent?.removeListener(_onComplaintsIntent);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    if (!kIsWeb) {
      _razorpay.clear();
    }
    super.dispose();
  }

  void _onComplaintsIntent() {
    final intent = widget.complaintsIntent?.value;
    if (intent == null) return;

    int nextTabIndex = 0;
    _EeSort nextSort = _EeSort.newest;
    switch (intent.filter) {
      case EeQuickFilter.approvalsQueue:
        nextTabIndex = 3;
        break;
      case EeQuickFilter.escalated:
        nextTabIndex = 1;
        break;
      case EeQuickFilter.resolved:
        nextTabIndex = 4;
        break;
      case EeQuickFilter.slaBreached:
        nextTabIndex = 0;
        nextSort = _EeSort.slaBreachFirst;
        break;
      case EeQuickFilter.paymentPending:
        nextTabIndex = 0;
        break;
      case EeQuickFilter.none:
        nextTabIndex = 0;
        break;
    }

    if (!mounted) return;
    setState(() {
      _quickFilter = intent.filter;
      _sort = nextSort;
      _searchQuery = '';
      _searchCtrl.text = '';
      if (_tabCtrl.index != nextTabIndex) {
        _tabCtrl.index = nextTabIndex;
      }
    });
  }

  // ─── Razorpay ────────────────────────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse r) {
    _snack('Payment successful! ID: ${r.paymentId}');
    setState(() => _payingComplaintId = null);
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _snack('Payment failed: ${r.message}', isError: true);
    setState(() => _payingComplaintId = null);
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    _snack('External wallet: ${r.walletName}');
    setState(() => _payingComplaintId = null);
  }

  void _openPaymentGateway(ComplaintModel comp) {
    if (kIsWeb) {
      _snack('Payments are not supported on web preview.', isError: true);
      return;
    }
    setState(() => _payingComplaintId = comp.complaintId);
    try {
      _razorpay.open({
        'key': _razorpayKey,
        'amount': 50000,
        'name': 'Civic Complaint System',
        'description': 'Resolution fee: ${comp.title}',
        'prefill': {'email': 'citizen@example.com', 'contact': '9999999999'},
        'notes': {'complaint_id': comp.complaintId},
        'theme': {'color': '#7B2FBE'},
      });
    } catch (e) {
      _snack('Could not open payment gateway: $e', isError: true);
      setState(() => _payingComplaintId = null);
    }
  }

  // ─── Escalation check ─────────────────────────────────────────────────────────

  Future<void> _triggerEscalationCheck() async {
    if (_escalationChecked) return;
    _escalationChecked = true;
    try { await _complaintService.checkAndProcessEscalations(); } catch (_) {}
  }

  Stream<List<ComplaintModel>> _streamEeComplaints() {
    return _complaintService.streamActiveComplaints().map(
          (list) => list
          .where((c) => c.assignedRole.toLowerCase() == 'ee')
          .toList(growable: false),
    );
  }

  // ─── Filter logic ─────────────────────────────────────────────────────────────
  List<ComplaintModel> _filterComplaints(
      List<ComplaintModel> all, int tabIndex) {

    switch (tabIndex) {

      case 1: // Escalated
        return all
            .where((c) => c.status.toLowerCase().contains('escalat'))
            .toList();

      case 2: // Court / CPGRAMS
        return all.where((c) {
          final data = c.additionalData ?? {};
          return data['isCourtCase'] == true ||
              data['isCpgrams'] == true; // check exact Firestore key!
        }).toList();

      case 3: // Pending approval
        return all.where((c) {
          final status = _normalizeStatus(c.status);
          return status == 'under_review' ||
              status == 'inspection_scheduled' ||
              status == 'work_order_issued';
        }).toList();

      case 4: // Resolved
        return all
            .where((c) => c.status.toLowerCase().contains('resolved'))
            .toList();

      default:
        return all;
    }
  }

  List<ComplaintModel> _applyQuickFilter(List<ComplaintModel> list) {
    switch (_quickFilter) {
      case EeQuickFilter.slaBreached:
        return list.where(_isSlaBreached).toList(growable: false);
      case EeQuickFilter.paymentPending:
        return list
            .where((c) {
          final s = c.status.toLowerCase();
          return s.contains('payment') && !s.contains('paid');
        })
            .toList(growable: false);
      case EeQuickFilter.escalated:
        return list
            .where((c) => c.isEscalated || c.status.toLowerCase().contains('escalat'))
            .toList(growable: false);
      case EeQuickFilter.approvalsQueue:
      case EeQuickFilter.resolved:
      case EeQuickFilter.none:
        return list;
    }
  }

  // ─── SLA breach check ─────────────────────────────────────────────────────────

  bool _isSlaBreached(ComplaintModel c) {
    final deadline = c.slaDeadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline) &&
        !c.status.toLowerCase().contains('resolved');
  }

  Color _slaColor(ComplaintModel c) {
    final deadline = c.slaDeadline;
    if (deadline == null) return Colors.transparent;
    final remaining = deadline.difference(DateTime.now());
    if (_isSlaBreached(c)) return const Color(0xFFEF4444);
    if (remaining.inHours < 4) return const Color(0xFFF97316);
    return Colors.transparent;
  }

  String _slaLabel(ComplaintModel c) {
    final deadline = c.slaDeadline;
    if (deadline == null) return '';
    if (_isSlaBreached(c)) return '⚠ SLA Breached';
    final remaining = deadline.difference(DateTime.now());
    if (remaining.inHours < 1) return '${remaining.inMinutes}m left';
    if (remaining.inHours < 24) return '${remaining.inHours}h left';
    return '${remaining.inDays}d left';
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _normalizeStatus(String s) =>
      s.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  String _formatDate(DateTime? v) {
    if (v == null) return 'Unknown';
    return DateFormat('dd MMM yyyy').format(v);
  }

  String _budgetSummary(ComplaintModel c) {
    final raw = c.estimatedCost.trim();
    if (raw.isEmpty) return '';

    final normalized = raw.replaceAll(',', '');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return '';

    final isWhole = (value - value.truncateToDouble()).abs() < 0.000001;
    final formatted = NumberFormat.decimalPattern('en_IN')
        .format(isWhole ? value.toInt() : value);

    final budget = c.budgetSource.trim();
    final costPart = 'Est. \u20B9$formatted';
    if (budget.isEmpty) return costPart;
    return '$costPart \u2022 $budget';
  }

  String _actionLabel(String status) {
    final n = _normalizeStatus(status);
    if (n == 'resolved') return 'View';
    if (n == 'approved') return 'Resolve';
    return 'Review';
  }

  Color _priorityColor(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':   return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF97316);
      default:       return const Color(0xFF22C55E);
    }
  }

  Color _statusColor(String s) {
    final n = _normalizeStatus(s);
    if (n.contains('resolved') || n.contains('closed')) return const Color(0xFF22C55E);
    if (n.contains('progress'))  return const Color(0xFF3B82F6);
    if (n.contains('assigned'))  return const Color(0xFFF59E0B);
    if (n.contains('escalat'))   return const Color(0xFFEF4444);
    if (n.contains('approved'))  return const Color(0xFF8B5CF6);
    return const Color(0xFF94A3B8);
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

  // ─── PDF Report ───────────────────────────────────────────────────────────────

  Future<void> _generatePdfReport(List<ComplaintModel> complaints) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);

    try {
      final pdf   = pw.Document();
      final now   = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      final total = complaints.length;
      final escalated  = complaints.where((c) => c.status.toLowerCase().contains('escalat')).length;
      final resolved   = complaints.where((c) => c.status.toLowerCase().contains('resolved')).length;
      final breached   = complaints.where(_isSlaBreached).length;
      final courtCases = complaints.where((c) => c.additionalData?['isCourtCase'] == true).length;
      final cpgrams    = complaints.where((c) => c.additionalData?['isCpgrams'] == true).length;

      const purpleC  = PdfColor.fromInt(0xFF7B2FBE);
      const darkC    = PdfColor.fromInt(0xFF1E0A3C);
      const greyC    = PdfColor.fromInt(0xFF64748B);
      const lightBg  = PdfColor.fromInt(0xFFF3E8FF);
      const redC     = PdfColor.fromInt(0xFFEF4444);
      const greenC   = PdfColor.fromInt(0xFF22C55E);
      const amberC   = PdfColor.fromInt(0xFFF97316);
      const divC     = PdfColor.fromInt(0xFFE9D8FD);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (ctx) => pw.Column(children: [
            // TN Govt letterhead style
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: purpleC,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GOVERNMENT OF TAMIL NADU',
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      pw.Text('Civic Complaint Management — EE Executive Report',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.white)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Report Date: $now',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.white)),
                      pw.Text('Classification: OFFICIAL',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ]),
          footer: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: divC))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential — TNEB / Civic Dept. EE Office',
                    style: const pw.TextStyle(fontSize: 7, color: greyC)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7, color: greyC)),
              ],
            ),
          ),
          build: (ctx) => [

            // ── Summary Stats ─────────────────────────────────────────────
            _pdfTitle('1. Executive Summary', purpleC),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatBox('Total Cases', '$total', purpleC, lightBg),
                _pdfStatBox('Escalated', '$escalated', redC, const PdfColor.fromInt(0xFFFEF2F2)),
                _pdfStatBox('SLA Breach', '$breached', amberC, const PdfColor.fromInt(0xFFFFF7ED)),
                _pdfStatBox('Resolved', '$resolved', greenC, const PdfColor.fromInt(0xFFF0FDF4)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                _pdfStatBox('Court Cases', '$courtCases', redC, const PdfColor.fromInt(0xFFFEF2F2)),
                pw.SizedBox(width: 10),
                _pdfStatBox('CPGRAMS', '$cpgrams', const PdfColor.fromInt(0xFF3B82F6),
                    const PdfColor.fromInt(0xFFEFF6FF)),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Complaint Register ────────────────────────────────────────
            _pdfTitle('2. Complaint Register', purpleC),
            pw.Table(
              border: pw.TableBorder.all(color: divC, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: purpleC),
                  children: ['ID', 'Title', 'Category', 'Priority', 'Status', 'Date']
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ))
                      .toList(),
                ),
                // Data rows
                ...complaints.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final isBreached = _isSlaBreached(c);
                  final bg = i.isEven ? lightBg : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isBreached
                          ? const PdfColor.fromInt(0xFFFFF3CD)
                          : bg,
                    ),
                    children: [
                      c.complaintId.length > 10
                          ? '${c.complaintId.substring(0, 10)}…'
                          : c.complaintId,
                      c.title.length > 30
                          ? '${c.title.substring(0, 30)}…'
                          : c.title,
                      c.category,
                      c.priority,
                      c.status.replaceAll('_', ' '),
                      _formatDate(c.createdAt),
                    ].map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      child: pw.Text(cell,
                          style: pw.TextStyle(
                              fontSize: 7.5, color: darkC)),
                    )).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── SLA Breach List ───────────────────────────────────────────
            if (breached > 0) ...[
              _pdfTitle('3. SLA Breach Alert', redC),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFFF3CD),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: amberC, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$breached complaints have exceeded SLA deadline and require immediate EE action.',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF92400E)),
                    ),
                    pw.SizedBox(height: 8),
                    ...complaints
                        .where(_isSlaBreached)
                        .map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Text(
                        '• ${c.complaintId} — ${c.title} (${c.priority} priority)',
                        style: const pw.TextStyle(
                            fontSize: 8, color: darkC),
                      ),
                    )),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ── Court / CPGRAMS ───────────────────────────────────────────
            if (courtCases > 0 || cpgrams > 0) ...[
              _pdfTitle('4. Priority Grievance Cases', redC),
              pw.Table(
                border: pw.TableBorder.all(color: divC, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: redC),
                    children: ['ID', 'Title', 'Type', 'Status']
                        .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ))
                        .toList(),
                  ),
                  ...complaints
                      .where((c) =>
                  c.additionalData?['isCourtCase'] == true ||
                      c.additionalData?['isCpgrams'] == true)
                      .map((c) => pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFFEF2F2)),
                    children: [
                      c.complaintId.length > 10
                          ? '${c.complaintId.substring(0, 10)}…'
                          : c.complaintId,
                      c.title.length > 35
                          ? '${c.title.substring(0, 35)}…'
                          : c.title,
                      c.additionalData?['isCourtCase'] == true
                          ? 'Court Case'
                          : 'CPGRAMS',
                      c.status.replaceAll('_', ' '),
                    ]
                        .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(cell,
                          style: const pw.TextStyle(
                              fontSize: 7.5)),
                    ))
                        .toList(),
                  )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // ── EE Declaration ────────────────────────────────────────────
            _pdfTitle('5. EE Official Declaration', purpleC),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: divC),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'I, the undersigned Executive Engineer, hereby certify that the above report '
                        'is an accurate representation of complaint status under my jurisdiction, '
                        'prepared in accordance with Tamil Nadu Civic Services Management guidelines '
                        'and GO Ms. No. (applicable). Actions have been initiated as per prescribed SLA.',
                    style: const pw.TextStyle(fontSize: 8.5, color: greyC),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfSignatureLine('Executive Engineer Signature', 140),
                      _pdfSignatureLine('Office Seal & Date', 140),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'EE_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
      _snack('EE report generated successfully.');
    } catch (e) {
      _snack('Failed to generate report: $e', isError: true);
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ─── PDF helpers ─────────────────────────────────────────────────────────────

  pw.Widget _pdfTitle(String title, PdfColor color) {
    return pw.Column(children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      ),
      pw.SizedBox(height: 8),
    ]);
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ]),
    );
  }

  pw.Widget _pdfSignatureLine(String label, double width) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: width, height: 1, color: const PdfColor.fromInt(0xFF1E0A3C)),
        pw.SizedBox(height: 4),
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 7.5, color: PdfColor.fromInt(0xFF64748B))),
      ],
    );
  }

  // ─── Logout dialog ────────────────────────────────────────────────────────────

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
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                )),
            const SizedBox(height: 8),
            Text('Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 13,
                    color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: _purpleLight, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('Cancel',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _purple))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    FadeSlideRoute(page: const LoginScreen()), (_) => false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text('Sign Out',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white))),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Payment sheet ────────────────────────────────────────────────────────────

  void _showPaymentSheet(ComplaintModel comp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2))),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _purpleDark]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: _purple.withOpacity(0.35), blurRadius: 16,
                  offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.payment_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          Text('Collect Resolution Fee',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C))),
          const SizedBox(height: 6),
          Text(comp.title, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(fontSize: 13,
                  color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: _purpleLight, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _purpleBorder)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Resolution Fee',
                  style: GoogleFonts.nunito(fontSize: 14,
                      fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              Text('₹500.00',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _purple)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: ['UPI', 'Card', 'Net Banking', 'Wallet'].map((m) =>
                  Container(margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFF8F5FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _purpleBorder)),
                    child: Text(m, style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700, color: _purple)),
                  )).toList()),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () { Navigator.pop(context); _openPaymentGateway(comp); },
            child: Container(width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purpleDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.4),
                    blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 10),
                Text('Pay ₹500 Securely', style: GoogleFonts.spaceGrotesk(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _purpleBorder, width: 1.5)),
              child: Center(child: Text('Cancel', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _purple))),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user_outlined,
                size: 12, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text('Powered by Razorpay · 256-bit SSL',
                style: GoogleFonts.nunito(fontSize: 11,
                    color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: eeOfficialTheme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: const PreferredSize(
              preferredSize: Size.zero,
              child: SizedBox.shrink(),
            ),
            body: StreamBuilder<List<ComplaintModel>>(
              stream: _streamEeComplaints(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final all = snapshot.data ?? const <ComplaintModel>[];
                final breachCount = all.where(_isSlaBreached).length;

                if (widget.mode == EeHomeMode.dashboard) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(all, breachCount)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _buildStatsRow(all),
                        ),
                      ),
                      if (breachCount > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: _buildSlaBreachBanner(breachCount),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: _buildChartsSection(all),
                        ),
                      ),

                      // Heatmap moved to Dashboard
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A1680).withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: const ComplaintHeatmapSection(role: 'ee'),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: _buildActionCenter(all, breachCount),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: _buildTrendAndInsights(all),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                }

                return AnimatedBuilder(
                  animation: Listenable.merge([_tabCtrl, _searchCtrl]),
                  builder: (_, __) {
                    var filtered = _filterComplaints(all, _tabCtrl.index);
                    filtered = _applyQuickFilter(filtered);
                    filtered = _applySearch(filtered);
                    filtered = _applySort(filtered);

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: AppGradients.headerGradient,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(28),
                                bottomRight: Radius.circular(28),
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                                child: Text(
                                  'Complaints',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                            child: _buildSearchAndSort(),
                          ),
                        ),

                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _FixedSliverHeaderDelegate(
                            height: 58,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: _buildStatusTabs(all),
                            ),
                          ),
                        ),

                        if (snapshot.connectionState == ConnectionState.waiting)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          )
                        else if (filtered.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                              child: _buildEmptyCard(),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (ctx, i) {
                                  final comp = filtered[i];
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 280 + i * 55),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, child) => Opacity(
                                      opacity: v,
                                      child: Transform.translate(
                                        offset: Offset(0, (1 - v) * 14),
                                        child: child,
                                      ),
                                    ),
                                    child: _buildComplaintCard(ctx, comp),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCenter(List<ComplaintModel> all, int breachCount) {
    final theme = Theme.of(context);

    final approvals = _filterComplaints(all, 3).length;
    final escalated = _filterComplaints(all, 1).length;
    final resolved = _filterComplaints(all, 4).length;
    final paymentPending = all.where((c) {
      final s = c.status.toLowerCase();
      return s.contains('payment') && !s.contains('paid');
    }).length;

    Widget card({
      required IconData icon,
      required String title,
      required int value,
      required Color color,
      required EeQuickFilter filter,
    }) {
      return InkWell(
        onTap: widget.onOpenComplaints == null
            ? null
            : () => widget.onOpenComplaints!(EeComplaintsIntent(filter)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.subtle,
            border: Border.all(color: AppColors.borderColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.toString(),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    final items = <Widget>[
      card(
        icon: Icons.fact_check_rounded,
        title: 'Pending Approval',
        value: approvals,
        color: const Color(0xFFF59E0B),
        filter: EeQuickFilter.approvalsQueue,
      ),
      card(
        icon: Icons.warning_amber_rounded,
        title: 'SLA Breaches',
        value: breachCount,
        color: const Color(0xFFEF4444),
        filter: EeQuickFilter.slaBreached,
      ),
      card(
        icon: Icons.trending_up_rounded,
        title: 'Escalations',
        value: escalated,
        color: const Color(0xFF8B5CF6),
        filter: EeQuickFilter.escalated,
      ),
      card(
        icon: Icons.task_alt_rounded,
        title: 'Resolved',
        value: resolved,
        color: const Color(0xFF22C55E),
        filter: EeQuickFilter.resolved,
      ),
    ];

    if (paymentPending > 0) {
      items.add(
        card(
          icon: Icons.payments_rounded,
          title: 'Payment Pending',
          value: paymentPending,
          color: const Color(0xFF3B82F6),
          filter: EeQuickFilter.paymentPending,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action Center',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final cardWidth = isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            return Wrap(
              runSpacing: 12,
              spacing: 12,
              children: items
                  .map((w) => SizedBox(width: cardWidth, child: w))
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrendAndInsights(List<ComplaintModel> all) {
    final theme = Theme.of(context);

    Widget sectionCard({required String title, required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.subtle,
          border: Border.all(color: AppColors.borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ]),
      );
    }

    // Trend data (last 7 days): createdAt vs resolved (status contains resolved; lastUpdated as proxy).
    final now = DateTime.now();
    DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
    final start = dayStart(now.subtract(const Duration(days: 6)));

    final days = List<DateTime>.generate(7, (i) => dayStart(start.add(Duration(days: i))));
    final created = List<double>.filled(7, 0);
    final resolved = List<double>.filled(7, 0);

    int idxFor(DateTime d) {
      final diff = dayStart(d).difference(start).inDays;
      return (diff >= 0 && diff < 7) ? diff : -1;
    }

    for (final c in all) {
      final ca = c.createdAt;
      if (ca != null) {
        final i = idxFor(ca);
        if (i != -1) created[i] += 1;
      }

      if (c.status.toLowerCase().contains('resolved')) {
        final i = idxFor(c.lastUpdated);
        if (i != -1) resolved[i] += 1;
      }
    }

    final trendCard = sectionCard(
      title: '7-Day Trend',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: theme.textTheme.labelSmall),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= days.length) return const SizedBox.shrink();
                    final d = days[i];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${d.day}/${d.month}', style: theme.textTheme.labelSmall),
                    );
                  },
                ),
              ),
            ),
            minX: 0,
            maxX: 6,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(7, (i) => FlSpot(i.toDouble(), created[i])),
                isCurved: true,
                barWidth: 3,
                color: theme.colorScheme.primary,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: List.generate(7, (i) => FlSpot(i.toDouble(), resolved[i])),
                isCurved: true,
                barWidth: 3,
                color: const Color(0xFF22C55E),
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );

    Map<String, int> tally(Iterable<String> keys) {
      final m = <String, int>{};
      for (final k in keys) {
        final kk = k.trim().isEmpty ? 'Unknown' : k.trim();
        m[kk] = (m[kk] ?? 0) + 1;
      }
      return m;
    }

    List<MapEntry<String, int>> topN(Map<String, int> m, int n) {
      final entries = m.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value));
      return entries.take(n).toList(growable: false);
    }

    final topCategories = topN(tally(all.map((c) => c.category)), 5);

    Widget rankedList(List<MapEntry<String, int>> items, {required String emptyLabel}) {
      if (items.isEmpty) {
        return Text(
          emptyLabel,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        );
      }
      return Column(
        children: [
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i].key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    items[i].value.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final categoriesCard = sectionCard(
      title: 'Category Hotspots',
      child: rankedList(topCategories, emptyLabel: 'No category data available.'),
    );

    final safetyRisk = all.where((c) => c.isSafetyRisk).length;
    final majorFault = all.where((c) => c.isMajorFault).length;
    final reopened = all.where((c) => c.reopenCount > 0).length;
    final escalated = all.where((c) => c.isEscalated || c.status.toLowerCase().contains('escalat')).length;
    final breached = all.where(_isSlaBreached).length;

    Widget pill({required IconData icon, required String label, required int value, required Color color}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, color: color),
          ),
        ]),
      );
    }

    final riskCard = sectionCard(
      title: 'Risk & Severity',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          pill(icon: Icons.health_and_safety_rounded, label: 'Safety', value: safetyRisk, color: const Color(0xFFEF4444)),
          pill(icon: Icons.bolt_rounded, label: 'Major', value: majorFault, color: const Color(0xFFF97316)),
          pill(icon: Icons.refresh_rounded, label: 'Reopened', value: reopened, color: theme.colorScheme.primary),
          pill(icon: Icons.trending_up_rounded, label: 'Escalated', value: escalated, color: const Color(0xFF8B5CF6)),
          pill(icon: Icons.warning_amber_rounded, label: 'SLA', value: breached, color: const Color(0xFFEF4444)),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (isWide) {
          return Column(
            children: [
              trendCard,
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categoriesCard),
                  const SizedBox(width: 12),
                  Expanded(child: riskCard),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            trendCard,
            const SizedBox(height: 12),
            categoriesCard,
            const SizedBox(height: 12),
            riskCard,
          ],
        );
      },
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
        border: Border.all(color: AppColors.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final searchField = TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search complaints',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );

          final sortField = DropdownButtonFormField<_EeSort>(
            key: ValueKey(_sort),
            initialValue: _sort,
            isExpanded: true,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _sort = v);
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sort_rounded, size: 18),
              prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 40),
            ),
            selectedItemBuilder: (_) => const [
              Text('Newest', overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Oldest', overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('Priority', overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('SLA first', overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
            items: const [
              DropdownMenuItem(
                value: _EeSort.newest,
                child: Text('Newest', overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              DropdownMenuItem(
                value: _EeSort.oldest,
                child: Text('Oldest', overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              DropdownMenuItem(
                value: _EeSort.priority,
                child: Text('Priority', overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              DropdownMenuItem(
                value: _EeSort.slaBreachFirst,
                child: Text('SLA breach', overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                sortField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 240, child: sortField),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartsSection(List<ComplaintModel> all) {
    final theme = Theme.of(context);

    int isPendingApproval(ComplaintModel c) {
      final n = _normalizeStatus(c.status);
      return (n == 'under_review' || n == 'inspection_scheduled' || n == 'work_order_issued')
          ? 1
          : 0;
    }

    int isApproved(ComplaintModel c) => _normalizeStatus(c.status) == 'approved' ? 1 : 0;
    int isResolved(ComplaintModel c) => c.status.toLowerCase().contains('resolved') ? 1 : 0;
    int isEscalated(ComplaintModel c) => c.status.toLowerCase().contains('escalat') ? 1 : 0;

    final total = all.length;
    final high = all.where((c) => c.priority.trim().toLowerCase() == 'high').length;
    final medium = all.where((c) => c.priority.trim().toLowerCase() == 'medium').length;
    final low = all.where((c) => c.priority.trim().toLowerCase() == 'low').length;
    final otherPriority = (total - high - medium - low).clamp(0, total);

    final escalated = all.fold<int>(0, (p, c) => p + isEscalated(c));
    final pending = all.fold<int>(0, (p, c) => p + isPendingApproval(c));
    final approved = all.fold<int>(0, (p, c) => p + isApproved(c));
    final resolved = all.fold<int>(0, (p, c) => p + isResolved(c));

    Widget sectionCard({required String title, required Widget child}) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.subtle,
          border: Border.all(color: AppColors.borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ]),
      );
    }

    Widget legendDot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );

    Widget legendItem(String label, int value, Color c) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        legendDot(c),
        const SizedBox(width: 6),
        Text(
          '$label ($value)',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ]);
    }

    final priorityPie = sectionCard(
      title: 'Priority Distribution',
      child: SizedBox(
        height: 210,
        child: Row(children: [
          Expanded(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 52,
                sectionsSpace: 2,
                sections: [
                  _pieSection('High', high, AppColors.priorityHigh),
                  _pieSection('Medium', medium, AppColors.priorityMedium),
                  _pieSection('Low', low, AppColors.priorityLow),
                  if (otherPriority > 0) _pieSection('Other', otherPriority, AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 190,
            child: Wrap(
              runSpacing: 10,
              spacing: 12,
              children: [
                legendItem('High', high, AppColors.priorityHigh),
                legendItem('Medium', medium, AppColors.priorityMedium),
                legendItem('Low', low, AppColors.priorityLow),
                if (otherPriority > 0) legendItem('Other', otherPriority, AppColors.textSecondary),
              ],
            ),
          ),
        ]),
      ),
    );

    final statusBars = sectionCard(
      title: 'Status Overview',
      child: SizedBox(
        height: 210,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.borderColor,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: true),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    final label = switch (idx) {
                      0 => 'Esc',
                      1 => 'Pend',
                      2 => 'Appr',
                      3 => 'Res',
                      _ => '',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ),
            ),
            maxY: [escalated, pending, approved, resolved, 1].reduce((a, b) => a > b ? a : b).toDouble() + 1,
            barGroups: [
              _barGroup(0, escalated.toDouble(), const Color(0xFFEF4444)),
              _barGroup(1, pending.toDouble(), const Color(0xFFF59E0B)),
              _barGroup(2, approved.toDouble(), theme.colorScheme.primary),
              _barGroup(3, resolved.toDouble(), const Color(0xFF22C55E)),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (isWide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: priorityPie),
            const SizedBox(width: 12),
            Expanded(child: statusBars),
          ]);
        }
        return Column(children: [
          priorityPie,
          const SizedBox(height: 12),
          statusBars,
        ]);
      },
    );
  }

  PieChartSectionData _pieSection(String label, int value, Color color) {
    final showTitle = value > 0;
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      radius: 62,
      title: showTitle ? value.toString() : '',
      titleStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
      ],
    );
  }

  // UPDATED: Modified Search to support the new `assignedWorkerNames` array
  List<ComplaintModel> _applySearch(List<ComplaintModel> input) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return input;

    bool matches(ComplaintModel c) {
      bool matchesWorkerName = false;

      // Check if any of the assigned workers' names contain the search query
      if (c.assignedWorkerNames != null && c.assignedWorkerNames!.isNotEmpty) {
        matchesWorkerName = c.assignedWorkerNames!.any((name) => name.toLowerCase().contains(q));
      }

      return c.complaintId.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q) ||
          c.priority.toLowerCase().contains(q) ||
          c.status.toLowerCase().contains(q) ||
          c.ward.toLowerCase().contains(q) ||
          matchesWorkerName; // Used here instead of the old single string
    }

    return input.where(matches).toList(growable: false);
  }

  List<ComplaintModel> _applySort(List<ComplaintModel> input) {
    final list = input.toList(growable: true);
    int priorityRank(String p) {
      switch (p.trim().toLowerCase()) {
        case 'high':
          return 0;
        case 'medium':
          return 1;
        case 'low':
          return 2;
        default:
          return 3;
      }
    }

    int compareDateDesc(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    int compareDateAsc(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    switch (_sort) {
      case _EeSort.newest:
        list.sort((a, b) => compareDateDesc(a.createdAt, b.createdAt));
        break;
      case _EeSort.oldest:
        list.sort((a, b) => compareDateAsc(a.createdAt, b.createdAt));
        break;
      case _EeSort.priority:
        list.sort((a, b) {
          final pr = priorityRank(a.priority).compareTo(priorityRank(b.priority));
          if (pr != 0) return pr;
          return compareDateDesc(a.createdAt, b.createdAt);
        });
        break;
      case _EeSort.slaBreachFirst:
        list.sort((a, b) {
          final ab = _isSlaBreached(a);
          final bb = _isSlaBreached(b);
          if (ab != bb) return ab ? -1 : 1;
          return compareDateDesc(a.createdAt, b.createdAt);
        });
        break;
    }
    return list;
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(List<ComplaintModel> complaints, int breachCount) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // TN Govt badge
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
                    Text(
                      'Executive Engineer · TN Govt',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(
                  'EE Dashboard',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Approve, resolve & collect payments',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (breachCount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        '$breachCount SLA Breach${breachCount > 1 ? 'es' : ''}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            // Three-dot menu
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout')  _showLogoutDialog();
                if (value == 'heatmap') Navigator.push(context,
                    FadeSlideRoute(page: const HeatmapDashboard()));
                if (value == 'pdf') {
                  // We need the stream data — get from context
                  _snack('Generating PDF...');
                  _complaintService.streamActiveComplaints().first.then((list) {
                    final eeList = list
                        .where((c) => c.assignedRole.toLowerCase() == 'ee')
                        .toList();
                    _generatePdfReport(eeList);
                  });
                }
              },
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 12,
              shadowColor: const Color(0xFF4A1680).withOpacity(0.2),
              itemBuilder: (_) => [
                PopupMenuItem<String>(value: 'pdf',
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            color: Color(0xFF3B82F6), size: 15)),
                    const SizedBox(width: 12),
                    Text('Generate EE Report',
                        style: GoogleFonts.spaceGrotesk(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E0A3C))),
                  ]),
                ),
                PopupMenuItem<String>(value: 'heatmap',
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.map_outlined,
                            color: Color(0xFF3B82F6), size: 15)),
                    const SizedBox(width: 12),
                    Text('Predictive Heatmap',
                        style: GoogleFonts.spaceGrotesk(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E0A3C))),
                  ]),
                ),
                PopupMenuItem<String>(value: 'logout',
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.logout_rounded,
                            color: Color(0xFFEF4444), size: 15)),
                    const SizedBox(width: 12),
                    Text('Sign Out',
                        style: GoogleFonts.spaceGrotesk(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444))),
                  ]),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: _generatingPdf
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── SLA Breach Banner ────────────────────────────────────────────────────────

  Widget _buildSlaBreachBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timer_off_rounded,
              color: Color(0xFFF97316), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count SLA Deadline${count > 1 ? 's' : ''} Breached',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E))),
            Text('Immediate EE action required per TN Govt guidelines.',
                style: GoogleFonts.nunito(fontSize: 11,
                    color: const Color(0xFF92400E), fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<ComplaintModel> complaints) {
    final total     = complaints.length;
    final escalated = complaints.where((c) => c.status.toLowerCase().contains('escalat')).length;
    final approved  = complaints.where((c) => _normalizeStatus(c.status) == 'approved').length;
    final resolved  = complaints.where((c) => c.status.toLowerCase().contains('resolved')).length;

    return Row(children: [
      _statTile('Total',     '$total',     Icons.assignment_rounded,   _purple, _purpleLight),
      const SizedBox(width: 10),
      _statTile('Escalated', '$escalated', Icons.warning_amber_rounded,
          const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      const SizedBox(width: 10),
      _statTile('Approved',  '$approved',  Icons.thumb_up_rounded,
          const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
      const SizedBox(width: 10),
      _statTile('Resolved',  '$resolved',  Icons.verified_rounded,
          const Color(0xFF22C55E), const Color(0xFFF0FDF4)),
    ]);
  }

  Widget _statTile(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF4A1680).withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 14)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: const Color(0xFF1E0A3C), height: 1)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.nunito(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  // ─── Filter Tab Bar ───────────────────────────────────────────────────────────

  Widget _buildStatusTabs(List<ComplaintModel> all) {
    final counts = [
      all.length,
      all.where((c) => c.status.toLowerCase().contains('escalat')).length,
      all.where((c) => c.additionalData?['isCourtCase'] == true ||
          c.additionalData?['isCpgrams'] == true).length,
      all.where((c) {
        final n = _normalizeStatus(c.status);
        return n == 'under_review' || n == 'inspection_scheduled' || n == 'work_order_issued';
      }).length,
      all.where((c) => c.status.toLowerCase().contains('resolved')).length,
    ];

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
        border: Border.all(color: AppColors.borderColor),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        tabs: List.generate(
          _filterLabels.length,
              (i) => Tab(
            height: 42,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_filterLabels[i]),
              if (counts[i] > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tabCtrl.index == i
                        ? Colors.white.withOpacity(0.25)
                        : theme.colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${counts[i]}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _tabCtrl.index == i
                          ? Colors.white
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ─── Complaint Card ───────────────────────────────────────────────────────────

  Widget _buildComplaintCard(BuildContext context, ComplaintModel comp) {
    final normalizedStatus = _normalizeStatus(comp.status);
    final isEscalated = normalizedStatus == 'escalated';
    final isBreached  = _isSlaBreached(comp);
    final isCourtCase = comp.additionalData?['isCourtCase'] == true;
    final isCpgrams   = comp.additionalData?['isCpgrams'] == true;
    final sColor      = _statusColor(comp.status);
    final pColor      = _priorityColor(comp.priority);
    final actionLabel = _actionLabel(comp.status);
    final isPaying    = _payingComplaintId == comp.complaintId;
    final slaLabel    = _slaLabel(comp);
    final slaColor    = _slaColor(comp);
    final budgetLine  = _budgetSummary(comp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isBreached
              ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 1.5)
              : isEscalated
              ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.35), width: 1.5)
              : null,
          boxShadow: [BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 5),
          )],
        ),
        child: Column(children: [
          // Top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: (isEscalated ? const Color(0xFFEF4444) : pColor).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: (isEscalated ? const Color(0xFFEF4444) : pColor).withOpacity(0.3)),
                ),
                child: Icon(
                  isEscalated ? Icons.warning_amber_rounded : Icons.gavel_rounded,
                  color: isEscalated ? const Color(0xFFEF4444) : pColor, size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Flags row
                  if (isEscalated || isBreached || isCourtCase || isCpgrams)
                    Wrap(spacing: 6, runSpacing: 4,
                      children: [
                        if (isEscalated) _flagBadge('⚡ Escalated',
                            const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
                        if (isBreached) _flagBadge('⏰ SLA Breached',
                            const Color(0xFFF97316), const Color(0xFFFFF7ED)),
                        if (isCourtCase) _flagBadge('⚖ Court Case',
                            const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
                        if (isCpgrams) _flagBadge('📋 CPGRAMS',
                            const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                      ],
                    ),
                  if (isEscalated || isBreached || isCourtCase || isCpgrams)
                    const SizedBox(height: 5),
                  Text(comp.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E0A3C), height: 1.3)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(_formatDate(comp.createdAt),
                        style: GoogleFonts.nunito(fontSize: 11,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600)),
                    if (slaLabel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: slaColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: slaColor.withOpacity(0.35)),
                        ),
                        child: Text(slaLabel,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: slaColor)),
                      ),
                    ],
                  ]),
                  if (budgetLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee_rounded,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            budgetLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),
              ),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFFF1EDF9)),

          // Bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              _chip(comp.status.replaceAll('_', ' '), sColor),
              const SizedBox(width: 6),
              _chip(comp.priority, pColor),
              const Spacer(),
              // Payment
              GestureDetector(
                onTap: isPaying ? null : () => _showPaymentSheet(comp),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                  child: isPaying
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF22C55E))))
                      : const Icon(Icons.payment_rounded,
                      color: Color(0xFF22C55E), size: 16),
                ),
              ),
              // Review / Approve
              GestureDetector(
                onTap: () => Navigator.push(context,
                    FadeSlideRoute(page: ApprovalHub(complaint: comp))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEscalated
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : [_purple, _purpleDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: (isEscalated ? const Color(0xFFEF4444) : _purple).withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.gavel_rounded, color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(actionLabel, style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _flagBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ─── Empty Card ───────────────────────────────────────────────────────────────

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF4A1680).withOpacity(0.06),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: _purpleLight, shape: BoxShape.circle),
            child: const Icon(Icons.inbox_rounded, color: _purple, size: 36)),
        const SizedBox(height: 16),
        Text('No Complaints in This Filter',
            style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C))),
        const SizedBox(height: 6),
        Text('All caught up in this category!',
            style: GoogleFonts.nunito(fontSize: 13,
                color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _FixedSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _FixedSliverHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Use a surface to ensure pinned header stays readable over content.
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FixedSliverHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}