import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/complaint_model.dart';
import '../screens/complaint_detail_screen.dart';
import '../services/app_localizations.dart';

class NearbyComplaintsScreen extends StatefulWidget {
  const NearbyComplaintsScreen({super.key});

  @override
  State<NearbyComplaintsScreen> createState() => _NearbyComplaintsScreenState();
}

class _NearbyComplaintsScreenState extends State<NearbyComplaintsScreen>
    with TickerProviderStateMixin {
  double? centerLat;
  double? centerLon;
  String _locationLabel = 'Fetching your location...';
  double _currentRadius = 10;
  bool _loading = true;
  bool _capturingLocation = false;

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _loadUserLocation();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection("Users")
            .doc(uid)
            .get();
        if (doc.exists) {
          final lat = (doc['latitude'] as num?)?.toDouble() ?? 11.0168;
          final lon = (doc['longitude'] as num?)?.toDouble() ?? 76.9558;
          final placemarks = await placemarkFromCoordinates(lat, lon);
          final place = placemarks.isNotEmpty ? placemarks.first : null;
          setState(() {
            centerLat = lat;
            centerLon = lon;
            _locationLabel = place != null
                ? '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                : 'Saved location';
          });
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
    _headerCtrl.forward();
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _capturingLocation = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final place = placemarks.isNotEmpty ? placemarks.first : null;
        setState(() {
          centerLat = pos.latitude;
          centerLon = pos.longitude;
          _locationLabel = place != null
              ? '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
              : 'Current Location';
        });
      }
    } catch (_) {
      setState(() => _locationLabel = 'Could not capture location');
    }
    setState(() => _capturingLocation = false);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('resolved') || s.contains('closed') || s.contains('completed')) {
      return const Color(0xFF22C55E);
    }
    if (s.contains('progress')) return const Color(0xFF3B82F6);
    if (s.contains('assigned')) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
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
    return Icons.report_problem_outlined;
  }

  Color _distanceColor(double km) {
    if (km <= 2) return const Color(0xFF22C55E);
    if (km <= 8) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _distanceLabel(double km) {
    if (km < 1) return "${(km * 1000).round()} m";
    return "${km.toStringAsFixed(1)} km";
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F0FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2FBE).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_searching_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Locating you...',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A1680),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FA),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
        FirebaseFirestore.instance.collection("complaints").snapshots(),
        builder: (context, snapshot) {
          // Compute nearby list
          List<Map<String, dynamic>> nearby = [];
          if (snapshot.hasData) {
            nearby = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final complaint = Complaint.fromFirestore(data);
              double distance = 0;
              if (complaint.latitude != null && centerLat != null) {
                distance = Geolocator.distanceBetween(
                  centerLat!,
                  centerLon!,
                  complaint.latitude!,
                  complaint.longitude!,
                ) /
                    1000;
              }
              return {'complaint': complaint, 'distance': distance};
            })
                .where((c) => (c['distance'] as double) <= _currentRadius)
                .toList();

            nearby.sort((a, b) => (a['distance'] as double)
                .compareTo(b['distance'] as double));
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildHeader(),
                  ),
                ),
              ),

              // ── LOCATION CAPTURE CARD ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildLocationCard(),
                ),
              ),

              // ── RADIUS CONTROL ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _buildRadiusControl(),
                ),
              ),

              // ── COUNT ROW ─────────────────────────────────────────────────
              if (snapshot.hasData)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      children: [
                        Text(
                          '${nearby.length} complaint${nearby.length == 1 ? '' : 's'} found',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4A1680),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7B2FBE),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'within ${_currentRadius.round()} km',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── LOADING INDICATOR ─────────────────────────────────────────
              if (!snapshot.hasData)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation(Color(0xFF7B2FBE)),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )

              // ── EMPTY STATE ───────────────────────────────────────────────
              else if (nearby.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())

              // ── COMPLAINT CARDS ───────────────────────────────────────────
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final item = nearby[index];
                        final c = item['complaint'] as Complaint;
                        final dist = item['distance'] as double;
                        return _ComplaintCard(
                          complaint: c,
                          distance: dist,
                          index: index,
                          statusColor: _statusColor(c.status),
                          categoryIcon: _categoryIcon(c.category),
                          distanceColor: _distanceColor(dist),
                          distanceLabel: _distanceLabel(dist),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ComplaintDetailsPage(complaint: c),
                            ),
                          ),
                        );
                      },
                      childCount: nearby.length,
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B2FBE), Color(0xFF4A1680), Color(0xFF2D0E5E)],
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
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 80,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB06AFF).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -15,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.translate('nearby_complaints') ?? 'Complaints Near You',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.translate('nearby_desc') ?? 'Discover & track civic issues around your area',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PulseLocationBadge(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Location Capture Card ────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    final bool hasLocation = centerLat != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Location icon tile
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: hasLocation
                  ? const Color(0xFFF3E8FF)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: hasLocation
                  ? const Color(0xFF7B2FBE)
                  : const Color(0xFFF97316),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? (AppLocalizations.of(context)?.translate('your_location') ?? 'Your Location') : (AppLocalizations.of(context)?.translate('no_location') ?? 'No Location Set'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _locationLabel,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Capture / Update button
          GestureDetector(
            onTap: _capturingLocation ? null : _captureCurrentLocation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: _capturingLocation
                    ? const LinearGradient(
                  colors: [Color(0xFFB06AFF), Color(0xFF7B2FBE)],
                )
                    : const LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2FBE).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _capturingLocation
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.my_location_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    hasLocation 
                        ? (AppLocalizations.of(context)?.translate('update') ?? 'Update') 
                        : (AppLocalizations.of(context)?.translate('capture') ?? 'Capture'),
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
        ],
      ),
    );
  }

  // ─── Radius Control ───────────────────────────────────────────────────────────

  Widget _buildRadiusControl() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
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
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.social_distance_rounded,
                    color: Color(0xFF7B2FBE), size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)?.translate('search_radius') ?? 'Search Radius',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentRadius.round()} km',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: const Color(0xFF7B2FBE),
              inactiveTrackColor: const Color(0xFFE9D8FD),
              thumbColor: const Color(0xFF7B2FBE),
              overlayColor: const Color(0xFF7B2FBE).withOpacity(0.15),
            ),
            child: Slider(
              value: _currentRadius,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (value) => setState(() => _currentRadius = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['1 km', '10 km', '25 km', '50 km'].map((label) {
                return Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: const Color(0xFFB0A8C8),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                color: Color(0xFF7B2FBE), size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)?.translate('no_complaints') ?? 'No Complaints Nearby',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.translate('no_nearby_desc') ?? 'Try increasing the search radius\nor update your location',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => setState(() => _currentRadius = 25),
            icon: const Icon(Icons.expand_circle_down_outlined,
                color: Color(0xFF7B2FBE), size: 18),
            label: Text(
              AppLocalizations.of(context)?.translate('expand_radius') ?? 'Expand to 25 km',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7B2FBE),
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF3E8FF),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulse Location Badge ─────────────────────────────────────────────────────

class _PulseLocationBadge extends StatefulWidget {
  @override
  State<_PulseLocationBadge> createState() => _PulseLocationBadgeState();
}

class _PulseLocationBadgeState extends State<_PulseLocationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.12),
          border: Border.all(
              color: Colors.white.withOpacity(0.25), width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }
}

// ─── Complaint Card ────────────────────────────────────────────────────────────

class _ComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final double distance;
  final int index;
  final Color statusColor;
  final IconData categoryIcon;
  final Color distanceColor;
  final String distanceLabel;
  final VoidCallback onTap;

  const _ComplaintCard({
    required this.complaint,
    required this.distance,
    required this.index,
    required this.statusColor,
    required this.categoryIcon,
    required this.distanceColor,
    required this.distanceLabel,
    required this.onTap,
  });

  @override
  State<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 50),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
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
                // Top row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FBE), Color(0xFF4A1680)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2FBE).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(widget.categoryIcon,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E0A3C),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.category,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: Color(0xFF7B2FBE)),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF1EDF9)),

                // Bottom row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: widget.statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              c.status.replaceAll('_', ' '),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Distance badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.distanceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: widget.distanceColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded,
                                size: 11, color: widget.distanceColor),
                            const SizedBox(width: 5),
                            Text(
                              widget.distanceLabel,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.distanceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}