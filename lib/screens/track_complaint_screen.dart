import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:complaint_system/models/complaint_model.dart';
import 'package:complaint_system/screens/complaint_detail_screen.dart';
import '../services/app_localizations.dart';

class TrackComplaintScreen extends StatefulWidget {
  const TrackComplaintScreen({super.key});

  @override
  State<TrackComplaintScreen> createState() => _TrackComplaintScreenState();
}

class _TrackComplaintScreenState extends State<TrackComplaintScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isSearching = false;

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg          = Color(0xFFF3F0FA);

  Future<void> _searchComplaint() async {
    final searchId = _idController.text.trim();
    if (searchId.isEmpty) {
      _snack(AppLocalizations.of(context)?.translate('enter_complaint_id_hint') ?? 'Please enter a Complaint ID', isError: true);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('complaints')
          .doc(searchId)
          .get();

      if (doc.exists) {
        final complaint =
        Complaint.fromFirestore(doc.data() as Map<String, dynamic>);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailsPage(complaint: complaint),
            ),
          );
        }
      } else {
        _snack(AppLocalizations.of(context)?.translate('no_complaint_found') ?? 'No complaint found with this ID', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: isError ? const Color(0xFFEF4444) : _purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── PAGE TITLE ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple, _purpleDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.track_changes_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)?.translate('track_complaint') ?? 'Track Complaint',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E0A3C),
                      )),
                  Text(AppLocalizations.of(context)?.translate('track_complaint_subtitle') ?? 'Check the latest status of your complaint',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── MAIN CARD ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A1680).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pulse icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _purple.withOpacity(0.15),
                        _purpleDark.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: _purpleBorder, width: 2),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: _purple, size: 36),
                ),

                const SizedBox(height: 18),

                Text(AppLocalizations.of(context)?.translate('enter_complaint_id') ?? 'Enter Complaint ID',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E0A3C),
                    )),

                const SizedBox(height: 6),

                Text(
                  AppLocalizations.of(context)?.translate('complaint_id_desc') ?? 'Paste or type the ID you received\nwhen filing your complaint.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                // ── INPUT FIELD ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _purpleBorder, width: 1.5),
                  ),
                  child: TextField(
                    controller: _idController,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E0A3C),
                    ),
                    onSubmitted: (_) => _isSearching ? null : _searchComplaint(),
                    decoration: InputDecoration(
                      hintText: 'e.g. C-ABC123XYZ',
                      hintStyle: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFFB0A8C8),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _purpleLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tag_rounded,
                            color: _purple, size: 16),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── TRACK BUTTON ────────────────────────────────────────────
                GestureDetector(
                  onTap: _isSearching ? null : _searchComplaint,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: _isSearching
                          ? LinearGradient(colors: [
                        _purple.withOpacity(0.6),
                        _purpleDark.withOpacity(0.6),
                      ])
                          : const LinearGradient(
                        colors: [_purple, _purpleDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isSearching
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
                      child: _isSearching
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.of(context)
                                ?.translate('track') ??
                                'Track Complaint',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── INFO TILES ────────────────────────────────────────────────────
          _infoTile(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF0EA5E9),
            bg: const Color(0xFFE0F2FE),
            title: AppLocalizations.of(context)?.translate('where_to_find_id') ?? 'Where to find your ID?',
            body: AppLocalizations.of(context)?.translate('complaint_id_info') ?? 'Your Complaint ID was shown on screen and sent to your registered contact after filing.',
          ),
          const SizedBox(height: 12),
          _infoTile(
            icon: Icons.lock_clock_rounded,
            color: const Color(0xFFF59E0B),
            bg: const Color(0xFFFFFBEB),
            title: AppLocalizations.of(context)?.translate('realtime_updates') ?? 'Real-time updates',
            body: AppLocalizations.of(context)?.translate('realtime_updates_desc') ?? 'Status is updated live as officials review and resolve your complaint.',
          ),
        ],
      ),
    );
  }

  // ─── Info Tile ────────────────────────────────────────────────────────────────

  Widget _infoTile({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E0A3C),
                    )),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}