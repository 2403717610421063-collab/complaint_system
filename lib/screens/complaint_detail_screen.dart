import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:complaint_system/models/complaint_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'feedback_page.dart';
import 'package:complaint_system/services/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'package:complaint_system/screens/chat_screen.dart';

class ComplaintDetailsPage extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailsPage({super.key, required this.complaint});

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('closed') || s.contains('finished')) {
      return const Color(0xFF15803D);
    }
    if (s.contains('resolved') || s.contains('completed')) {
      return const Color(0xFF22C55E);
    }
    if (s.contains('progress')) return const Color(0xFF3B82F6);
    if (s.contains('assigned')) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF97316);
      case 'low': return const Color(0xFF22C55E);
      default: return const Color(0xFF94A3B8);
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Icons.keyboard_double_arrow_up_rounded;
      case 'medium': return Icons.drag_handle_rounded;
      case 'low': return Icons.keyboard_double_arrow_down_rounded;
      default: return Icons.remove_rounded;
    }
  }

  IconData _categoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('road') || c.contains('infra')) return Icons.add_road_rounded;
    if (c.contains('water') || c.contains('drain')) return Icons.water_drop_outlined;
    if (c.contains('electric') || c.contains('power')) return Icons.bolt_rounded;
    if (c.contains('garbage') || c.contains('waste')) return Icons.delete_outline_rounded;
    if (c.contains('park') || c.contains('green')) return Icons.park_outlined;
    if (c.contains('noise')) return Icons.volume_up_outlined;
    if (c.contains('traffic')) return Icons.traffic_outlined;
    if (c.contains('health') || c.contains('medical')) return Icons.local_hospital_outlined;
    return Icons.category_outlined;
  }

  int _currentStepIndex(String status) {
    final s = status.toLowerCase();
    if (s.contains('closed') || s.contains('finished')) return 3;
    if (s.contains('resolved') || s.contains('completed')) return 3;
    if (s.contains('progress')) return 2;
    if (s.contains('assigned')) return 1;
    return 0;
  }

  // ─── Fullscreen Image Viewer ───────────────────────────────────────────────

  void _openFullscreenImage(String url, String tag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(tag, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 1.0,
                maxScale: 4.0,
                child: Hero(
                  tag: url,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Feedback Submission Logic ──────────────────────────────────────────────

  Future<void> _submitFeedbackToFirebase(int rating, Function(VoidCallback) setSheetState) async {
    setSheetState(() => _isSubmittingFeedback = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final complaintRef = db.collection('complaints').doc(widget.complaint.complaintId);
      batch.update(complaintRef, {
        'rating': rating.toDouble(),
      });

      final workerIds = widget.complaint.assignedWorkerIds;

      if (workerIds.isNotEmpty) {
        for (String id in workerIds) {
          if (id.trim().isEmpty || id.toLowerCase() == 'unassigned') continue;

          final workerRef = db.collection('Users').doc(id);
          batch.update(workerRef, {
            'totalRating': FieldValue.increment(rating),
            'ratingCount': FieldValue.increment(1),
          });
        }
      }

      await batch.commit();

      setState(() {
        widget.complaint.rating = rating.toDouble();
      });

      setSheetState(() {
        _isSubmittingFeedback = false;
        _feedbackSubmitted = true;
      });

    } catch (e) {
      setSheetState(() => _isSubmittingFeedback = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Feedback Sheet ──────────────────────────────────────────────────────────

  int _selectedRating = 0;
  bool _feedbackSubmitted = false;

  void _showFeedbackSheet() {
    _selectedRating = 0;
    _feedbackSubmitted = false;
    _isSubmittingFeedback = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !_isSubmittingFeedback,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 28, left: 24, right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: _feedbackSubmitted
                  ? _feedbackSuccess()
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF7B2FBE).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 18),
                  Text('Rate Your Experience', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Text('How satisfied are you with the resolution?', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < _selectedRating;
                      return GestureDetector(
                        onTap: _isSubmittingFeedback ? null : () => setSheet(() => _selectedRating = i + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                            size: filled ? 44 : 38,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  if (_selectedRating > 0)
                    Text(
                      ['', 'Poor 😞', 'Fair 😐', 'Good 🙂', 'Great 😊', 'Excellent 🤩'][_selectedRating],
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: [Colors.transparent, const Color(0xFFEF4444), const Color(0xFFF97316), const Color(0xFFF59E0B), const Color(0xFF22C55E), const Color(0xFF10B981)][_selectedRating],
                      ),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedRating == 0 || _isSubmittingFeedback)
                          ? null
                          : () async {
                        await _submitFeedbackToFirebase(_selectedRating, setSheet);
                        if (_feedbackSubmitted) {
                          Future.delayed(const Duration(milliseconds: 1800), () => Navigator.pop(ctx));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF7B2FBE),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmittingFeedback
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                        'Submit Feedback',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _selectedRating == 0 ? const Color(0xFF94A3B8) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _feedbackSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 32), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 48),
        ),
        const SizedBox(height: 18),
        Text('Thank You! 🎉', style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text('Your feedback has been submitted\nsuccessfully.', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500, height: 1.5)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Open Office Location in Maps ──────────────────────────────────────────
  Future<void> _openOfficeInGoogleMaps() async {
    final lat = widget.complaint.officeLat;
    final lon = widget.complaint.officeLon;

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Office location data is incomplete"),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final nativeMapUri = Uri.parse("geo:$lat,$lon?q=$lat,$lon(Assigned+Office)");

    try {
      if (await canLaunchUrl(nativeMapUri)) {
        await launchUrl(nativeMapUri, mode: LaunchMode.externalApplication);
      } else {
        final webMapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Cannot open maps: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Status Banner ───────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final color = _statusColor(widget.complaint.status);
    final s = widget.complaint.status.toLowerCase();
    String message = 'Your complaint is being reviewed.';
    IconData msgIcon = Icons.hourglass_top_rounded;

    if (s.contains('closed') || s.contains('finished')) {
      message = 'Complaint is fully verified and closed. Thank you!';
      msgIcon = Icons.task_alt_rounded;
    } else if (s.contains('resolved') || s.contains('completed')) {
      message = 'Work completed! Awaiting final verification by officials.';
      msgIcon = Icons.verified_rounded;
    } else if (s.contains('progress')) {
      message = 'Work is actively in progress on your complaint.';
      msgIcon = Icons.construction_rounded;
    } else if (s.contains('assigned')) {
      message = 'An officer has been assigned to your complaint.';
      msgIcon = Icons.person_pin_circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(msgIcon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w600, color: color.withOpacity(0.9), height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ─── Timeline Card ───────────────────────────────────────────────────────────

  Widget _buildTimelineCard() {
    final isClosed = _isClosed();
    final stages = [
      {'label': 'Submitted', 'icon': Icons.send_rounded, 'sub': 'Complaint lodged successfully'},
      {'label': 'Assigned', 'icon': Icons.assignment_ind_rounded, 'sub': 'Officer assigned'},
      {'label': 'In Progress', 'icon': Icons.construction_rounded, 'sub': 'Work underway'},
      {
        'label': isClosed ? 'Closed' : 'Resolved',
        'icon': isClosed ? Icons.task_alt_rounded : Icons.verified_rounded,
        'sub': isClosed ? 'Verified by Dept' : 'Work completed'
      },
    ];

    final current = _currentStepIndex(widget.complaint.status);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.route_rounded, 'Complaint Progress'),
          const SizedBox(height: 20),
          ...List.generate(stages.length, (i) {
            final isCompleted = i < current;
            final isCurrent   = i == current;
            final isLast      = i == stages.length - 1;
            final stage       = stages[i];
            final dotColor    = isCompleted
                ? const Color(0xFF22C55E)
                : isCurrent ? const Color(0xFF7B2FBE) : const Color(0xFFCBD5E1);

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + i * 120),
              curve: Curves.easeOut,
              builder: (_, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 12 * (1 - val)), child: child)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withOpacity(isCompleted || isCurrent ? 1 : 0.15),
                          border: Border.all(color: dotColor, width: isCurrent ? 2.5 : 0),
                          boxShadow: isCurrent ? [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : null,
                        ),
                        child: Icon(stage['icon'] as IconData, size: 16, color: isCompleted || isCurrent ? Colors.white : dotColor),
                      ),
                      if (!isLast)
                        AnimatedContainer(
                          duration: Duration(milliseconds: 600 + i * 100),
                          width: 2, height: 40, margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isCompleted ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage['label'] as String, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500, color: isCompleted || isCurrent ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(stage['sub'] as String, style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Meta Grid ───────────────────────────────────────────────────────────────

  Widget _buildMetaGrid() {
    return Row(
      children: [
        Expanded(child: _metaTile(icon: _categoryIcon(widget.complaint.category), iconColor: const Color(0xFF8B5CF6), bgColor: const Color(0xFFF5F3FF), label: 'Category', value: widget.complaint.category)),
        const SizedBox(width: 12),
        Expanded(child: _metaTile(icon: Icons.calendar_month_rounded, iconColor: const Color(0xFF0EA5E9), bgColor: const Color(0xFFF0F9FF), label: 'Filed On', value: DateFormat('dd MMM yyyy').format(widget.complaint.date))),
      ],
    );
  }

  Widget _metaTile({required IconData icon, required Color iconColor, required Color bgColor, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Assigned Office Card ──────────────────────────────────────────────────

  Widget _buildAssignedOfficeCard() {
    final sectionId = widget.complaint.sectionId.isEmpty ? '—' : widget.complaint.sectionId;
    final assignedTo = widget.complaint.assignedTo.isEmpty ? '—' : widget.complaint.assignedTo;
    final officeLat = widget.complaint.officeLat?.toStringAsFixed(5) ?? '—';
    final officeLon = widget.complaint.officeLon?.toStringAsFixed(5) ?? '—';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.business_rounded, 'Assigned Office Details'),
          const SizedBox(height: 16),

          _officeDetailRow(
            icon: Icons.tag_rounded,
            label: 'Section ID',
            value: sectionId,
            color: const Color(0xFF7B2FBE),
          ),
          const SizedBox(height: 12),
          _officeDetailRow(
            icon: Icons.alternate_email_rounded,
            label: 'Assigned Official (AE)',
            value: assignedTo,
            color: const Color(0xFF3B82F6),
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office Coordinates',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lat: $officeLat\nLon: $officeLon',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              IntrinsicWidth(
                child: ElevatedButton.icon(
                  onPressed: _openOfficeInGoogleMaps,
                  icon: const Icon(Icons.navigation_rounded, size: 14),
                  label: Text(
                    'Navigate',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FBE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _officeDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Description Card ─────────────────────────────────────────────────────────

  Widget _buildDescriptionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.notes_rounded, 'Description'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.complaint.description, style: GoogleFonts.nunito(fontSize: 14.5, color: const Color(0xFF334155), height: 1.7, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location Card ────────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    final lat = widget.complaint.latitude?.toStringAsFixed(5) ?? '—';
    final lon = widget.complaint.longitude?.toStringAsFixed(5) ?? '—';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.map_outlined, 'Location'),
          const SizedBox(height: 14),
          Container(
            height: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(
              children: [
                CustomPaint(size: const Size(double.infinity, 120), painter: _GridPainter()),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.4), blurRadius: 12, spreadRadius: 3)]), child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20)),
                      const SizedBox(height: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)]), child: Text('Complaint Location', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _coordTile(Icons.north_east_rounded, 'Latitude', lat, const Color(0xFF8B5CF6))),
              const SizedBox(width: 10),
              Expanded(child: _coordTile(Icons.east_rounded, 'Longitude', lon, const Color(0xFF0EA5E9))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coordTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.nunito(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Image & Proof Cards ──────────────────────────────────────────────────────

  Widget _buildImageCard(String title, String imageUrl, String tag) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.photo_library_outlined, title),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openFullscreenImage(imageUrl, tag),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Hero(
                    tag: imageUrl,
                    child: Image.network(
                      imageUrl, fit: BoxFit.cover, width: double.infinity, height: 200,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: const Color(0xFFF1F5F9), child: const Center(child: Icon(Icons.broken_image_outlined, color: Color(0xFFCBD5E1), size: 40))),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(tag, style: GoogleFonts.nunito(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
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

  Widget _buildProofCard() {
    final proofUrl = widget.complaint.proofImage;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.verified, color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 12),
              Text('Resolution Proof', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF14532D))),
            ],
          ),
          const SizedBox(height: 16),

          if (widget.complaint.resolutionNote.isNotEmpty) ...[
            Text('Action Taken:', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF166534))),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: Text(widget.complaint.resolutionNote, style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF1F2937))),
            ),
            const SizedBox(height: 16),
          ],

          if (proofUrl.isNotEmpty && proofUrl != 'placeholder_image_url') ...[
            Text('Work Evidence:', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF166534))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openFullscreenImage(proofUrl, 'Resolution Proof'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: proofUrl,
                  child: Image.network(
                    proofUrl, fit: BoxFit.cover, width: double.infinity, height: 180,
                    errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.white, child: const Center(child: Icon(Icons.broken_image_outlined, color: Color(0xFFCBD5E1)))),
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  // ─── Feedback Card ────────────────────────────────────────────────────────────

  Widget _buildFeedbackCard() {
    final rating = (widget.complaint.rating ?? 0).toInt().clamp(0, 5);
    final messages = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];
    final colors = [Colors.transparent, const Color(0xFFEF4444), const Color(0xFFF97316), const Color(0xFFF59E0B), const Color(0xFF22C55E), const Color(0xFF10B981)];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.reviews_outlined, 'Your Feedback'),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < rating;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: filled ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0), size: 36),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: (rating > 0 ? colors[rating] : const Color(0xFF94A3B8)).withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: (rating > 0 ? colors[rating] : const Color(0xFF94A3B8)).withOpacity(0.3))),
                  child: Text(rating > 0 ? messages[rating] : 'No rating', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: rating > 0 ? colors[rating] : const Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared UI Card ──────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]),
      child: child,
    );
  }

  // ─── Section Header ──────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(10)
            ),
            child: Icon(icon, color: const Color(0xFF7B2FBE), size: 18)
        ),
        const SizedBox(width: 12),
        Text(
            title,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A)
            )
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasProof = widget.complaint.proofImage.isNotEmpty && widget.complaint.proofImage != 'placeholder_image_url';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverHeader(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusBanner(),
                    const SizedBox(height: 20),
                    _buildTimelineCard(),
                    const SizedBox(height: 20),
                    _buildMetaGrid(),
                    const SizedBox(height: 20),
                    _buildDescriptionCard(),
                    const SizedBox(height: 20),
                    _buildLocationCard(),
                    const SizedBox(height: 20),
                    _buildAssignedOfficeCard(),

                    if (widget.complaint.imageUrl != null && widget.complaint.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildImageCard('Attached Photo', widget.complaint.imageUrl!, 'Attached Photo'),
                    ],

                    if (hasProof) ...[
                      const SizedBox(height: 20),
                      _buildProofCard(),
                    ],

                    if ((widget.complaint.rating ?? 0) > 0) ...[
                      const SizedBox(height: 20),
                      _buildFeedbackCard(),
                    ] else if (_isResolvedOrClosed()) ...[
                      const SizedBox(height: 20),
                      _buildFeedbackCTA(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared UI Helpers ───────────────────────────────────────────────────────

  bool _isResolvedOrClosed() {
    final s = widget.complaint.status.toLowerCase();
    return s.contains('resolved') || s.contains('closed') || s.contains('finished') || s.contains('completed');
  }

  bool _isClosed() {
    final s = widget.complaint.status.toLowerCase();
    return s.contains('closed') || s.contains('finished');
  }

  Widget _buildFeedbackCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7B2FBE).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How was the resolution?', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 3),
                Text('Share your experience with us', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFeedbackSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text('Rate Now', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF4A1680))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF4A1680),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.18),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.18),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, size: 18, color: Colors.white),
              tooltip: 'Share Complaint',
              onPressed: () {
                HapticFeedback.lightImpact();
                Share.share(
                  'Complaint ID: ${widget.complaint.complaintId}\n'
                      'Title: ${widget.complaint.title}\n'
                      'Status: ${widget.complaint.status}\n'
                      'Filed on: ${DateFormat('dd MMM yyyy').format(widget.complaint.date)}',
                  subject: 'My Complaint Status — ${widget.complaint.complaintId}',
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.18),
            child: IconButton(
              icon: const Icon(Icons.message_outlined, size: 18, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      complaintId: widget.complaint.complaintId,
                      complaintTitle: widget.complaint.title,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7B2FBE), Color(0xFF4A1680), Color(0xFF2D0E5E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -30, right: -40, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
              Positioned(bottom: 20, right: 50, child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB06AFF).withOpacity(0.2)))),
              Positioned(top: 60, left: -20, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.3))),
                        child: Icon(_categoryIcon(widget.complaint.category), color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 14),
                      Text(widget.complaint.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _headerChip(icon: Icons.circle, label: widget.complaint.status.replaceAll('_', ' '), color: _statusColor(widget.complaint.status)),
                          const SizedBox(width: 8),
                          _headerChip(icon: _priorityIcon(widget.complaint.priority), label: widget.complaint.priority.toUpperCase(), color: _priorityColor(widget.complaint.priority)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.45))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.45)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 24) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_GridPainter _) => false;
}