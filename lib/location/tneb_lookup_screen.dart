import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_localizations.dart';
import 'package:complaint_system/location/TNEBLocationService.dart';
import 'map_picker_screen.dart';

class TNEBLookupScreen extends StatefulWidget {
  const TNEBLookupScreen({super.key});

  @override
  State<TNEBLookupScreen> createState() => _TNEBLookupScreenState();
}

class _TNEBLookupScreenState extends State<TNEBLookupScreen> {
  final _registerNumController = TextEditingController();

  bool _isLoading = false;
  String _status = '';
  String _activeMethod = ''; // 'register' | 'gps' | 'map'
  Map<String, dynamic>? _resultData;

  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple = Color(0xFF7B2FBE);
  static const _purpleDark = Color(0xFF4A1680);
  static const _purpleDeep = Color(0xFF2D0E5E);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg = Color(0xFFF3F0FA);

  @override
  void dispose() {
    _registerNumController.dispose();
    super.dispose();
  }

  // ─── Method 1: Firebase ───────────────────────────────────────────────────────

  Future<void> _fetchFromFirebase() async {
    final regNum = _registerNumController.text.trim();
    if (regNum.isEmpty) {
      _snack(
          AppLocalizations.of(context)?.translate('enter_reg_num') ??
              'Please enter a Register Number',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _activeMethod = 'register';
      _status = AppLocalizations.of(context)?.translate('searching_db') ??
          'Searching database...';
      _resultData = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(regNum)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Robust parsing: Handles Strings, Ints, and Doubles safely
        double lat = double.tryParse(data['lat']?.toString() ?? '0.0') ?? 0.0;
        double lng = double.tryParse(data['lon']?.toString() ?? '0.0') ?? 0.0;

        // Failsafe if data is missing or returning 0.0 (Null Island)
        if (lat == 0.0 && lng == 0.0) {
          setState(() => _status = 'Error: Coordinates missing or invalid in database.');
          return;
        }

        await _processLocation(lat, lng);
      } else {
        setState(() => _status = 'Register number not found in database.');
      }
    } catch (e) {
      setState(() => _status = 'Database Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Method 2: GPS ───────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _activeMethod = 'gps';
      _status = AppLocalizations.of(context)?.translate('gps_acquiring') ??
          'Acquiring GPS signal...';
      _resultData = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permissions denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await _processLocation(pos.latitude, pos.longitude);
    } catch (e) {
      setState(() => _status = 'GPS Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Method 3: Map picker ─────────────────────────────────────────────────────

  Future<void> _pickFromMap() async {
    final LatLng? loc = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (loc != null) {
      setState(() {
        _isLoading = true;
        _activeMethod = 'map';
        _status = AppLocalizations.of(context)?.translate('map_processing') ??
            'Processing map selection...';
        _resultData = null;
      });
      await _processLocation(loc.latitude, loc.longitude);
      setState(() => _isLoading = false);
    }
  }

  // ─── Core logic ──────────────────────────────────────────────────────────────

  Future<void> _processLocation(double lat, double lng) async {
    // DEBUG PRINT: Check your console! If this says California or 0.0, that's why it fails.
    print('DEBUG: Scanning boundaries for Lat: $lat, Lng: $lng');

    setState(() =>
    _status = AppLocalizations.of(context)?.translate('tneb_scanning') ??
        'Scanning TNEB boundaries...');
    try {
      final geoData =
      await rootBundle.loadString('assets/TNEB_Master_Data.json');
      final result = TNEBLocationService().findBoundary(lat, lng, geoData);

      setState(() {
        _resultData = result;
        _status = result != null
            ? (AppLocalizations.of(context)?.translate('match_found') ??
            'Match Found!')
            : 'Outside mapped TNEB areas.';
      });
    } catch (e) {
      setState(() => _status = 'Processing Error: $e');
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
          Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: isError ? const Color(0xFFEF4444) : _purple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ── METHOD 1: REGISTER ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildRegisterCard(),
            ),
          ),

          // ── DIVIDER ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(children: [
                const Expanded(child: Divider(color: Color(0xFFE9D8FD))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                      AppLocalizations.of(context)?.translate('or') ?? 'or',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB0A8C8),
                      )),
                ),
                const Expanded(child: Divider(color: Color(0xFFE9D8FD))),
              ]),
            ),
          ),

          // ── METHOD 2 & 3 ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _buildLocationMethodsCard(),
            ),
          ),

          // ── STATUS / RESULT ───────────────────────────────────────────────────
          if (_isLoading || _status.isNotEmpty || _resultData != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _buildStatusResult(),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
            top: -20,
            right: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 80,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB06AFF).withOpacity(0.18)),
            ),
          ),
          Positioned(
            top: 50,
            left: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
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
                                  const Icon(Icons.electric_bolt_rounded,
                                      color: Colors.white70, size: 13),
                                  const SizedBox(width: 5),
                                  Text('TNEB',
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
                            Text(
                                AppLocalizations.of(context)
                                    ?.translate('tneb_section_lookup') ??
                                    'Section Lookup',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                )),
                            const SizedBox(height: 5),
                            Text(
                                AppLocalizations.of(context)
                                    ?.translate('find_tneb_section') ??
                                    'Find your TNEB section & subdivision',
                                style: GoogleFonts.nunito(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 28),
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

  // ─── Register Card ────────────────────────────────────────────────────────────

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purpleLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.badge_outlined, color: _purple, size: 17),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppLocalizations.of(context)
                      ?.translate('register_number') ??
                      'Register Number',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  )),
              Text(
                  AppLocalizations.of(context)
                      ?.translate('lookup_via_service_num') ??
                      'Lookup via service / consumer number',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  )),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _purpleBorder, width: 1.5),
                ),
                child: TextField(
                  controller: _registerNumController,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E0A3C),
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)
                        ?.translate('enter_reg_hint') ??
                        'Enter Register / Service No.',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFFB0A8C8),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(Icons.numbers_rounded,
                        color: _purple, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isLoading ? null : _fetchFromFirebase,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: _isLoading && _activeMethod == 'register'
                      ? const LinearGradient(
                      colors: [Color(0xFFB06AFF), _purpleDark])
                      : const LinearGradient(
                    colors: [_purple, _purpleDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading && _activeMethod == 'register'
                    ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                )
                    : const Icon(Icons.search_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── Location Methods Card ────────────────────────────────────────────────────

  Widget _buildLocationMethodsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purpleLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place_rounded, color: _purple, size: 17),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  AppLocalizations.of(context)
                      ?.translate('direct_location') ??
                      'Direct Location',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  )),
              Text(
                  AppLocalizations.of(context)?.translate('gps_or_map') ??
                      'Use GPS or pick a point on the map',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  )),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _locationMethodButton(
                  icon: Icons.my_location_rounded,
                  label: AppLocalizations.of(context)?.translate('use_gps') ??
                      'Use GPS',
                  subLabel:
                  AppLocalizations.of(context)?.translate('auto_detect') ??
                      'Auto-detect',
                  color: const Color(0xFF22C55E),
                  bg: const Color(0xFFF0FDF4),
                  loading: _isLoading && _activeMethod == 'gps',
                  onTap: _isLoading ? null : _getCurrentLocation,
                )),
            const SizedBox(width: 12),
            Expanded(
                child: _locationMethodButton(
                  icon: Icons.map_rounded,
                  label: AppLocalizations.of(context)?.translate('open_map') ??
                      'Open Map',
                  subLabel:
                  AppLocalizations.of(context)?.translate('pick_manually') ??
                      'Pick manually',
                  color: const Color(0xFF0EA5E9),
                  bg: const Color(0xFFE0F2FE),
                  loading: _isLoading && _activeMethod == 'map',
                  onTap: _isLoading ? null : _pickFromMap,
                )),
          ]),
        ],
      ),
    );
  }

  Widget _locationMethodButton({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required Color bg,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: loading ? color.withOpacity(0.15) : bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            loading
                ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
                : Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
              Text(subLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.7),
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Status / Result ──────────────────────────────────────────────────────────

  Widget _buildStatusResult() {
    final bool isSuccess = _resultData != null;
    final bool isError = !_isLoading &&
        _status.isNotEmpty &&
        !isSuccess &&
        (_status.contains('Error') ||
            _status.contains('denied') ||
            _status.contains('outside') ||
            _status.contains('not found'));

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Column(children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(_purple),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 14),
          Text(_status,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              )),
        ]),
      );
    }

    if (isSuccess) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A1680).withOpacity(0.09),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_purple, _purpleDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      AppLocalizations.of(context)
                          ?.translate('match_found') ??
                          'Match Found!',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(
                      AppLocalizations.of(context)
                          ?.translate('tneb_section_details') ??
                          'TNEB section details below',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _resultRow(
                    Icons.electrical_services_rounded,
                    AppLocalizations.of(context)?.translate('section') ??
                        'Section',
                    _resultData!['section_na']),
                _resultRow(
                    Icons.qr_code_rounded,
                    AppLocalizations.of(context)?.translate('code') ?? 'Code',
                    _resultData!['ssmaecode']),
                _resultRow(
                    Icons.account_tree_outlined,
                    AppLocalizations.of(context)?.translate('subdivision') ??
                        'Subdivision',
                    _resultData!['subdivisio']),
                _resultRow(
                    Icons.circle_outlined,
                    AppLocalizations.of(context)?.translate('circle') ??
                        'Circle',
                    _resultData!['circle_nam'],
                    isLast: true),
              ]),
            ),
          ],
        ),
      );
    }

    if (_status.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isError ? const Color(0xFFFECACA) : _purpleBorder,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFEF4444).withOpacity(0.1)
                  : _purpleLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: isError ? const Color(0xFFEF4444) : _purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(_status,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF64748B),
                  height: 1.4,
                )),
          ),
        ]),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _resultRow(IconData icon, String label, dynamic value,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
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
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              Text(
                '${value ?? 'N/A'}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF1EDF9)),
      ],
    );
  }
}