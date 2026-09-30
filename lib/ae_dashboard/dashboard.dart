import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../aee_dashboard/section_details_service.dart';

class AeSectionDashboardScreen extends StatefulWidget {
  const AeSectionDashboardScreen({super.key});

  @override
  State<AeSectionDashboardScreen> createState() =>
      _AeSectionDashboardScreenState();
}

class _AeSectionDashboardScreenState extends State<AeSectionDashboardScreen> {
  final SectionDetailsService _service = SectionDetailsService();
  String? _userSectionId;
  bool _loadingUser = true;
  Map<String, dynamic>? _aeDetails;

  static const _purple = Color(0xFF7B1FA2);
  static const _purpleDark = Color(0xFF4A148C);
  static const _purpleDeep = Color(0xFF2D0060);
  static const _purpleLight = Color(0xFFF3E8FF);

  @override
  void initState() {
    super.initState();
    _loadUserSectionId();
  }

  Future<void> _loadUserSectionId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final sectionId = (userData?['section_id'] ?? '').toString().trim();

        // Load AE details
        _aeDetails = {
          'name': userData?['name'] ?? 'N/A',
          'email': userData?['email'] ?? 'N/A',
          'role': userData?['role'] ?? 'AE',
          'employeeId': userData?['employee_id'] ?? 'N/A',
          'phone': userData?['phone'] ?? 'N/A',
        };

        if (mounted) {
          setState(() {
            _userSectionId = sectionId;
            _loadingUser = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingUser = false);
      }
    } catch (e) {
      print('Error loading user section: $e');
      if (mounted) setState(() => _loadingUser = false);
    }
  }
  Future<void> _openGoogleMaps(double lat, double lon) async {
    final Uri url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open Google Maps';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_purple, _purpleDark, _purpleDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AE Section Dashboard',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Assistant Engineer Details & Section Information',
                                style: GoogleFonts.nunito(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _loadingUser
                  ? const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_purple)),
              )
                  : _userSectionId == null || _userSectionId!.isEmpty
                  ? _buildNoSectionCard()
                  : _buildSectionDetailsCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSectionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFECDD3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFEF4444), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'No Section Assigned',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your profile does not have a section assigned yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDetailsCard() {
    return FutureBuilder<SectionDetailsModel?>(
      future: _service.getSectionById(_userSectionId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_purple)),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 32),
                    const SizedBox(height: 16),
                    Text(
                      'Section Not Found',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Section ID: $_userSectionId',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final section = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AE Details Card (First Priority)
              _buildAeDetailsCard(),

              const SizedBox(height: 20),

              // Section Details Card
              _buildSectionDetails(section),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAeDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_purpleLight, Color(0xFFFAF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D8FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: _purple, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Assistant Engineer Details',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Name', _aeDetails?['name'] ?? 'N/A', Icons.badge_outlined),
          const Divider(height: 16, color: Color(0xFFE9D8FD)),
          _buildDetailRow('Employee ID', _aeDetails?['employeeId'] ?? 'N/A', Icons.numbers_outlined),
          const Divider(height: 16, color: Color(0xFFE9D8FD)),
          _buildDetailRow('Email', _aeDetails?['email'] ?? 'N/A', Icons.email_outlined),
          const Divider(height: 16, color: Color(0xFFE9D8FD)),
          _buildDetailRow('Phone', _aeDetails?['phone'] ?? 'N/A', Icons.phone_outlined),
          const Divider(height: 16, color: Color(0xFFE9D8FD)),
          _buildDetailRow('Role', _aeDetails?['role'] ?? 'AE', Icons.work_outlined),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _purple.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E0A3C),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDetails(SectionDetailsModel section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title Card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_purpleLight, Color(0xFFFAF5FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9D8FD), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B1FA2).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_city_outlined,
                        color: _purple, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.sectionName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E0A3C),
                          ),
                        ),
                        Text(
                          'Section ID: ${section.sectionId}',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Geographic Information
        _buildInfoCard(
          title: '📍 Geographic Information',
          icon: Icons.map_outlined,
          children: [
            _buildInfoRow('Region', section.regionName, 'ID: ${section.regionId}'),
            const Divider(height: 16, color: Color(0xFFE9D8FD)),
            _buildInfoRow('Division', section.divisionName, 'ID: ${section.divisionId}'),
            const Divider(height: 16, color: Color(0xFFE9D8FD)),
            _buildInfoRow('Circle', section.circleName, 'ID: ${section.circleId}'),
            const Divider(height: 16, color: Color(0xFFE9D8FD)),
            _buildInfoRow('Subdivision', section.subdivisionName, 'ID: ${section.subdivisionId}'),
          ],
        ),

        const SizedBox(height: 16),

        // Assigned AE Officer
        _buildInfoCard(
          title: '👤 Assigned AE Officer',
          icon: Icons.engineering_outlined,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Officer ID',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  section.aeId,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E0A3C),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Office Location
        _buildInfoCard(
          title: '📌 Office Location',
          icon: Icons.location_on_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latitude',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${section.officeLat.toStringAsFixed(6)}°',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E0A3C),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE9D8FD),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Longitude',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${section.officeLon.toStringAsFixed(6)}°',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E0A3C),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _openGoogleMaps(section.officeLat, section.officeLon);
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text("Navigate"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D8FD), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E0A3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String subvalue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E0A3C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subvalue,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}