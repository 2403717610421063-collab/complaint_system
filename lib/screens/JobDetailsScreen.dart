// job_details.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complaint_system/models/complaint_model.dart';
import 'package:complaint_system/services/gamification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:complaint_system/services/email_service.dart';
import 'package:complaint_system/services/complaint_service.dart';
import 'package:complaint_system/services/status_normalizer.dart';
import 'package:complaint_system/services/user_collection_bridge.dart';
import '../models/Application.dart';
import '../services/app_localizations.dart';
import '../screens/SignatureProofScreen.dart';

class JobDetailScreen extends StatefulWidget {
  final Complaint task;
  const JobDetailScreen({super.key, required this.task});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  // ─── Theme ───────────────────────────────────────────────────────────────────
  static const _purple       = Color(0xFF5B2D91);
  static const _purpleLight  = Color(0xFF7C3FBE);
  static const _purpleFaint  = Color(0xFFF3EEFF);
  static const _bgPage       = Color(0xFFF4F2FA);
  static const _cardBg       = Colors.white;
  static const _green        = Color(0xFF22C55E);
  static const _amber        = Color(0xFFF59E0B);
  static const _red          = Color(0xFFEF4444);
  static const _textDark     = Color(0xFF1C0B3A);
  static const _textMid      = Color(0xFF64748B);

  // ─── State ───────────────────────────────────────────────────────────────────
  final TextEditingController _resolutionController = TextEditingController();
  final ImagePicker           _picker               = ImagePicker();
  final ComplaintService      _complaintService     = ComplaintService();
  final UserCollectionBridge  _userBridge           = UserCollectionBridge();

  File?   _pickedImage;
  String? _signatureImagePath;
  String? _uploadedProofImageUrl;
  bool    _signatureCaptured = false;
  late String _liveStage;
  bool _submitting = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  String _normalize(String s) => normalizeStatus(s);

  @override
  void initState() {
    super.initState();
    _liveStage = widget.task.status;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _resolutionController.dispose();
    super.dispose();
  }

