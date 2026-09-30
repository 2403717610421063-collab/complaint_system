import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ManageLeavesScreen extends StatefulWidget {
  const ManageLeavesScreen({super.key});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen> {
  static const _purple = Color(0xFF7B1FA2);
  static const _bg = Color(0xFFF4F3F9);

  // 1. Updated Reject Logic (Simple update)
  Future<void> _rejectLeave(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(docId)
          .update({'status': 'rejected'});

      if (!mounted) return;
      _showSnack('Leave request rejected.', Colors.red);
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }
  Future<void> _showApproveDialog(String leaveDocId, String originalOfficerEmail) async {
    String? selectedSubstituteEmail;
    bool isProcessing = false;
    String searchQuery = '';

    // 1. Explicitly type the Future so Flutter knows exactly what data is coming back
    final Future<QuerySnapshot<Map<String, dynamic>>> usersFuture =
    FirebaseFirestore.instance
        .collection('Users')
    // NOTE: If this returns 0 results, check your database! It might be saved as 'official' (lowercase)
        .where('role', isEqualTo: 'OFFICIAL')
        .get();

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: Colors.white,
                  title: Text(
                    'Assign Substitute',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFF1E0A3C),
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search and select an officer to take over the active complaints for $originalOfficerEmail.',
                          style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.trim().toLowerCase();
                            });
                          },
                          style: GoogleFonts.nunito(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            hintStyle: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // List of Officers
                        Expanded(
                          // 2. Explicitly type the FutureBuilder
                          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future: usersFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: _purple));
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text('Error loading officers.', style: GoogleFonts.nunito(color: Colors.red)));
                              }

                              // 3. Safe Filtering
                              final officers = snapshot.data!.docs.where((doc) {
                                // No longer need "as Map<String, dynamic>" because of the explicit typing above!
                                final data = doc.data();

                                // .toString() safely handles numbers/nulls if the database structure is slightly off
                                final email = data['email']?.toString() ?? '';
                                final name = data['name']?.toString() ?? '';
                                final officialRole = data['officialRole']?.toString() ?? '';

                                // A. Don't show the person taking leave
                                if (email == originalOfficerEmail) return false;

                                // B. Hide Foremen and Linemen (Case-insensitive check just to be safe)
                                final roleLower = officialRole.toLowerCase();
                                if (roleLower == 'foreman' || roleLower == 'lineman') return false;

                                // C. Apply search filter
                                if (searchQuery.isNotEmpty) {
                                  return name.toLowerCase().contains(searchQuery) ||
                                      email.toLowerCase().contains(searchQuery);
                                }
                                return true;
                              }).toList();

                              if (officers.isEmpty) {
                                return Center(
                                  child: Text('No matching officers found.', style: GoogleFonts.nunito(color: Colors.grey)),
                                );
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: officers.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final data = officers[index].data();
                                    final email = data['email']?.toString() ?? 'No Email';
                                    final name = data['name']?.toString() ?? 'Unknown';
                                    final sectionId = data['section_id']?.toString()
                                        ?? data['subdivision_id']?.toString()
                                        ?? data['division_id']?.toString()
                                        ?? 'N/A';

                                    final isSelected = selectedSubstituteEmail == email;

                                    return ListTile(
                                      onTap: () {
                                        setState(() {
                                          selectedSubstituteEmail = email;
                                        });
                                      },
                                      selected: isSelected,
                                      selectedTileColor: const Color(0xFFF3E8FF),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      title: Text(
                                        name,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? _purple : const Color(0xFF1E0A3C),
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        email,
                                        style: GoogleFonts.nunito(
                                          color: isSelected ? _purple.withOpacity(0.8) : const Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? _purple.withOpacity(0.3) : Colors.transparent,
                                            )
                                        ),
                                        child: Text(
                                          'ID: $sectionId',
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: isSelected ? _purple : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isProcessing ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: (selectedSubstituteEmail == null || isProcessing)
                          ? null
                          : () async {
                        setState(() => isProcessing = true);
                        await _processApprovalAndReassign(
                            leaveDocId,
                            originalOfficerEmail,
                            selectedSubstituteEmail!
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Approve & Assign', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }
  // 3. The Database Batch Operation
  Future<void> _processApprovalAndReassign(String leaveDocId, String originalEmail, String substituteEmail) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Step A: Update the Leave Request to approved and record the substitute
      final leaveRef = FirebaseFirestore.instance.collection('leave_requests').doc(leaveDocId);
      batch.update(leaveRef, {
        'status': 'approved',
        'substituteAssigned': substituteEmail,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Step B: Find all active complaints assigned to the original officer
      final activeComplaintsQuery = await FirebaseFirestore.instance
          .collection('complaints')
          .where('assignedTo', isEqualTo: originalEmail)
      // We don't want to reassign closed complaints
          .where('status', whereIn: ['pending', 'in_progress', 'escalated', 'resolved'])
          .get();

      // Step C: Add updates to the batch to reassign them
      for (var doc in activeComplaintsQuery.docs) {
        batch.update(doc.reference, {
          'assignedTo': substituteEmail,
          // Optional: Add a note to the history/timeline that it was reassigned due to leave
        });
      }

      // Commit the batch
      await batch.commit();

      _showSnack('Leave approved and ${activeComplaintsQuery.docs.length} complaints reassigned to $substituteEmail.', Colors.green);
    } catch (e) {
      _showSnack('Failed to approve and reassign: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.nunito()), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(
            'Manage Leaves',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: _purple,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Pending Requests'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaveList(statusFilter: 'pending'),
            _LeaveList(statusFilter: 'history'),
          ],
        ),
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  final String statusFilter;
  const _LeaveList({required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leave_requests')
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading requests: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)));
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter based on the tab
        final filteredDocs = allDocs.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'pending';
          if (statusFilter == 'pending') return status == 'pending';
          return status == 'approved' || status == 'rejected';
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available_rounded, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  statusFilter == 'pending' ? 'No pending leave requests.' : 'No leave history found.',
                  style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildLeaveCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildLeaveCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final email = data['email'] ?? 'Unknown User';
    final role = (data['role'] ?? 'Official').toString().toUpperCase();
    final reason = data['reason'] ?? 'No reason provided';
    final status = data['status'] ?? 'pending';
    final substitute = data['substituteAssigned'];

    // Format dates
    final startTimestamp = data['startDate'] as Timestamp?;
    final endTimestamp = data['endDate'] as Timestamp?;
    final startStr = startTimestamp != null ? DateFormat('MMM dd, yyyy').format(startTimestamp.toDate()) : 'N/A';
    final endStr = endTimestamp != null ? DateFormat('MMM dd, yyyy').format(endTimestamp.toDate()) : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF7B1FA2),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 12),

            // Email/Name
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFF1E0A3C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dates
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$startStr  →  $endStr',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1EDF9)),
            ),

            // Reason
            Text(
              'Reason:',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF1E0A3C)),
            ),

            // Show Substitute if approved
            if (status == 'approved' && substitute != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Duties handed over to:\n$substitute',
                        style: GoogleFonts.nunito(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            ],

            // Action Buttons (Only show if pending)
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.findAncestorStateOfType<_ManageLeavesScreenState>()?._rejectLeave(docId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reject', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.findAncestorStateOfType<_ManageLeavesScreenState>()?._showApproveDialog(docId, email),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Approve', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'approved':
        bg = Colors.green.withOpacity(0.1);
        text = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        bg = Colors.red.withOpacity(0.1);
        text = Colors.red;
        label = 'Rejected';
        break;
      default:
        bg = Colors.orange.withOpacity(0.1);
        text = Colors.orange;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: GoogleFonts.nunito(color: text, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}