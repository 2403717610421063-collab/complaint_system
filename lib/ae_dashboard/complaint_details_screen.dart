import 'package:flutter/material.dart';
import '../models/admin_complaint_model.dart';
import '../services/complaint_service.dart';
import '../services/status_normalizer.dart';
import 'assign_staff_screen.dart';
import 'resolution_entry_screen.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final String complaintId;
  final ComplaintService? _complaintService;

  ComplaintService get complaintService => _complaintService ?? ComplaintService();

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  bool _loading = false;

  // --- THEME COLORS ---
  static const _purple       = Color(0xFF5B2D91);
  static const _purpleLight  = Color(0xFF7C3FBE);
  static const _bgPage       = Color(0xFFF4F2FA);
  static const _green        = Color(0xFF22C55E);
  static const _darkGreen    = Color(0xFF15803D);
  static const _amber        = Color(0xFFF59E0B);
  static const _red          = Color(0xFFEF4444);
  static const _textDark     = Color(0xFF1C0B3A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        title: const Text('Complaint Detail'),
        elevation: 0,
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ComplaintModel?>(
        stream: widget.complaintService.streamComplaintById(widget.complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final complaint = snapshot.data;
          if (complaint == null) return const Center(child: Text('Complaint not found.'));

          // --- 1. CORE LOGIC VARIABLES ---
          final normalizedStatus = normalizeStatus(complaint.status);
          final bool isAe = complaint.assignedRole.trim().toLowerCase() == 'ae';

          // CHECK: Are there any workers in the list?
          final bool hasWorkers = complaint.assignedWorkerIds.isNotEmpty;

          // CHECK: Has proof been collected?
          final bool proofCollected = complaint.proofImage.trim().isNotEmpty &&
              complaint.proofImage != 'placeholder_image_url';

          // --- PERMISSIONS ---
          final bool canManageStaff = isAe && (normalizedStatus == 'pending' || normalizedStatus == 'classified' || normalizedStatus == 'in_progress');
          final bool canEnterResolution = isAe && normalizedStatus == 'in_progress' && hasWorkers;
          final bool canFinalize = isAe && normalizedStatus == 'resolved';
          final bool canReopen = isAe && (normalizedStatus == 'resolved' || normalizedStatus == 'closed');
          final bool isFullyFinished = normalizedStatus == 'closed' || normalizedStatus == 'finished';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(complaint, normalizedStatus),
                    const SizedBox(height: 16),

                    _buildDetailsGrid(complaint, hasWorkers, proofCollected),
                    const SizedBox(height: 16),

                    // Dedicated Multiple Workers Details Card
                    if (hasWorkers) ...[
                      _buildWorkerInfoCard(complaint),
                      const SizedBox(height: 16),
                    ],

                    // Initial Complaint Image
                    _buildInitialImageSection(complaint),
                    const SizedBox(height: 16),

                    // ONLY show this highlighted box if proof is collected
                    if (proofCollected) ...[
                      _buildProofCard(complaint),
                      const SizedBox(height: 16),
                    ],

                    _buildActionPanel(
                      complaint: complaint,
                      canManageStaff: canManageStaff,
                      hasWorkers: hasWorkers,
                      canResolve: canEnterResolution,
                      canFinalize: canFinalize,
                      canReopen: canReopen,
                      isFullyFinished: isFullyFinished,
                    ),

                    if (_loading) const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(color: _purple),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeaderCard(ComplaintModel complaint, String status) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade300)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    complaint.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textDark),
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Text("Complaint ID: ${complaint.complaintId}",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(ComplaintModel complaint, bool hasWorkers, bool proofCollected) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 180,
        ),
        children: [
          _infoBox("Location & Category", Icons.location_on, [
            _dataRow("Ward", complaint.ward),
            _dataRow("Category", complaint.category),
            _dataRow("Priority", complaint.priority,
                color: complaint.priority.toLowerCase() == 'high' ? _red : _green),
          ]),
          _infoBox("Assignment Status", Icons.assignment_ind, [
            _dataRow("Assigned AE", complaint.assignedTo),
            _dataRow("Crew Size", hasWorkers ? "${complaint.assignedWorkerIds.length} Workers" : "Unassigned",
                color: hasWorkers ? Colors.blue : _amber),
            _dataRow("Work Proof", proofCollected ? "✅ Collected" : "⏳ Pending",
                color: proofCollected ? _green : Colors.grey),
          ]),
        ],
      );
    });
  }

  Widget _buildWorkerInfoCard(ComplaintModel complaint) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text("Assigned Work Crew (${complaint.assignedWorkerIds.length})",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900)),
            ],
          ),
          const SizedBox(height: 16),

          // Generate a row for every worker in the array
          ...complaint.assignedWorkerIds.asMap().entries.map((entry) {
            final int index = entry.key; // 0, 1, 2...
            final int workerNumber = index + 1; // 1, 2, 3...
            final String workerId = entry.value;

            // IMPORTANT: Since your database currently only stores IDs and Emails,
            // you will need to ensure your ComplaintModel has these arrays,
            // OR fetch the name/role from Firestore using the workerId.
            // This uses a safe fallback just in case the data isn't there yet.
            final String workerName = (complaint.assignedWorkerNames != null && complaint.assignedWorkerNames!.length > index)
                ? complaint.assignedWorkerNames![index]
                : "Fetching Name...";

            final String workerRole = (complaint.assignedWorkerRoles != null && complaint.assignedWorkerRoles!.length > index)
                ? complaint.assignedWorkerRoles![index]
                : "Field Worker";
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A nice circular badge for the worker number
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      "$workerNumber",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Worker details column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "Worker $workerNumber: $workerName",
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                        const SizedBox(height: 2),
                        Text(
                            workerRole,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(), // Make sure you include .toList() at the end!
        ],
      ),
    );
  }

  Widget _buildInitialImageSection(ComplaintModel complaint) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade300)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.report_problem, color: _amber, size: 20),
                SizedBox(width: 8),
                Text("Initial Complaint Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
              ],
            ),
            const Divider(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: complaint.imageUrl.trim().isNotEmpty
                  ? Image.network(complaint.imageUrl, height: 250, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => _imagePlaceholder("Image failed to load"))
                  : _imagePlaceholder("No initial image provided"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofCard(ComplaintModel complaint) {
    final String signatureUrl = complaint.signatureUrl;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, color: _green, size: 24),
              SizedBox(width: 8),
              Text("Crew's Proof of Completion",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _green)),
            ],
          ),
          const SizedBox(height: 16),

          const Text("Action Taken / Resolution Note:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              complaint.resolutionNote.isNotEmpty ? complaint.resolutionNote : "No notes provided.",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;

                if (isWide) {
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _proofImageWidget("Work Proof Photo", complaint.proofImage)),
                        const SizedBox(width: 16),
                        Expanded(child: _proofImageWidget("Citizen Signature", signatureUrl, isSignature: true)),
                      ]
                  );
                } else {
                  return Column(
                      children: [
                        _proofImageWidget("Work Proof Photo", complaint.proofImage),
                        const SizedBox(height: 16),
                        _proofImageWidget("Citizen Signature", signatureUrl, isSignature: true),
                      ]
                  );
                }
              }
          ),
        ],
      ),
    );
  }

  Widget _proofImageWidget(String label, String url, {bool isSignature = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: url.isNotEmpty && url != 'placeholder_image_url'
              ? Container(
            color: Colors.white,
            child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: isSignature ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (_,__,___) => _imagePlaceholder("Unable to load")
            ),
          )
              : _imagePlaceholder("Not Provided"),
        ),
      ],
    );
  }

  Widget _buildActionPanel({
    required ComplaintModel complaint,
    required bool canManageStaff,
    required bool hasWorkers,
    required bool canResolve,
    required bool canFinalize,
    required bool canReopen,
    required bool isFullyFinished
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Administrative Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
          const SizedBox(height: 15),

          if (canManageStaff)
            _btn(
                hasWorkers ? "Manage Field Crew" : "Assign Field Crew",
                hasWorkers ? Icons.manage_accounts : Icons.group_add,
                    () => _toAssign(complaint),
                color: _purpleLight
            ),

          if (canResolve)
            _btn("Submit Work Proof", Icons.upload_file, () => _toResolve(complaint), color: _amber),

          if (canFinalize)
            _btn("Finalize & Close Complaint", Icons.task_alt, () => _finalize(complaint.complaintId), color: _green),

          if (canReopen)
            _btn("Reopen Complaint", Icons.settings_backup_restore, () => _reopen(complaint.complaintId), color: _red),

          if (isFullyFinished)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
              child: const Center(
                  child: Text("✅ This complaint is verified and closed.",
                      style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold))
              ),
            ),

          if (!canManageStaff && !canResolve && !canFinalize && !canReopen && !isFullyFinished)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text("No actions currently available", style: TextStyle(color: Colors.grey))),
            )
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _getColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor(status), width: 1.5),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: _getColor(status), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
    );
  }

  Widget _infoBox(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: _purple),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _purple)),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Flexible(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(String text) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color ?? _purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        ),
      ),
    );
  }

  // --- NAVIGATION & SERVICES ---

  void _toAssign(ComplaintModel c) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AssignStaffScreen(
        complaintId: c.complaintId, sectionId: c.section_id, complaintService: widget.complaintService)));
  }

  void _toResolve(ComplaintModel c) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ResolutionEntryScreen(
        complaintId: c.complaintId, complaintService: widget.complaintService)));
  }

  Future<void> _finalize(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalize Complaint?"),
        content: const Text("This confirms you have verified the work proof and the issue is fully settled. This will close the complaint."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Finalize", style: TextStyle(color: _green, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await widget.complaintService.updateComplaintStatus(id, 'closed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Complaint verified and closed successfully!"), backgroundColor: _green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error finalizing: $e"), backgroundColor: _red)
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _reopen(String id) async {
    setState(() => _loading = true);
    try {
      await widget.complaintService.reopenComplaint(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error reopening: $e"), backgroundColor: _red)
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getColor(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
      case 'finished': return _darkGreen;
      case 'resolved': return _green;
      case 'in_progress': return _amber;
      case 'under_review': return _purpleLight;
      case 'escalated': return _red;
      default: return Colors.blue;
    }
  }
}