  // ─── Maps ────────────────────────────────────────────────────────────────────
  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination="
            "${widget.task.latitude},${widget.task.longitude}");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ─── Status update ───────────────────────────────────────────────────────────
  Future<void> _updateFirestoreTask(String newStatus,
      {String? resolution}) async {
    await FirebaseFirestore.instance
        .collection('complaints')
        .doc(widget.task.complaintId)
        .update({
      'status': newStatus,
      if (resolution != null) 'resolutionDetails': resolution,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() {
      widget.task.status = newStatus;
      _liveStage = newStatus;
    });
  }

  // ─── Notify & start ──────────────────────────────────────────────────────────
  Future<void> _notifyCitizenAndStart() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("📢 Citizen notified – work started")));
    await _updateFirestoreTask('in_progress');
  }

  // ─── Cloudinary Upload ───────────────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final cloudinary = CloudinaryPublic(
          Application.cloud_name, Application.complaint_img,
          cache: false);
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path,
            resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Upload Error: $e');
      return null;
    }
  }

  // ─── Pick image ──────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (img != null && mounted) {
      setState(() => _pickedImage = File(img.path));
    }
  }

  Future<void> _pickImageFromCamera() async {
    final img = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 70);
    if (img != null && mounted) {
      setState(() => _pickedImage = File(img.path));
    }
  }

  // ─── Open SignatureProofScreen ────────────────────────────────────────────────
  Future<void> _openSignatureScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureProofScreen(
          complaint: widget.task,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _signatureCaptured = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Signature captured successfully"),
          backgroundColor: _green,
        ),
      );
    }
  }

  // ─── Resolution dialog ────────────────────────────────────────────────────────
  void _showResolutionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return _ResolutionSheet(
              resolutionController: _resolutionController,
              pickedImage: _pickedImage,
              signatureCaptured: _signatureCaptured,
              onPickGallery: () async {
                await _pickImage();
                setModalState(() {}); // Forces the bottom sheet to refresh visually
              },
              onPickCamera: () async {
                await _pickImageFromCamera();
                setModalState(() {});
              },
              onOpenSignature: () async {
                await _openSignatureScreen();
                setModalState(() {});
              },
              submitting: _submitting,
              onSubmit: () => _submitResolution(setModalState),
            );
          }
      ),
    );
  }

  // ─── Submit resolution ────────────────────────────────────────────────────────
  Future<void> _submitResolution(StateSetter setModalState) async {
    if (_resolutionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ Please enter action taken"),
          backgroundColor: _amber));
      return;
    }
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ Please attach a proof photo"),
          backgroundColor: _amber));
      return;
    }
    if (!_signatureCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ Citizen signature is required"),
          backgroundColor: _amber));
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = true);
    setModalState(() => _submitting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⏳ Uploading proof photo..."),
          duration: Duration(seconds: 4)));

      final proofUrl = await _uploadToCloudinary(_pickedImage!);
      final proofImageUrl = proofUrl ?? 'placeholder_image_url';

      await _complaintService.markResolved(
        complaintId: widget.task.complaintId,
        resolutionNote: _resolutionController.text,
        proofImage: proofImageUrl,
      );

      if (!mounted) return;
      setState(() {
        widget.task.status = 'resolved';
        _liveStage = 'resolved';
        _submitting = false;
      });

      await GamificationService().awardPointsForResolution(widget.task.userId);

      // Successfully finished everything: Now close the bottom sheet safe and clean
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Complaint resolved, points awarded & email sent"),
          backgroundColor: _green));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      setModalState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e"), backgroundColor: _red));
    }
  }

  // ─── Timeline ─────────────────────────────────────────────────────────────────
  Widget _trackingTimeline() {
    const stages = ['assigned', 'on_the_way', 'in_progress', 'resolved'];
    final stageLabels = {
      'assigned'   : 'Assigned',
      'on_the_way' : 'On the Way',
      'in_progress': 'In Progress',
      'resolved'   : 'Resolved',
    };
    final stageIcons = {
      'assigned'   : Icons.assignment_ind_rounded,
      'on_the_way' : Icons.directions_run_rounded,
      'in_progress': Icons.construction_rounded,
      'resolved'   : Icons.verified_rounded,
    };

    String normalized = _normalize(_liveStage);
    if (normalized == 'pending' || normalized == 'classified' || normalized=='pending_assignment') {
      normalized = 'assigned';
    }
    int currentIndex = stages.indexWhere((s) => _normalize(s) == normalized);
    if (currentIndex == -1) currentIndex = 0;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Progress",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _textDark)),
          const SizedBox(height: 16),
          ...List.generate(stages.length, (i) {
            final done    = i <= currentIndex;
            final active  = i == currentIndex;
            final isLast  = i == stages.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: active ? 34 : 26,
                        height: active ? 34 : 26,
                        decoration: BoxDecoration(
                          color: done ? _purple : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [
                            BoxShadow(
                                color: _purple.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                              : [],
                        ),
                        child: Icon(stageIcons[stages[i]],
                            size: active ? 17 : 13,
                            color: done ? Colors.white : Colors.grey.shade400),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 36,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            gradient: done && i < currentIndex
                                ? const LinearGradient(
                                colors: [_purple, _purpleLight],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter)
                                : null,
                            color: done && i < currentIndex ? null : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageLabels[stages[i]] ?? stages[i],
                        style: TextStyle(
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: active ? 14 : 13,
                          color: done ? _textDark : _textMid,
                        ),
                      ),
                      if (active)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _purpleFaint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("Current",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _purple,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────────────────────
  Widget _actionButtons() {
    String stage = _normalize(_liveStage);
    if (stage == 'pending' || stage == 'classified' || stage=='pending_assignment' || stage=='under_review' ) stage = 'assigned';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: _purple.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stage == 'assigned')
            _gradientButton(
              label: "NOTIFY CITIZEN & START WORK",
              icon: Icons.notifications_active_rounded,
              onTap: _notifyCitizenAndStart,
            ),
          if (stage == 'in_progress')
            _gradientButton(
              label: "SUBMIT WORK & RESOLVE",
              icon: Icons.check_circle_rounded,
              onTap: _showResolutionDialog,
              color1: const Color(0xFF16A34A),
              color2: const Color(0xFF22C55E),
            ),
          if (stage == 'resolved') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, color: _green, size: 20),
                  SizedBox(width: 8),
                  Text("Complaint Resolved",
                      style: TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showResolutionDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _purpleFaint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _purple.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded,
                        color: _purple, size: 18),
                    SizedBox(width: 8),
                    Text("View / Update Proof",
                        style: TextStyle(
                            color: _purple,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('Execution Details ') ?? "Execution Details",
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(_normalize(_liveStage)),
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          )
        ],
      ),
      bottomNavigationBar: _actionButtons(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerCard(),
              const SizedBox(height: 16),
              _trackingTimeline(),
              const SizedBox(height: 16),
              _sectionLabel("Issue Description"),
              _glassCard(
                child: Text(widget.task.description,
                    style: const TextStyle(color: _textDark, fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 16),
              _sectionLabel("Location"),
              _glassCard(
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: _red, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("GPS Coordinates", style: TextStyle(fontSize: 11, color: _textMid)),
                        Text(
                          "Lat ${widget.task.latitude}, Lon ${widget.task.longitude}",
                          style: const TextStyle(fontSize: 13, color: _textDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Wrap it in a clean constraint layout block
                  IntrinsicWidth(
                    child: ElevatedButton.icon(
                      onPressed: _openGoogleMaps,
                      icon: const Icon(Icons.navigation_rounded, size: 15),
                      label: const Text("Navigate",
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ),
              if (widget.task.imageUrl != null && widget.task.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel("Complaint Photo"),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.task.imageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _purpleFaint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: _purple, strokeWidth: 2),
                      ),
                    ),
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Color(0xFFCBD5E1), size: 36),
                          SizedBox(height: 6),
                          Text("Image unavailable", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header card ─────────────────────────────────────────────────────────────
  Widget _headerCard() {
    final sColor = _statusColor(_normalize(_liveStage));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_purple, _purpleLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _purple.withOpacity(0.30), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(widget.task.category,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sColor.withOpacity(0.5)),
                ),
                child: Text(_statusLabel(_normalize(_liveStage)),
                    style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.task.title,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 8),
          Text("ID: #${widget.task.complaintId}",
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))
      ],
    ),
    child: child,
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textMid, letterSpacing: 0.4)),
  );

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color color1 = _purple,
    Color color2 = _purpleLight,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color1, color2]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: color1.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
        ),
      );

  Color _statusColor(String s) {
    if (s.contains('resolved') || s.contains('closed')) return _green;
    if (s.contains('progress')) return const Color(0xFF3B82F6);
    if (s.contains('assigned')) return _amber;
    if (s.contains('escalat'))  return _red;
    return _textMid;
  }

  String _statusLabel(String s) {
    final map = {
      'assigned'   : 'Assigned',
      'on_the_way' : 'On the Way',
      'in_progress': 'In Progress',
      'resolved'   : 'Resolved',
      'pending'    : 'Pending',
      'classified' : 'Classified',
    };
    return map[s] ?? s.replaceAll('_', ' ');
  }
}

