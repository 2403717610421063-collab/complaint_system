import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/admin_complaint_model.dart';
import '../services/complaint_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/escalation_timer.dart';
import '../widgets/complaint_heatmap_section.dart';
import 'package:complaint_system/screens/login_screen.dart';
import '../theme/app_theme.dart' hide StatusBadge;
import 'aee_section_dashboard_screen.dart';
import 'intervention.dart';

enum AeeHomeMode { dashboard, complaints }

class AEEHome extends StatefulWidget {
  const AEEHome({
    super.key,
    this.mode = AeeHomeMode.dashboard,
  });

  final AeeHomeMode mode;

  @override
  State<AEEHome> createState() => _AEEHomeState();
}

class _AEEHomeState extends State<AEEHome> {
  bool _escalationChecked = false;
  bool _generatingReport  = false;
  final ComplaintService _complaintService = ComplaintService();

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple       = Color(0xFF7B2FBE);
  static const _purpleDark   = Color(0xFF4A1680);
  static const _purpleDeep   = Color(0xFF2D0E5E);
  static const _purpleLight  = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg           = Color(0xFFF4F3F9);

  // ─── TN Gov PDF palette ───────────────────────────────────────────────────
  static const _tnBlue   = PdfColor.fromInt(0xFF003580);
  static const _tnRed    = PdfColor.fromInt(0xFFC0392B);
  static const _tnGold   = PdfColor.fromInt(0xFFB8860B);
  static const _tnLight  = PdfColor.fromInt(0xFFE8F0FE);
  static const _tnGray   = PdfColor.fromInt(0xFFF5F5F5);
  static const _tnGrayTx = PdfColor.fromInt(0xFF555555);

  @override
  void initState() {
    super.initState();
    _triggerEscalationCheck();
  }

  Future<void> _triggerEscalationCheck() async {
    if (_escalationChecked) return;
    _escalationChecked = true;
    try {
      await ComplaintService().checkAndProcessEscalations();
    } catch (_) {}
  }

  Stream<List<ComplaintModel>> _streamAeeComplaints() {
    return _complaintService.streamActiveComplaints().map(
          (complaints) => complaints
          .where((c) => c.assignedRole.toLowerCase() == 'aee')
          .toList(growable: false),
    );
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

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    final s = status.trim().toLowerCase().replaceAll(' ', '_');
    if (s.contains('resolved') || s.contains('closed')) return const Color(0xFF22C55E);
    if (s.contains('progress'))  return const Color(0xFF3B82F6);
    if (s.contains('assigned'))  return const Color(0xFFF59E0B);
    if (s.contains('escalat'))   return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  PdfColor _pdfStatusColor(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('resolved') || s.contains('closed'))
      return const PdfColor.fromInt(0xFF1E8449);
    if (s.contains('progress')) return const PdfColor.fromInt(0xFF2471A3);
    if (s.contains('assigned')) return const PdfColor.fromInt(0xFFD68910);
    if (s.contains('escalat'))  return const PdfColor.fromInt(0xFFC0392B);
    return PdfColors.grey600;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ─── REPORT GENERATION ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _generateReport(List<ComplaintModel> complaints) async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);

    try {
      final pdf    = pw.Document();
      final now    = DateTime.now();
      final refNo  = 'TANGEDCO/SAL/AEE/${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final dateStr= '${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year}';
      final timeStr= '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

      final total       = complaints.length;
      final escalated   = complaints.where((c) => c.status.toLowerCase().contains('escalat')).length;
      final inProgress  = complaints.where((c) => c.status.toLowerCase().contains('progress')).length;
      final resolved    = complaints.where((c) => c.status.toLowerCase().contains('resolved')).length;
      final pending     = total - resolved;

      // Category breakdown
      final catMap = <String, int>{};
      for (final c in complaints) {
        final cat = c.category.trim().isEmpty ? 'Unknown' : c.category.trim();
        catMap[cat] = (catMap[cat] ?? 0) + 1;
      }
      final sortedCats = catMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // ── Helper text styles ─────────────────────────────────────────────────
      pw.TextStyle bold(double size, {PdfColor color = PdfColors.black}) =>
          pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: size, color: color);
      pw.TextStyle regular(double size, {PdfColor color = PdfColors.black}) =>
          pw.TextStyle(fontSize: size, color: color);

