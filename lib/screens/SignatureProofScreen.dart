import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/Application.dart' ;
import '../models/complaint_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Call this from your JobDetailScreen when the worker marks a job as done:
///
///   final signed = await Navigator.push<bool>(
///     context,
///     MaterialPageRoute(
///       builder: (_) => SignatureProofScreen(complaint: complaint),
///     ),
///   );
///   if (signed == true) { /* refresh UI */ }
/// ─────────────────────────────────────────────────────────────────────────────

class SignatureProofScreen extends StatefulWidget {
  final Complaint complaint;

  const SignatureProofScreen({super.key, required this.complaint});

  @override
  State<SignatureProofScreen> createState() => _SignatureProofScreenState();
}

class _SignatureProofScreenState extends State<SignatureProofScreen> {
  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg          = Color(0xFFF3F0FA);

  // ─── Signature state ─────────────────────────────────────────────────────────
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke      = [];
  bool _hasSignature  = false;
  bool _isSaving      = false;
  bool _isSaved       = false;
  String? _uploadedSignatureUrl;

  final GlobalKey _canvasKey = GlobalKey();

  // ─── Capture signature as base64 PNG ─────────────────────────────────────────
  Future<Uint8List?> _captureSignature() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture Error: $e");
      return null;
    }
  }
  // CLOUDINARY UPLOAD — saves bytes to temp file, then uses CloudinaryPublic
  Future<String?> _uploadToCloudinary(Uint8List imageBytes) async {
    File? tempFile;
    try {
      // Write in-memory bytes to a temp file so we can use CloudinaryFile.fromFile
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
          '${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes);

      final cloudinary = CloudinaryPublic(
          Application.cloud_name, Application.complaint_img,
          cache: false);
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(tempFile.path,
            resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Upload Error: $e');
      rethrow;
    } finally {
      // Clean up temp file
      try { await tempFile?.delete(); } catch (_) {}
    }
  }
  // ─── Save to Firestore ───────────────────────────────────────────────────────
  Future<void> _saveProof() async {
    if (!_hasSignature) {
      _snack('Please provide a signature first', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageBytes = await _captureSignature();
      if (imageBytes == null) throw Exception('Failed to capture signature');

      final signatureUrl = await _uploadToCloudinary(imageBytes);
      if (signatureUrl == null) throw Exception('No URL returned from Cloudinary');

      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId)
          .update({
        'signatureUrl':       signatureUrl,
        'signedAt':           FieldValue.serverTimestamp(),
        'proofCollected':     true,
      });

      setState(() {
        _uploadedSignatureUrl = signatureUrl;
        _isSaving = false;
        _isSaved  = true;
      });

      // Auto-pop after 5 seconds, but allow manual close
      await Future.delayed(const Duration(milliseconds: 5000));
      if (mounted && _isSaved) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Error saving proof: $e', isError: true);
    }
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasSignature  = false;
    });
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: isError ? const Color(0xFFEF4444) : _purple,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: _isSaved ? _buildSuccess() : _buildForm(),
    );
  }

  // ─── Success screen ───────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded,
                  color: Color(0xFF22C55E), size: 56),
            ),
            const SizedBox(height: 24),
            Text('Proof Saved!',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E0A3C),
                )),
            const SizedBox(height: 10),
            Text(
              'The digital signature has been\nrecorded as proof of work.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            if (_uploadedSignatureUrl != null) ...[
              const SizedBox(height: 32),
              Text('VERIFIED SIGNATURE', 
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: 1.5,
                  color: _purple.withOpacity(0.5),
                )),
              const SizedBox(height: 12),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _purpleBorder, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    _uploadedSignatureUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 48),
            // DONE BUTTON to prevent "stuck" feeling
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text('Done', 
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main form ───────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── HEADER ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildHeader()),

        // ── COMPLAINT SUMMARY ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _buildComplaintSummary(),
          ),
        ),

        // ── INSTRUCTIONS ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildInstructions(),
          ),
        ),

        // ── SIGNATURE PAD ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildSignaturePad(),
          ),
        ),

        // ── ACTION BUTTONS ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
            child: _buildActions(),
          ),
        ),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _purpleDark, Color(0xFF2D0E5E)],
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
          Positioned(top: -20, right: -30,
            child: Container(width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(bottom: 10, right: 70,
            child: Container(width: 70, height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFB06AFF).withOpacity(0.18)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proof of Work',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 4),
                      Text('Collect citizen\'s digital signature',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
                // Verified badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.draw_rounded,
                      color: Colors.white, size: 22),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Complaint Summary ───────────────────────────────────────────────────────

  Widget _buildComplaintSummary() {
    final c = widget.complaint;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: [
        _summaryRow(Icons.title_rounded,        'Job Title',  c.title),
        _divider(),
        _summaryRow(Icons.tag_rounded,          'Complaint ID', c.complaintId),
        _divider(),
        _summaryRow(Icons.category_outlined,    'Category',   c.category),
        _divider(),
        _summaryRow(Icons.calendar_today_rounded,'Date',
            DateFormat('dd MMM yyyy').format(c.date)),
      ]),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _purpleLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _purple, size: 14),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            )),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              )),
        ),
      ]),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, color: Color(0xFFF1EDF9));

  // ─── Instructions ────────────────────────────────────────────────────────────

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to collect signature',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF92400E),
                    )),
                const SizedBox(height: 4),
                Text(
                  '1. Hand the device to the citizen.\n'
                      '2. Ask them to sign in the box below.\n'
                      '3. Tap "Save Proof" to record the signature.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Signature Pad ───────────────────────────────────────────────────────────

  Widget _buildSignaturePad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _purpleLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.gesture_rounded,
                    color: _purple, size: 15),
              ),
              const SizedBox(width: 10),
              Text('Citizen Signature',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  )),
              const Spacer(),
              // Clear button
              GestureDetector(
                onTap: _clearSignature,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.refresh_rounded,
                        size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text('Clear',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        )),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Canvas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasSignature ? _purple : _purpleBorder,
                    width: _hasSignature ? 2 : 1.5,
                  ),
                ),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanStart: (d) {
                      setState(() {
                        _currentStroke = [d.localPosition];
                        _hasSignature  = true;
                      });
                    },
                    onPanUpdate: (d) {
                      setState(() => _currentStroke.add(d.localPosition));
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _strokes.add(List.from(_currentStroke));
                        _currentStroke = [];
                      });
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                      ),
                      size: const Size(double.infinity, 220),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Sign here hint
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(children: [
              const Icon(Icons.edit_rounded,
                  size: 12, color: Color(0xFFB0A8C8)),
              const SizedBox(width: 6),
              Text(
                _hasSignature
                    ? 'Signature recorded ✓'
                    : 'Sign in the box above',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: _hasSignature
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFB0A8C8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── Action Buttons ───────────────────────────────────────────────────────────

  Widget _buildActions() {
    return Column(children: [
      // Save proof button
      GestureDetector(
        onTap: (_isSaving || !_hasSignature) ? null : _saveProof,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: (_isSaving || !_hasSignature)
                ? LinearGradient(colors: [
              _purple.withOpacity(0.4),
              _purpleDark.withOpacity(0.4),
            ])
                : const LinearGradient(
              colors: [_purple, _purpleDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: (_isSaving || !_hasSignature)
                ? []
                : [
              BoxShadow(
                color: _purple.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _isSaving
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Save Proof',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Cancel
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _purpleBorder, width: 1.5),
          ),
          child: Center(
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _purple,
                )),
          ),
        ),
      ),
    ]);
  }
}

// ─── Signature Painter ────────────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    // White background (needed for image capture)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFAF8FF),
    );

    final paint = Paint()
      ..color = const Color(0xFF4A1680)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> points) {
      if (points.isEmpty) return;
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        if (i == 1) {
          path.lineTo(points[i].dx, points[i].dy);
        } else {
          final mid = Offset(
            (points[i - 1].dx + points[i].dx) / 2,
            (points[i - 1].dy + points[i].dy) / 2,
          );
          path.quadraticBezierTo(
              points[i - 1].dx, points[i - 1].dy, mid.dx, mid.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    drawStroke(currentStroke);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}