class _ResolutionSheet extends StatelessWidget {
  final TextEditingController resolutionController;
  final File?   pickedImage;
  final bool    signatureCaptured;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onOpenSignature;
  final VoidCallback onSubmit;
  final bool submitting;

  const _ResolutionSheet({
    required this.resolutionController,
    required this.pickedImage,
    required this.signatureCaptured,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onOpenSignature,
    required this.onSubmit,
    required this.submitting,
  });

  static const _purple      = Color(0xFF5B2D91);
  static const _purpleFaint = Color(0xFFF3EEFF);
  static const _green       = Color(0xFF22C55E);
  static const _textDark    = Color(0xFF1C0B3A);
  static const _textMid     = Color(0xFF64748B);
  static const _amber       = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final allDone = pickedImage != null && signatureCaptured;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _purpleFaint, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.assignment_turned_in_rounded, color: _purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Submit Work Proof", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
                  Text("All three fields required", style: TextStyle(fontSize: 12, color: _textMid)),
                ],
              ),
            ]),
            const SizedBox(height: 24),

            _stepHeader("1", "Proof Photo", pickedImage != null),
            const SizedBox(height: 8),
            if (pickedImage != null)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(pickedImage!, width: double.infinity, height: 180, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onPickGallery,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ])
            else
              Row(children: [
                Expanded(child: _photoButton("Camera", Icons.camera_alt_rounded, onPickCamera)),
                const SizedBox(width: 10),
                Expanded(child: _photoButton("Gallery", Icons.photo_library_rounded, onPickGallery)),
              ]),
            const SizedBox(height: 20),

            _stepHeader("2", "Action Taken", resolutionController.text.trim().isNotEmpty),
            const SizedBox(height: 8),
            TextField(
              controller: resolutionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Describe what was done to resolve this issue…",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8F7FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            _stepHeader("3", "Citizen Signature", signatureCaptured),
            const SizedBox(height: 8),
            if (signatureCaptured)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _green.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_rounded, color: _green, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Signature Captured", style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 14)),
                        Text("Citizen has signed off on the resolution", style: TextStyle(color: Color(0xFF166534), fontSize: 11)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenSignature,
                    child: const Text("Redo", style: TextStyle(color: _green, fontSize: 12)),
                  ),
                ]),
              )
            else
              GestureDetector(
                onTap: onOpenSignature,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _purpleFaint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _purple.withOpacity(0.25)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.draw_rounded, color: _purple, size: 32),
                      SizedBox(height: 6),
                      Text("Tap to Collect Citizen Signature", style: TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 2),
                      Text("Required for proof of resolution", style: TextStyle(color: _textMid, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 28),

            if (!allDone)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _missingFieldsText(pickedImage, signatureCaptured),
                      style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                    ),
                  ),
                ]),
              ),

            GestureDetector(
              onTap: submitting ? null : onSubmit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: allDone
                      ? const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)])
                      : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: allDone ? [BoxShadow(color: _green.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Center(
                  child: submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(allDone ? Icons.check_circle_rounded : Icons.lock_rounded, color: allDone ? Colors.white : Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(allDone ? "FINALIZE & CLOSE" : "COMPLETE ALL STEPS",
                        style: TextStyle(color: allDone ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader(String number, String title, bool done) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: done ? _green : _purple, shape: BoxShape.circle),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
              : Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textDark)),
      if (done) ...[
        const SizedBox(width: 6),
        const Icon(Icons.verified_rounded, color: _green, size: 15),
      ],
    ],
  );

  Widget _photoButton(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: _purpleFaint, borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.2))),
          child: Column(
            children: [
              Icon(icon, color: _purple, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: _purple, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      );

  String _missingFieldsText(File? img, bool sigCaptured) {
    final missing = <String>[];
    if (img == null) missing.add("proof photo");
    if (!sigCaptured) missing.add("citizen signature");
    return "Still needed: ${missing.join(' & ')}";
  }
}