      // ── Page builder ──────────────────────────────────────────────────────
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(18, 15, 18, 18),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _tnBlue, width: 0.5)),
            ),
            child: pw.Text(
              'TANGEDCO — AEE Complaint Escalation Report  |  Ref: $refNo  |  Generated: $dateStr $timeStr  |  Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: regular(6.5, color: _tnGrayTx),
              textAlign: pw.TextAlign.center,
            ),
          ),
          build: (ctx) => [

            // ══ HEADER BAND ════════════════════════════════════════════════
            pw.Container(
              decoration: pw.BoxDecoration(
                color: _tnBlue,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'தமிழ்நாடு அரசு  /  Government of Tamil Nadu',
                    style: bold(11, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Tamil Nadu Generation and Distribution Corporation Limited (TANGEDCO)',
                    style: regular(8, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'Salem District  |  Salem Division  |  Electrical Section — AEE Office',
                    style: regular(7.5, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 5),

            // ══ REPORT TITLE BAND ══════════════════════════════════════════
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _tnRed, width: 1.2),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Center(
                child: pw.Text(
                  'COMPLAINT ESCALATION REPORT — AEE DASHBOARD',
                  style: bold(10, color: _tnRed),
                ),
              ),
            ),

            pw.SizedBox(height: 6),

            // ══ META INFO TABLE ════════════════════════════════════════════
            _pdfMetaTable(refNo, dateStr, timeStr, total, bold, regular),

            pw.SizedBox(height: 8),

            // ══ SECTION 1: SUMMARY STATS ════════════════════════════════
            _pdfSectionTitle('1.  SUMMARY OF COMPLAINTS', bold),
            pw.SizedBox(height: 4),
            _pdfStatsRow(total, escalated, inProgress, resolved, pending, bold, regular),

            pw.SizedBox(height: 8),

            // ══ SECTION 2: COMPLAINT REGISTER TABLE ═══════════════════════
            _pdfSectionTitle('2.  DETAILED COMPLAINT REGISTER', bold),
            pw.SizedBox(height: 4),
            _pdfComplaintTable(complaints, bold, regular),

            pw.SizedBox(height: 8),

            // ══ SECTION 3: CATEGORY ANALYSIS ══════════════════════════════
            _pdfSectionTitle('3.  CATEGORY-WISE ANALYSIS', bold),
            pw.SizedBox(height: 4),
            _pdfCategoryTable(sortedCats, total, bold, regular),

            pw.SizedBox(height: 10),

            // ══ SECTION 4: DECLARATION ════════════════════════════════════
            _pdfSectionTitle('4.  DECLARATION', bold),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _tnBlue, width: 0.8),
                borderRadius: pw.BorderRadius.circular(3),
                color: _tnGray,
              ),
              child: pw.Text(
                'I hereby certify that the information furnished in this report is true and correct to the best of my knowledge '
                    'and belief. This report has been generated from the TANGEDCO Complaint Management System and '
                    'reflects all active escalations assigned to the AEE Division as on $dateStr.',
                style: regular(7.5),
              ),
            ),

            pw.SizedBox(height: 16),

            // ══ SIGNATURE BLOCK ═══════════════════════════════════════════
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date: $dateStr', style: regular(7.5)),
                    pw.Text('Time: $timeStr', style: regular(7.5)),
                    pw.Text('Place: Salem', style: regular(7.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 120,
                      height: 0.5,
                      color: _tnBlue,
                      margin: const pw.EdgeInsets.only(bottom: 4),
                    ),
                    pw.Text('Signature of AEE', style: bold(8, color: _tnBlue)),
                    pw.Text('Assistant Executive Engineer', style: regular(7)),
                    pw.Text('Salem Division — TANGEDCO', style: regular(7)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            // ══ OFFICE SEAL NOTE ══════════════════════════════════════════
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _tnGold, width: 0.8),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              padding: const pw.EdgeInsets.all(6),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8, height: 8,
                    decoration: const pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: _tnGold,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'This is a system-generated report. Office seal and countersignature required for official use.',
                    style: regular(7, color: _tnGold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // ── Share / Print ────────────────────────────────────────────────────
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
        'AEE_Complaint_Report_${now.day.toString().padLeft(2,'0')}${now.month.toString().padLeft(2,'0')}${now.year}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generation failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  // ─── PDF Widget Helpers ───────────────────────────────────────────────────

  pw.Widget _pdfSectionTitle(
      String title,
      pw.TextStyle Function(double, {PdfColor color}) bold,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: _tnLight,
        border: const pw.Border(left: pw.BorderSide(color: _tnBlue, width: 3)),
      ),
      child: pw.Text(title, style: bold(8.5, color: _tnBlue)),
    );
  }

  pw.Widget _pdfMetaTable(
      String refNo,
      String dateStr,
      String timeStr,
      int total,
      pw.TextStyle Function(double, {PdfColor color}) bold,
      pw.TextStyle Function(double, {PdfColor color}) regular,
      ) {
    const cellDecor = pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        right:  pw.BorderSide(color: PdfColors.grey300, width: 0.4),
      ),
    );

    pw.Widget lbl(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t, style: bold(7.5, color: _tnBlue)),
    );
    pw.Widget val(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t, style: regular(7.5)),
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _tnBlue, width: 1),
        borderRadius: pw.BorderRadius.circular(3),
        color: const PdfColor.fromInt(0xFFFAFAFA),
      ),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(1.8),
          2: pw.FlexColumnWidth(1.2),
          3: pw.FlexColumnWidth(1.8),
        },
        children: [
          pw.TableRow(children: [
            pw.Container(decoration: cellDecor, child: lbl('Report Ref No.')),
            pw.Container(decoration: cellDecor, child: val(refNo)),
            pw.Container(decoration: cellDecor, child: lbl('Date & Time')),
            pw.Container(decoration: cellDecor, child: val('$dateStr  $timeStr')),
          ]),
          pw.TableRow(children: [
            pw.Container(decoration: cellDecor, child: lbl('Reporting Officer')),
            pw.Container(decoration: cellDecor, child: val('AEE Officer')),
            pw.Container(decoration: cellDecor, child: lbl('Designation')),
            pw.Container(decoration: cellDecor, child: val('Asst. Executive Engineer')),
          ]),
          pw.TableRow(children: [
            pw.Container(decoration: cellDecor, child: lbl('District')),
            pw.Container(decoration: cellDecor, child: val('Salem')),
            pw.Container(decoration: cellDecor, child: lbl('Division')),
            pw.Container(decoration: cellDecor, child: val('Salem Division')),
          ]),
          pw.TableRow(children: [
            pw.Container(decoration: cellDecor, child: lbl('Report Period')),
            pw.Container(decoration: cellDecor, child: val('Active Escalations as on $dateStr')),
            pw.Container(decoration: cellDecor, child: lbl('Total Complaints')),
            pw.Container(decoration: cellDecor, child: val('$total')),
          ]),
        ],
      ),
    );
  }

  pw.Widget _pdfStatsRow(
      int total,
      int escalated,
      int inProgress,
      int resolved,
      int pending,
      pw.TextStyle Function(double, {PdfColor color}) bold,
      pw.TextStyle Function(double, {PdfColor color}) regular,
      ) {
    final stats = [
      ('Total',       '$total',       const PdfColor.fromInt(0xFF003580), _tnLight),
      ('Escalated',   '$escalated',   const PdfColor.fromInt(0xFFC0392B), const PdfColor.fromInt(0xFFFDECEA)),
      ('In Progress', '$inProgress',  const PdfColor.fromInt(0xFF2471A3), const PdfColor.fromInt(0xFFE3F2FD)),
      ('Resolved',    '$resolved',    const PdfColor.fromInt(0xFF1E8449), const PdfColor.fromInt(0xFFE8F5E9)),
      ('Pending',     '$pending',     const PdfColor.fromInt(0xFFD35400), const PdfColor.fromInt(0xFFFFF3E0)),
    ];

    return pw.Row(
      children: stats.map((s) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              color: s.$4,
              border: pw.Border.all(color: s.$3, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                pw.Text(s.$2, style: bold(18, color: s.$3)),
                pw.SizedBox(height: 2),
                pw.Text(s.$1, style: regular(7, color: _tnGrayTx),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _pdfComplaintTable(
      List<ComplaintModel> complaints,
      pw.TextStyle Function(double, {PdfColor color}) bold,
      pw.TextStyle Function(double, {PdfColor color}) regular,
      ) {
    pw.Widget hdr(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t,
          style: bold(7, color: PdfColors.white),
          textAlign: pw.TextAlign.center),
    );

    pw.Widget cell(String t, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(t,
              style: isBold
                  ? bold(7, color: color ?? PdfColors.black)
                  : regular(7, color: color ?? PdfColors.black),
              textAlign: align),
        );

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _tnBlue),
      children: [
        hdr('S.No.'),
        hdr('Complaint ID'),
        hdr('Category'),
        hdr('Title / Description'),
        hdr('Status'),
        hdr('Last Updated'),
      ],
    );

    final dataRows = complaints.asMap().entries.map((entry) {
      final i    = entry.key;
      final comp = entry.value;
      final bg   = i.isEven ? _tnGray : PdfColors.white;
      final sc   = _pdfStatusColor(comp.status);

      String lastUpd = '';
      if (comp.lastUpdated != null) {
        final d = comp.lastUpdated!;
        lastUpd =
        '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
      }

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          cell('${i + 1}', align: pw.TextAlign.center),
          cell(comp.complaintId.length > 10 ? comp.complaintId.substring(0, 10) : comp.complaintId,
              align: pw.TextAlign.center),
          cell(comp.category),
          cell(comp.title.length > 60 ? '${comp.title.substring(0, 60)}...' : comp.title),
          cell(comp.status.replaceAll('_', ' '),
              isBold: true, color: sc, align: pw.TextAlign.center),
          cell(lastUpd, align: pw.TextAlign.center),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FixedColumnWidth(65),
        2: pw.FixedColumnWidth(60),
        3: pw.FlexColumnWidth(1),
        4: pw.FixedColumnWidth(68),
        5: pw.FixedColumnWidth(58),
      },
      children: [headerRow, ...dataRows],
    );
  }

  pw.Widget _pdfCategoryTable(
      List<MapEntry<String, int>> sortedCats,
      int total,
      pw.TextStyle Function(double, {PdfColor color}) bold,
      pw.TextStyle Function(double, {PdfColor color}) regular,
      ) {
    pw.Widget hdr(String t) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(t,
          style: bold(7.5, color: PdfColors.white),
          textAlign: pw.TextAlign.center),
    );
    pw.Widget cell(String t,
        {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t,
              style: isBold ? bold(7.5) : regular(7.5),
              textAlign: align),
        );

    final rows = sortedCats.asMap().entries.map((entry) {
      final i   = entry.key;
      final cat = entry.value;
      final pct = total > 0
          ? '${(cat.value / total * 100).toStringAsFixed(1)}%'
          : '0.0%';
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isEven ? _tnGray : PdfColors.white),
        children: [
          cell('${i + 1}', align: pw.TextAlign.center),
          cell(cat.key),
          cell('${cat.value}', align: pw.TextAlign.center),
          cell(pct, align: pw.TextAlign.center),
        ],
      );
    }).toList();

    final totalRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _tnLight),
      children: [
        cell('', align: pw.TextAlign.center),
        cell('TOTAL', isBold: true),
        cell('$total', align: pw.TextAlign.center, isBold: true),
        cell('100%', align: pw.TextAlign.center, isBold: true),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(35),
        1: pw.FlexColumnWidth(1),
        2: pw.FixedColumnWidth(55),
        3: pw.FixedColumnWidth(75),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _tnBlue),
          children: [
            hdr('S.No.'),
            hdr('Category'),
            hdr('Count'),
            hdr('Percentage'),
          ],
        ),
        ...rows,
        totalRow,
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ─── BUILD ────────────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: _streamAeeComplaints(),
        builder: (context, snapshot) {
          final complaints = snapshot.data ?? const <ComplaintModel>[];
          final recent = complaints.take(5).toList(growable: false);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(complaints)),

              if (widget.mode == AeeHomeMode.dashboard) ...[
                // ── QUICK STATS ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildStatsRow(complaints),
                  ),
                ),

                // ── ANALYSIS ───────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildAnalysisSection(complaints),
                  ),
                ),

                // ── HEATMAP ─────────────────────────────────────────────────
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
                      child: const ComplaintHeatmapSection(role: 'aee'),
                    ),
                  ),
                ),

                // ── DASHBOARD RECENT LABEL ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _purpleLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insights_rounded, color: _purple, size: 15),
                      ),
                      const SizedBox(width: 10),
                      Text('Recent Escalations',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E0A3C),
                          )),
                      const Spacer(),
                      if (complaints.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _purpleLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _purpleBorder),
                          ),
                          child: Text('${recent.length}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _purple,
                              )),
                        ),
                    ]),
                  ),
                ),
              ] else ...[
                // ── COMPLAINTS LABEL ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _purpleLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.list_alt_rounded, color: _purple, size: 15),
                      ),
                      const SizedBox(width: 10),
                      Text('Division Escalation Queue',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E0A3C),
                          )),
                      const Spacer(),
                      if (complaints.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _purpleLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _purpleBorder),
                          ),
                          child: Text('${complaints.length}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _purple,
                              )),
                        ),
                    ]),
                  ),
                ),
              ],

              // ── LOADING ───────────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(_purple),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )

              // ── EMPTY ─────────────────────────────────────────────────────
              else if (complaints.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: _buildEmptyCard(),
                  ),
                )

              // ── COMPLAINT CARDS ───────────────────────────────────────────
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                        final source = widget.mode == AeeHomeMode.dashboard
                            ? recent
                            : complaints;
                        final comp = source[i];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 280 + i * 55),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                                offset: Offset(0, (1 - v) * 14),
                                child: child),
                          ),
                          child: _buildComplaintCard(ctx, comp),
                        );
                      },
                      childCount: widget.mode == AeeHomeMode.dashboard
                          ? recent.length
                          : complaints.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),


    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(List<ComplaintModel> complaints, {bool loading = false}) {
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                const Icon(Icons.supervisor_account_rounded,
                                    color: Colors.white70, size: 13),
                                const SizedBox(width: 5),
                                Text('Assistant Executive Engineer',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    )),
                              ]),
                        ),
                        const SizedBox(height: 10),
                        Text('AEE Dashboard',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            )),
                        const SizedBox(height: 5),
                        Text('Review & intervene on escalated issues',
                            style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                  // Report button + three-dot menu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: complaints.isEmpty
                            ? null
                            : () => _generateReport(complaints),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                complaints.isEmpty ? 0.08 : 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _generatingReport
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _generatingReport ? 'Generating...' : 'Report',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'logout') {
                            _showLogoutDialog();
                          } else if (value == 'section_dashboard') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AeeSectionDashboardScreen(),
                              ),
                            );
                          }
                          else if (value == 'heatmap') {
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
                          }
                        },
                        offset: const Offset(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Colors.white,
                        elevation: 12,
                        shadowColor: const Color(0xFF4A1680).withOpacity(0.2),
                        itemBuilder: (_) => [
                          // Section Dashboard
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
                          // Logout
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
                      ),
                    ],
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
    final escalated  = complaints.where((c) => c.status.toLowerCase().contains('escalat')).length;
    final inProgress = complaints.where((c) => c.status.toLowerCase().contains('progress')).length;
    final resolved   = complaints.where((c) => c.status.toLowerCase().contains('resolved')).length;

    return Row(children: [
      _statTile('Total',       '$total',       Icons.assignment_rounded,
          _purple,                 _purpleLight),
      const SizedBox(width: 10),
      _statTile('Escalated',   '$escalated',   Icons.warning_amber_rounded,
          const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      const SizedBox(width: 10),
      _statTile('In Progress', '$inProgress',  Icons.construction_rounded,
          const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      const SizedBox(width: 10),
      _statTile('Resolved',    '$resolved',    Icons.verified_rounded,
          const Color(0xFF22C55E), const Color(0xFFF0FDF4)),
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
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
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
        .where((c) => c.status.toLowerCase().contains('escalat'))
        .length;
    final inProgress = complaints
        .where((c) => c.status.toLowerCase().contains('progress'))
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
              Text('Escalation Analysis',
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

  // ─── Complaint Card ───────────────────────────────────────────────────────────

  Widget _buildComplaintCard(BuildContext context, ComplaintModel comp) {
    final sColor = _statusColor(comp.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            // Top section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sColor.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        color: sColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _purpleLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            comp.category.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _purple,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(comp.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E0A3C),
                              height: 1.3,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      FadeSlideRoute(
                          page: InterventionScreen(complaint: comp)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_purple, _purpleDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.engineering_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1EDF9)),

            // Bottom: timer + status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.timer_outlined,
                        color: Color(0xFFF97316), size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EscalationTimer(lastUpdated: comp.lastUpdated),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sColor.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                            color: sColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(comp.status.replaceAll('_', ' '),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sColor,
                          )),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty Card ───────────────────────────────────────────────────────────────

  Widget _buildEmptyCard() {
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
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
              color: _purpleLight, shape: BoxShape.circle),
          child: const Icon(Icons.inbox_rounded, color: _purple, size: 36),
        ),
        const SizedBox(height: 16),
        Text('No Active Escalations',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            )),
        const SizedBox(height: 6),
        Text('All AEE escalations are cleared!',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }
}
