import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turf/turf.dart' as turf;

import '../models/Application.dart';
import '../services/email_service.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';
import '../services/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TNEB LOCATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════
class TNEBLocationService {

  Map<String, dynamic>? findBoundary(
      double lat,
      double lng,
      String geoJsonString,
      ) {
    final Map<String, dynamic> data = json.decode(geoJsonString);
    final featureCollection = turf.FeatureCollection.fromJson(data);

    final userPosition = turf.Position(lng, lat);

    for (final feature in featureCollection.features) {
      final properties = feature.properties ?? <String, dynamic>{};

      final divisionName =
      (properties['division_name'] ?? properties['division_n'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      final geom = feature.geometry;
      if (geom == null) continue;

      if (turf.booleanPointInPolygon(userPosition, geom)) {
        return properties;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkMySection() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final geoData = await rootBundle.loadString('assets/TNEB_Master_Data.json');

      return findBoundary(
        position.latitude,
        position.longitude,
        geoData,
      );
    } catch (e) {
      print("Error finding boundary: $e");
      return null;
    }
  }

  // FIXED: Changed to Map<String, dynamic> to safely hold numbers for lat/lon
  Map<String, dynamic>? extractHierarchy(Map<String, dynamic>? properties) {
    if (properties == null) return null;

    final section = (properties['section_name'] ?? properties['section_na'] ?? '')
        .toString()
        .trim();
    final subdivision =
    (properties['subdivision_name'] ?? properties['subdivisio'] ?? '')
        .toString()
        .trim();
    final division =
    (properties['division_name'] ?? properties['division_n'] ?? '')
        .toString()
        .trim();
    final section_id =
    (properties['section_id'] ?? properties['section_co'] ?? '')
        .toString()
        .trim();

    if (section.isEmpty && subdivision.isEmpty && division.isEmpty) {
      return null;
    }

    return <String, dynamic>{
      'section_id': section_id,
      'aeSection': section,
      'aeeSubdivision': subdivision,
      'eeDivision': division,
      'aeCode': (properties['ssmaecode'] ?? '').toString().trim(),
      'office_lat': properties['office_lat'],
      'office_lon': properties['office_lon']
    };
  }

  Future<Map<String, dynamic>?> getCurrentHierarchy() async {
    final props = await checkMySection();
    return extractHierarchy(props);
  }

  Future<Map<String, dynamic>?> getHierarchyForPoint(
      double latitude,
      double longitude,
      ) async {
    try {
      final geoData = await rootBundle.loadString('assets/TNEB_Master_Data.json');
      final props = findBoundary(latitude, longitude, geoData);
      return extractHierarchy(props);
    } catch (e) {
      print('Error computing hierarchy for point: $e');
      return null;
    }
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// ADD COMPLAINT SCREEN UI
// ═══════════════════════════════════════════════════════════════════════════

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _ebController = TextEditingController();

  File? _image;
  Position? _currentPosition;

  bool _isSubmitting = false;
  bool _isLocating = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ebController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── CLOUDINARY UPLOAD ──────────────────────────────────────────────────────
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

  // ── IMAGE / CAMERA PICKER ──────────────────────────────────────────────────
  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context)?.translate('add_photo') ?? 'Add Photo',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _imageSourceTile(
                    icon: Icons.camera_alt_rounded,
                    label: AppLocalizations.of(context)?.translate('camera') ?? 'Camera',
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _imageSourceTile(
                    icon: Icons.photo_library_rounded,
                    label: AppLocalizations.of(context)?.translate('gallery') ?? 'Gallery',
                    color: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker()
        .pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  // ── GPS LOCATION ───────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = position);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Location Error: $e')));
      }
    }
    setState(() => _isLocating = false);
  }

  // ── LOCATION METHOD CHOOSER ────────────────────────────────────────────────
  Future<void> _chooseLocationMethod() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.translate('select_location_method') ??
                    'Select Location Method',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _locationOption(
                icon: Icons.my_location_rounded,
                color: const Color(0xFF1565C0),
                title: AppLocalizations.of(context)?.translate('capture_location') ??
                    'Use Current Location',
                subtitle: AppLocalizations.of(context)?.translate('use_gps_desc') ??
                    'Get your precise GPS location',
                onTap: () {
                  Navigator.pop(context);
                  _getCurrentLocation();
                },
              ),
              const SizedBox(height: 12),
              _locationOption(
                icon: Icons.map_outlined,
                color: const Color(0xFFE65100),
                title: AppLocalizations.of(context)?.translate('choose_from_map') ??
                    'Choose from Map',
                subtitle: AppLocalizations.of(context)?.translate('map_tap_desc') ??
                    'Pick any location on the map',
                onTap: () async {
                  Navigator.pop(context);
                  final LatLng? picked = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                  );
                  if (picked != null) {
                    setState(() {
                      _currentPosition = Position(
                        latitude: picked.latitude,
                        longitude: picked.longitude,
                        timestamp: DateTime.now(),
                        accuracy: 1,
                        altitude: 0,
                        heading: 0,
                        speed: 0,
                        speedAccuracy: 1,
                        altitudeAccuracy: 1,
                        headingAccuracy: 1,
                      );
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location selected from map!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _locationOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── ROUTING LOGIC: LEAVE CHECKER ───────────────────────────────────────────
  Future<String> _getEffectiveAssignee(String originalOfficerEmail) async {
    try {
      final leaveDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(originalOfficerEmail)
          .get();

      if (leaveDoc.exists) {
        final data = leaveDoc.data()!;
        final status = data['status'] as String?;
        final substitute = data['substituteAssigned'] as String?;

        final startTimestamp = data['startDate'] as Timestamp?;
        final endTimestamp = data['endDate'] as Timestamp?;

        if (status == 'approved' && substitute != null && startTimestamp != null && endTimestamp != null) {
          final now = DateTime.now();
          final startDate = startTimestamp.toDate();
          final endDate = endTimestamp.toDate();

          final todayDate = DateTime(now.year, now.month, now.day);
          final start = DateTime(startDate.year, startDate.month, startDate.day);
          final end = DateTime(endDate.year, endDate.month, endDate.day);

          if (todayDate.compareTo(start) >= 0 && todayDate.compareTo(end) <= 0) {
            debugPrint('Officer $originalOfficerEmail is on leave. Routing to substitute: $substitute');
            return substitute;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking leave status: $e');
    }
    return originalOfficerEmail;
  }

  // ── SUBMIT COMPLAINT ───────────────────────────────────────────────────────
  Future<void> _submitComplaint() async {
    // 1. Initial Validation for Form fields (excluding EB number)
    if (!_formKey.currentState!.validate()) return;

    final ebNumber = _ebController.text.trim();
    final hasEbNumber = ebNumber.isNotEmpty;
    final hasLocation = _currentPosition != null;

    // Check if at least one is provided
    if (!hasEbNumber && !hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide either an EB Service Number OR select a Location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User is not logged in.");

      // 2. Fetch Location from EB Number if provided
      if (hasEbNumber) {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(ebNumber)
            .get();

        if (serviceDoc.exists) {
          final data = serviceDoc.data()!;
          if (data.containsKey('lat') && data.containsKey('log')) {
            // Override the current position with the exact EB service coordinates
            _currentPosition = Position(
              latitude: (data['lat'] as num).toDouble(),
              longitude: (data['log'] as num).toDouble(),
              timestamp: DateTime.now(),
              accuracy: 1,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 1,
              altitudeAccuracy: 1,
              headingAccuracy: 1,
            );
          } else {
            throw Exception("EB Service Number found, but location coordinates are missing in the database.");
          }
        } else {
          throw Exception("Invalid EB Service Number. Please check the number or leave it blank and choose a location manually.");
        }
      }

      // 3. Upload Image (if any)
      String? imageUrl;
      if (_image != null) imageUrl = await _uploadToCloudinary(_image!);

      // 4. Generate Custom ID
      final customId = 'C-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${user.uid.substring(0, 3)}'.toUpperCase();

      // 5. Fetch TNEB Hierarchy FIRST based on location
      Map<String, dynamic>? hierarchy;
      try {
        hierarchy = await TNEBLocationService().getHierarchyForPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      } catch (e) {
        debugPrint('Routing fetch failed: $e');
      }

      // 6. DYNAMICALLY FETCH AE'S EMAIL FROM USERS COLLECTION & CHECK LEAVE
      String assignedEmail = 'unassigned';
      String assignedRole = 'unassigned';
      debugPrint('TNEB Debug - AE Section: ${hierarchy?['aeSection']} | Section ID: ${hierarchy?['section_id']}');

      if (hierarchy != null && hierarchy['aeSection'] != null) {
        try {
          final searchSectionId = hierarchy['section_id'].toString().trim();

          final aeQuery = await FirebaseFirestore.instance
              .collection('Users')
              .where('section_id', isEqualTo: searchSectionId)
              .where('officialRole', isEqualTo: 'AE')
              .limit(1)
              .get();

          if (aeQuery.docs.isNotEmpty) {
            String originalAeEmail = aeQuery.docs.first['email'] ?? 'unassigned';

            if (originalAeEmail != 'unassigned') {
              assignedEmail = await _getEffectiveAssignee(originalAeEmail);
              assignedRole = 'ae';
            }
          }
        } catch (e) {
          debugPrint('Failed to fetch AE email: $e');
        }
      }

      // 7. Prepare all data in a single Map (FIXED CLEANUP)
      final complaintData = <String, dynamic>{
        'complaintId': customId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'ebServiceNumber': ebNumber,
        'userId': user.uid,
        'imageUrl': imageUrl ?? '',
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedTo': assignedEmail,
        'assignedRole': assignedRole,
        'status': 'pending',
      };

      // Safely append hierarchy data if it exists
      if (hierarchy != null) {
        complaintData.addAll({
          'section_id': hierarchy['section_id'],
          'tnebAeSection': hierarchy['aeSection'],
          'tnebAeeSubdivision': hierarchy['aeeSubdivision'],
          'tnebEeDivision': hierarchy['eeDivision'],
          'tnebAeCode': hierarchy['aeCode'],
          'tnebRoutingVersion': 'urban_v1',
          'office_lat': hierarchy['office_lat'],
          'office_lon': hierarchy['office_lon'],
        });
      }

      // 8. Perform a SINGLE write to Firestore
      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(customId)
          .set(complaintData);

      // 9. Send Email Notification
      if (user.email != null && user.email!.isNotEmpty) {
        EmailService().sendStatusEmail(
          user.email!,
          'Complaint Submitted Successfully',
          'Complaint ID: $customId\nStatus: ${complaintData['status']}',
        );
      }

      // 10. Handle Success Navigation
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint Filed Successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: GradientAppBar(
        title: AppLocalizations.of(context)?.translate('new_complaint') ??
            'New Complaint',
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1565C0).withOpacity(0.1), const Color(0xFF42A5F5).withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register a Complaint',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fill in the details below',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Complaint Details Section ──
                _SectionHeader(
                  icon: Icons.info_outline_rounded,
                  title: 'Complaint Details',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _StyledField(
                        controller: _titleController,
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFF1565C0),
                        label: 'Issue Title',
                        hint: 'e.g., Power outage in my area',
                        validator: (v) => v!.isEmpty
                            ? 'Please enter a complaint title'
                            : null,
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _StyledField(
                        controller: _descController,
                        icon: Icons.notes_rounded,
                        iconColor: const Color(0xFF6A1B9A),
                        label: 'Description',
                        hint: 'Describe your issue in detail...',
                        maxLines: 4,
                        alignLabelWithHint: true,
                        validator: (v) => v!.isEmpty
                            ? 'Please enter a description'
                            : null,
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _StyledField(
                        controller: _ebController,
                        icon: Icons.electrical_services_rounded,
                        iconColor: const Color(0xFFE65100),
                        label: 'EB Service Number (Optional)',
                        hint: 'Enter EB number OR provide location below',
                        keyboardType: TextInputType.number,
                        validator: (v) => null, // Optional now
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Location Section ──
                _SectionHeader(
                  icon: Icons.location_on_rounded,
                  title: 'Location Details',
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_isLocating)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Fetching your location...'),
                            ],
                          ),
                        )
                      else if (_currentPosition != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF2E7D32), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location Captured',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
                                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _currentPosition = null),
                                icon: Icon(Icons.edit_rounded, color: Colors.grey.shade600, size: 20),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.location_searching_rounded,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No location selected',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Required if EB Service Number is blank',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _SelectLocationButton(onPressed: _chooseLocationMethod),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Photo Section ──
                _SectionHeader(
                  icon: Icons.camera_alt_rounded,
                  title: 'Photo Attachment',
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _image != null
                        ? _ImagePreview(
                      key: const ValueKey('preview'),
                      image: _image!,
                      onRemove: () => setState(() => _image = null),
                      onReplace: _showImageSourceSheet,
                    )
                        : _PhotoPlaceholder(
                      key: const ValueKey('placeholder'),
                      onTap: _showImageSourceSheet,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Submit Button ──
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : _SubmitButton(onPressed: _submitComplaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? hint;
  final int maxLines;
  final bool alignLabelWithHint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
        alignLabelWithHint: alignLabelWithHint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      validator: validator,
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoPlaceholder({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFBBDEFB),
            width: 2,
            style: BorderStyle.solid,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F7FF), Color(0xFFE8F4FD)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 32, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a Photo',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0)),
            ),
            Text(
              'Camera or Gallery · Optional',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  final VoidCallback onReplace;
  const _ImagePreview({
    super.key,
    required this.image,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(image,
              height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          child: GestureDetector(
            onTap: onReplace,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Replace',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectLocationButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SelectLocationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.location_searching_rounded, size: 20),
        label: Text(
          'Select Location',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1565C0),
          side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SubmitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              'Submit Complaint',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const GradientAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}