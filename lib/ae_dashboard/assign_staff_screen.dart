import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/field_worker_model.dart';
import '../services/complaint_service.dart';
import '../services/status_normalizer.dart';
import '../services/worker_routing_service.dart';

class AssignStaffScreen extends StatefulWidget {
  const AssignStaffScreen({
    super.key,
    required this.complaintId,
    this.sectionId,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final String complaintId;
  final String? sectionId;
  final ComplaintService? _complaintService;

  ComplaintService get complaintService => _complaintService ?? ComplaintService();

  @override
  State<AssignStaffScreen> createState() => _AssignStaffScreenState();
}

class _AssignStaffScreenState extends State<AssignStaffScreen> {
  final WorkerRoutingService _routingService = WorkerRoutingService();

  bool _loadingData = true;
  bool _saving = false;
  String _complaintWard = 'Unknown';
  String _complaintPriority = 'low';
  String _complaintStatus = 'classified';
  String? _errorMessage;

  List<FieldWorkerModel> _eligibleWorkers = const [];
  FieldWorkerModel? _recommendedWorker;

  List<String> _selectedWorkerIds = [];

  @override
  void initState() {
    super.initState();
    _loadRoutingData();
  }

  Future<void> _loadRoutingData() async {
    try {
      // 1. Fetch Complaint Data
      final complaintSnapshot = await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaintId)
          .get();

      if (!complaintSnapshot.exists) {
        throw StateError('Complaint not found.');
      }

      final complaint = complaintSnapshot.data() ?? <String, dynamic>{};
      final targetSectionId = (complaint['section_id'] ?? '').toString().trim();

      if (targetSectionId.isEmpty) {
        throw StateError('Section ID is not available for this complaint.');
      }

      // 2. Fetch Potential Workers in this Section
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('officialRole', isEqualTo: 'Foreman')
          .where('section_id', isEqualTo: targetSectionId)
          .get();

      List<FieldWorkerModel> potentialWorkers = usersSnapshot.docs.map((doc) {
        return FieldWorkerModel.fromDocument(doc);
      }).toList();

      // 3. 🌟 NEW LOGIC: Check for Active Leaves 🌟
      List<FieldWorkerModel> availableWorkers = [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day); // Strip time for accurate day-to-day comparison

      for (var worker in potentialWorkers) {
        // Assume the leave document ID is the worker's email
        final leaveDoc = await FirebaseFirestore.instance
            .collection('leave_requests')
            .doc(worker.email)
            .get();

        bool isOnLeaveToday = false;

        if (leaveDoc.exists) {
          final data = leaveDoc.data()!;
          final status = data['status'] as String?;
          final startTimestamp = data['startDate'] as Timestamp?;
          final endTimestamp = data['endDate'] as Timestamp?;

          if (status == 'approved' && startTimestamp != null && endTimestamp != null) {
            final startDate = startTimestamp.toDate();
            final endDate = endTimestamp.toDate();

            final start = DateTime(startDate.year, startDate.month, startDate.day);
            final end = DateTime(endDate.year, endDate.month, endDate.day);

            // Check if today falls exactly on or between the start and end dates
            if (today.compareTo(start) >= 0 && today.compareTo(end) <= 0) {
              isOnLeaveToday = true;
            }
          }
        }

        // Only add them to the available list if they are NOT on leave today
        if (!isOnLeaveToday) {
          availableWorkers.add(worker);
        }
      }

      // 4. Run routing recommendations ONLY on the available workers
      final recommended = _routingService.recommendWorker(
        eligibleWorkers: availableWorkers,
        complaintPriority: (complaint['priority'] ?? 'low').toString(),
        complaintStatus: (complaint['status'] ?? 'classified').toString(),
      );

      if (!mounted) return;
      setState(() {
        _complaintWard = targetSectionId;
        _complaintPriority = (complaint['priority'] ?? 'low').toString();
        _complaintStatus = normalizeStatus(
          (complaint['status'] ?? 'classified').toString(),
        );
        _eligibleWorkers = availableWorkers; // Use the filtered list!
        _recommendedWorker = recommended;

        if (recommended != null) {
          _selectedWorkerIds = [recommended.id];
        }

        _loadingData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Field Crew')),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Assignment Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text('Complaint Section: $_complaintWard'),
                const SizedBox(height: 6),
                Text('Priority: $_complaintPriority'),
                const SizedBox(height: 6),
                Text('Current Status: $_complaintStatus'),
                const SizedBox(height: 12),

                if (_recommendedWorker != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      '💡 Recommended: ${_recommendedWorker!.name} '
                          '(${_recommendedWorker!.activeJobs}/${_recommendedWorker!.maxJobs} jobs)',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),

                if (_recommendedWorker != null) const SizedBox(height: 16),

                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (_errorMessage != null) const SizedBox(height: 12),

                if (_eligibleWorkers.isNotEmpty) ...[
                  const Text(
                    'Select Field Workers:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _eligibleWorkers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final worker = _eligibleWorkers[index];
                        final isSelected = _selectedWorkerIds.contains(worker.id);

                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('${worker.name} (${worker.role})'),
                          subtitle: Text('Active Jobs: ${worker.activeJobs}/${worker.maxJobs}'),
                          value: isSelected,
                          activeColor: Colors.purple,
                          onChanged: _saving
                              ? null
                              : (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedWorkerIds.add(worker.id);
                              } else {
                                _selectedWorkerIds.remove(worker.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_saving || _eligibleWorkers.isEmpty)
                        ? null
                        : _saveAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Assign Selected (${_selectedWorkerIds.length})', style: const TextStyle(fontSize: 16)),
                  ),
                ),

                // 🌟 Enhanced Empty State Warning 🌟
                if (_eligibleWorkers.isEmpty && _errorMessage == null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                        SizedBox(height: 8),
                        Text(
                          'No available workers',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'All workers in this section are currently on leave.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _markPendingAssignment,
                      icon: const Icon(Icons.schedule_send),
                      label: const Text('Mark Pending Assignment'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one worker to assign.')),
      );
      return;
    }

    setState(() => _saving = true);

    // Extract the models for the selected workers
    final selectedWorkers = _eligibleWorkers
        .where((worker) => _selectedWorkerIds.contains(worker.id))
        .toList();

    // Map them into lists for the backend
    final workerIds = selectedWorkers.map((w) => w.id).toList();
    final workerEmails = selectedWorkers.map((w) => w.email).toList();
    final workerNames = selectedWorkers.map((w) => w.name).toList();
    final workerRoles = selectedWorkers.map((w) => w.role).toList();

    final includesRecommended = _recommendedWorker != null &&
        _selectedWorkerIds.contains(_recommendedWorker!.id);

    try {
      await widget.complaintService.assignFieldStaff(
        complaintId: widget.complaintId,
        assignedWorkerIds: workerIds,
        assignedEmails: workerEmails,
        assignedWorkerNames: workerNames,
        assignedWorkerRoles: workerRoles,
        assignmentMode: includesRecommended ? 'recommended_included' : 'manual',
        assignmentReason: 'Team assigned by AE',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned ${_selectedWorkerIds.length} workers successfully!')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save assignment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _markPendingAssignment() async {
    setState(() => _saving = true);
    try {
      await widget.complaintService.markPendingAssignment(widget.complaintId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint moved to pending assignment.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark pending assignment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}