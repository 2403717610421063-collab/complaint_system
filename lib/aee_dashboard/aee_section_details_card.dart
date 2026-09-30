import 'package:complaint_system/aee_dashboard/section_details_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AeeSectionDetailsCard extends StatefulWidget {
  final String sectionId;

  const AeeSectionDetailsCard({
    super.key,
    required this.sectionId,
  });

  @override
  State<AeeSectionDetailsCard> createState() => _AeeSectionDetailsCardState();
}

class _AeeSectionDetailsCardState extends State<AeeSectionDetailsCard> {
  final SectionDetailsService _service = SectionDetailsService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SectionDetailsModel?>(
      future: _service.getSectionById(widget.sectionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorCard();
        }

        final section = snapshot.data!;
        return _buildDetailsCard(section);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D8FD)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF7B1FA2)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Section ID "${widget.sectionId}" not found',
              style: GoogleFonts.nunito(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(SectionDetailsModel section) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E8FF), Color(0xFFFAF5FF)],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFF7B1FA2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AEE Section Details',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7B1FA2),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Section Name (Large)
          Text(
            section.sectionName,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E0A3C),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Section ID: ${section.sectionId}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7B1FA2),
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Grid - Region & Division
          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  icon: Icons.public_rounded,
                  label: 'Region',
                  value: section.regionName,
                  subvalue: 'ID: ${section.regionId}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoBox(
                  icon: Icons.account_balance_rounded,
                  label: 'Division',
                  value: section.divisionName,
                  subvalue: 'ID: ${section.divisionId}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _InfoBox(
                  icon: Icons.domain_rounded,
                  label: 'Circle',
                  value: section.circleName,
                  subvalue: 'ID: ${section.circleId}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoBox(
                  icon: Icons.layers_rounded,
                  label: 'Subdivision',
                  value: section.subdivisionName,
                  subvalue: 'ID: ${section.subdivisionId}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // AE Assignment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE9D8FD), width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF4F46E5),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned AE Officer',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Office Location
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE9D8FD), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Office Location',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CoordBox(
                      label: 'Latitude',
                      value: '${section.officeLat.toStringAsFixed(4)}°',
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFFE9D8FD),
                    ),
                    _CoordBox(
                      label: 'Longitude',
                      value: '${section.officeLon.toStringAsFixed(4)}°',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subvalue;

  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.subvalue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9D8FD), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF7B1FA2)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subvalue,
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordBox extends StatelessWidget {
  final String label;
  final String value;

  const _CoordBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E0A3C),
            ),
          ),
        ],
      ),
    );
  }
}