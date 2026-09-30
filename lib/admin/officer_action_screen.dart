import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:complaint_system/services/officer_management_service.dart';

class OfficerActionScreen extends StatefulWidget {
  final Map<String, dynamic> officer;
  final String action; // 'delete', 'role', 'jurisdiction'
  final VoidCallback onComplete;

  const OfficerActionScreen({
    super.key,
    required this.officer,
    required this.action,
    required this.onComplete,
  });

  @override
  State<OfficerActionScreen> createState() => _OfficerActionScreenState();
}

class _OfficerActionScreenState extends State<OfficerActionScreen> {
  static const _purple = Color(0xFF7B2FBE);
  static const _purpleLight = Color(0xFFF3E8FF);

  bool _loading = false;
  String? _selectedReplacementId;
  String? _selectedNewRole;
  String? _selectedNewJurisdiction;
  List<Map<String, dynamic>> _availableReplacements = [];
  List<String> _availableRoles = ['AE', 'AEE', 'EE'];
  List<String> _availableJurisdictions = [];
  Map<String, dynamic> _tnebData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      _tnebData = await OfficerManagementService.loadTNEBMasterData();

      if (widget.action == 'delete' || widget.action == 'role') {
        final officers = await OfficerManagementService.getOfficersAtLevel(
          role: widget.officer['officialRole'],
          jurisdiction: _getJurisdictionValue(),
        );
        _availableReplacements = officers
            .where((o) => o['uid'] != widget.officer['uid'])
            .toList();
      } else if (widget.action == 'jurisdiction') {
        _loadAvailableJurisdictions();
      }
    } catch (e) {
      _showError('Error loading data: $e');
    }

    setState(() => _loading = false);
  }

  String _getJurisdictionValue() {
    final role = widget.officer['officialRole'];
    if (role == 'AE') return widget.officer['section'] ?? '';
    if (role == 'AEE') return widget.officer['subdivision'] ?? '';
    if (role == 'EE') return widget.officer['division'] ?? '';
    return '';
  }

  void _loadAvailableJurisdictions() {
    final role = widget.officer['officialRole'];
    final current = _getJurisdictionValue();

    if (role == 'AE') {
      // Get subdivisions for current division, then all sections
      final division = widget.officer['division'];
      if (_tnebData.containsKey(division)) {
        final subs = _tnebData[division] as Map<String, dynamic>;
        _availableJurisdictions = [];
        subs.forEach((sub, sections) {
          _availableJurisdictions.addAll(List<String>.from(sections));
        });
      }
    } else if (role == 'AEE') {
      // Get all subdivisions in current division
      final division = widget.officer['division'];
      if (_tnebData.containsKey(division)) {
        _availableJurisdictions =
            ((_tnebData[division] as Map).keys.toList()).cast<String>();
      }
    } else if (role == 'EE') {
      // Get all divisions
      _availableJurisdictions = (_tnebData.keys.toList()).cast<String>();
    }

    _availableJurisdictions.removeWhere((j) => j == current);
  }

  Future<void> _executeAction() async {
    if (_availableReplacements.isEmpty && 
        (widget.action == 'delete' || widget.action == 'role')) {
      _showError('No other officers available at this level');
      return;
    }

    if ((widget.action == 'delete' || widget.action == 'role') &&
        _selectedReplacementId == null) {
      _showError('Please select a replacement officer');
      return;
    }

    if (widget.action == 'jurisdiction' && _selectedNewJurisdiction == null) {
      _showError('Please select a new jurisdiction');
      return;
    }

    setState(() => _loading = true);

    try {
      if (widget.action == 'delete') {
        await _handleDelete();
      } else if (widget.action == 'role') {
        await _handleRoleChange();
      } else if (widget.action == 'jurisdiction') {
        await _handleJurisdictionChange();
      }

      if (!mounted) return;
      _showSuccess('Officer updated successfully');
      Navigator.pop(context);
      widget.onComplete();
    } catch (e) {
      _showError('Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleDelete() async {
    // Reassign complaints
    await OfficerManagementService.reassignComplaints(
      fromOfficerId: widget.officer['uid'],
      toOfficerId: _selectedReplacementId!,
    );

    // Delete officer
    await OfficerManagementService.deleteOfficer(widget.officer['uid']);
  }

  Future<void> _handleRoleChange() async {
    // Reassign complaints
    await OfficerManagementService.reassignComplaints(
      fromOfficerId: widget.officer['uid'],
      toOfficerId: _selectedReplacementId!,
    );

    // Update role
    await OfficerManagementService.updateOfficerRole(
      officerId: widget.officer['uid'],
      newRole: _selectedNewRole!,
    );
  }

  Future<void> _handleJurisdictionChange() async {
    // Reassign complaints
    await OfficerManagementService.reassignComplaints(
      fromOfficerId: widget.officer['uid'],
      toOfficerId: _selectedReplacementId!,
    );

    // Update jurisdiction
    await OfficerManagementService.updateOfficerJurisdiction(
      officerId: widget.officer['uid'],
      role: widget.officer['officialRole'],
      newJurisdiction: _selectedNewJurisdiction!,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getActionTitle(),
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _purple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfficerInfo(),
                  const SizedBox(height: 24),
                  _buildActionContent(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  String _getActionTitle() {
    if (widget.action == 'delete') return 'Delete Officer';
    if (widget.action == 'role') return 'Change Role';
    return 'Change Jurisdiction';
  }

  Widget _buildOfficerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purpleLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Officer Details',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _purple,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow('Name', widget.officer['name'] ?? 'N/A'),
          _infoRow('Email', widget.officer['email'] ?? 'N/A'),
          _infoRow('Role', widget.officer['officialRole'] ?? 'N/A'),
          _infoRow('Officer No.', widget.officer['officerNumber'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E0A3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionContent() {
    if (widget.action == 'delete') {
      return _buildDeleteContent();
    } else if (widget.action == 'role') {
      return _buildRoleChangeContent();
    } else {
      return _buildJurisdictionChangeContent();
    }
  }

  Widget _buildDeleteContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Warning: Delete Officer',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            'This officer will be permanently deleted. All in_progress complaints will be reassigned to the selected replacement officer.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: const Color(0xFF7F1D1D),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildReplacementSelector(),
      ],
    );
  }

  Widget _buildRoleChangeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Change Officer Role',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E0A3C),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Current Role: ${widget.officer['officialRole']}',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'New Role',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E0A3C),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedNewRole,
          items: _availableRoles
              .where((r) => r != widget.officer['officialRole'])
              .map((role) => DropdownMenuItem(value: role, child: Text(role)))
              .toList(),
          onChanged: (value) => setState(() => _selectedNewRole = value),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildReplacementSelector(),
      ],
    );
  }

  Widget _buildJurisdictionChangeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Change Jurisdiction',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E0A3C),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Current: ${_getJurisdictionValue()}',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'New Jurisdiction',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E0A3C),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedNewJurisdiction,
          items: _availableJurisdictions
              .map((j) => DropdownMenuItem(value: j, child: Text(j)))
              .toList(),
          onChanged: (value) => setState(() => _selectedNewJurisdiction = value),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // For jurisdiction change, we also need replacement
        if (_availableReplacements.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Cannot change jurisdiction: no other officers available at this level',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ] else ...[
          _buildReplacementSelector(),
        ]
      ],
    );
  }

  Widget _buildReplacementSelector() {
    if (_availableReplacements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Text(
          'No replacement officers available at this level',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Colors.red,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reassign Complaints To',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E0A3C),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedReplacementId,
          items: _availableReplacements
              .map<DropdownMenuItem<String>>((officer) => DropdownMenuItem(
                    value: officer['uid'] as String,
                    child: Text(officer['name'] ?? 'Unknown'),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedReplacementId = value),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _loading || _availableReplacements.isEmpty
                ? null
                : _executeAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _getActionTitle(),
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
