import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_complaint_model.dart';
import 'status_normalizer.dart';
import '../location/TNEBLocationService.dart';
import 'email_service.dart';

Duration getEscalationDuration(String priority) {
  final normalized = priority.trim().toLowerCase();
  switch (normalized) {
    case 'high':
      return const Duration(hours: 4);
    case 'medium':
      return const Duration(hours: 15);
    case 'low':
      return const Duration(hours: 24);
    default:
      return const Duration(hours: 24);
  }
}

String getNextRole(String currentRole) {
  final normalized = currentRole.trim().toLowerCase();
  switch (normalized) {
    case 'ae':
      return 'aee';
    case 'aee':
      return 'ee';
    default:
      return 'ee';
  }
}

class ComplaintService {
  ComplaintService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _complaints =>
      _firestore.collection('complaints');

  Future<void> updateComplaintStatus(String complaintId, String newStatus) async {
    try {
      await _firestore.collection('complaints').doc(complaintId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Successfully updated complaint $complaintId to status: $newStatus');
    } on FirebaseException catch (e) {
      print('Firestore error updating status: ${e.code} - ${e.message}');
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      print('Unexpected error updating status: $e');
      throw Exception('An unexpected error occurred while updating the status.');
    }
  }

  Future<void> checkAndProcessEscalations() async {
    // Pre-load AE / AEE / EE officials so that when a complaint
    // auto-escalates we can, on a best-effort basis, also route it
    // to the correct official user based on TNEB hierarchy fields.
    final Map<String, Map<String, dynamic>> _aeBySection = {};
    final Map<String, Map<String, dynamic>> _aeeBySubdivision = {};
    final Map<String, Map<String, dynamic>> _eeByDivision = {};

    try {
      // Officials live in the `Users` collection with an
      // `officialRole` flag. We derive their TNEB hierarchy
      // (section / subdivision / division) from their own
      // latitude/longitude using TNEBLocationService so that we
      // do not need extra routing fields on the user docs.

      final officialsSnap = await _firestore
          .collection('Users')
          .where('officialRole', whereIn: ['AE', 'AEE', 'EE'])
          .get();

      for (final doc in officialsSnap.docs) {
        final data = doc.data();
        final role = (data['officialRole'] ?? '')
            .toString()
            .toUpperCase()
            .trim();

        final lat = (data['latitude'] is num)
            ? (data['latitude'] as num).toDouble()
            : null;
        final lng = (data['longitude'] is num)
            ? (data['longitude'] as num).toDouble()
            : null;
        if (lat == null || lng == null) {
          continue;
        }

        final hierarchy =
            await TNEBLocationService().getHierarchyForPoint(lat, lng);
        if (hierarchy == null) continue;

        final aeSection =
            (hierarchy['aeSection'] ?? '').toString().trim().toLowerCase();
        final aeeSubdivision = (hierarchy['aeeSubdivision'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final eeDivision = (hierarchy['eeDivision'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (role == 'AE' && aeSection.isNotEmpty) {
          _aeBySection.putIfAbsent(aeSection, () => {
                ...data,
                '_id': doc.id,
              });
        } else if (role == 'AEE' && aeeSubdivision.isNotEmpty) {
          _aeeBySubdivision.putIfAbsent(aeeSubdivision, () => {
                ...data,
                '_id': doc.id,
              });
        } else if (role == 'EE' && eeDivision.isNotEmpty) {
          _eeByDivision.putIfAbsent(eeDivision, () => {
                ...data,
                '_id': doc.id,
              });
        }
      }
    } catch (_) {
      // If this pre-load fails for any reason, we still continue with
      // the existing escalation logic; owner routing will just fall
      // back to current behaviour.
    }

    final snapshot = await _complaints.get();
    final now = DateTime.now();

    for (final document in snapshot.docs) {
      final reference = _complaints.doc(document.id);
      
      bool emailShouldSend = false;
      String emailNextRole = '';

      await _firestore.runTransaction((transaction) async {
        final latest = await transaction.get(reference);
        if (!latest.exists) return;

        final data = latest.data() ?? <String, dynamic>{};
        final status = _normalizeStatus((data['status'] ?? '').toString());
        if (status == 'resolved' || status == 'approved') {
          return;
        }

        final currentRole = _normalizeRole(
          (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString(),
        );

        final currentLevel = data['escalationLevel'] is num
            ? (data['escalationLevel'] as num).toInt()
            : _roleToLevel(currentRole);

        if (currentRole == 'ee' || currentLevel >= 3) {
          return;
        }

        if (!_isEligibleForAutoEscalation(currentRole, status)) {
          return;
        }

        final assignedAt = _toDateTime(data['assignedAt']) ??
            _toDateTime(data['createdAt']) ??
            _toDateTime(data['lastUpdated']) ??
            now;

        final priority = (data['priority'] ?? 'Low').toString();
        final existingSlaDeadline = _toDateTime(data['slaDeadline']);
        final computedSlaDeadline = assignedAt.add(getEscalationDuration(priority));
        final effectiveDeadline = existingSlaDeadline ?? computedSlaDeadline;

        if (now.isBefore(effectiveDeadline) || now.isAtSameMomentAs(effectiveDeadline)) {
          if (existingSlaDeadline == null) {
            transaction.update(reference, {
              'slaDeadline': Timestamp.fromDate(computedSlaDeadline),
              'assignedAt': data['assignedAt'] ?? Timestamp.fromDate(assignedAt),
              'escalationLevel': currentLevel,
              'isEscalated': data['isEscalated'] == true,
            });
          }
          return;
        }

        final nextRole = getNextRole(currentRole);
        if (nextRole == currentRole) {
          return;
        }

        final newAssignedAt = now;
        final newSlaDeadline = newAssignedAt.add(getEscalationDuration(priority));
        final nextLevel = _roleToLevel(nextRole);

        final nextStatus = nextRole == 'ee' ? 'escalated' : status;

        // Best-effort owner routing for the *next* role using
        // pre-loaded officials and TNEB hierarchy fields on the
        // complaint document. If no matching official is found,
        // we simply keep the existing `assignedTo`.
        String? nextOwnerIdentifier;
        final aeSection = (data['tnebAeSection'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final aeeSubdivision = (data['tnebAeeSubdivision'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final eeDivision = (data['tnebEeDivision'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        Map<String, dynamic>? selectedOfficial;
        if (nextRole == 'ae' && aeSection.isNotEmpty) {
          selectedOfficial = _aeBySection[aeSection];
        } else if (nextRole == 'aee' && aeeSubdivision.isNotEmpty) {
          selectedOfficial = _aeeBySubdivision[aeeSubdivision];
        } else if (nextRole == 'ee' && eeDivision.isNotEmpty) {
          selectedOfficial = _eeByDivision[eeDivision];
        }

        if (selectedOfficial != null) {
          final email = (selectedOfficial['email'] ?? '').toString().trim();
          final name = (selectedOfficial['name'] ?? '').toString().trim();
          final id = (selectedOfficial['_id'] ?? '').toString().trim();

          nextOwnerIdentifier = email.isNotEmpty
              ? email
              : name.isNotEmpty
                  ? name
                  : id.isNotEmpty
                      ? id
                      : null;
        }

        final escalationReason =
            currentRole == 'aee' && nextRole == 'ee'
                ? 'SLA exceeded while unresolved'
                : 'SLA time exceeded';

        final updateData = <String, dynamic>{
          'assignedRole': nextRole,
          'currentOwnerRole': _displayRole(nextRole),
          'status': nextStatus,
          'assignedAt': Timestamp.fromDate(newAssignedAt),
          'slaDeadline': Timestamp.fromDate(newSlaDeadline),
          'escalationLevel': nextLevel,
          'isEscalated': true,
          'lastEscalatedAt': Timestamp.fromDate(now),
          'lastUpdated': Timestamp.fromDate(now),
          'escalationHistory': FieldValue.arrayUnion([
            {
              'fromRole': currentRole,
              'toRole': nextRole,
              'reason': escalationReason,
              'timestamp': Timestamp.fromDate(now),
            }
          ]),
        };

        if (nextOwnerIdentifier != null) {
          updateData['assignedTo'] = nextOwnerIdentifier;
        }

        transaction.update(reference, updateData);
        
        if (nextStatus == 'escalated') {
          emailShouldSend = true;
          emailNextRole = nextRole;
        }
      });

      // Best-effort email after successful transaction
      if (emailShouldSend) {
        _sendEmailNotification(
          document.id,
          'Complaint Escalated',
          'Your complaint has exceeded the SLA and has been automatically escalated to the higher authority ($emailNextRole).',
        );
      }
    }
  }

  Stream<List<ComplaintModel>> streamActiveComplaints() {
    const activeStatuses = {
      'pending',
      'classified',
      'under_review',
      'in_progress',
      'escalated',
      'approved',
      'resolved',
      'reopened',
    };

    return _complaints
        .snapshots()
        .map((snapshot) {
      final complaints = snapshot.docs
          .map(ComplaintModel.fromFirestore)
          .where(
            (item) => activeStatuses.contains(_normalizeStatus(item.status)),
      )
          .toList(growable: false);

      final sorted = complaints.toList(growable: false)
        ..sort((left, right) {
          final leftTime = left.createdAt;
          final rightTime = right.createdAt;

          if (leftTime == null && rightTime == null) return 0;
          if (leftTime == null) return 1;
          if (rightTime == null) return -1;
          return rightTime.compareTo(leftTime);
        });

      return sorted;
    });
  }

  String _normalizeStatus(String value) => normalizeStatus(value);

  Stream<ComplaintModel?> streamComplaintById(String complaintId) {
    return _complaints.doc(complaintId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ComplaintModel.fromFirestore(doc);
    });
  }

  Future<void> markUnderReview(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'classified', 'reopened'},
      actionLabel: 'Mark Under Review',
    );
    await _ensureModuleDefaults(complaintId);
    await _complaints.doc(complaintId).update({
      'status': 'under_review',
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _sendEmailNotification(
      complaintId,
      'Complaint Under Review',
      'Your complaint has been classified and is currently under review by the designated official.',
    );
  }

  Future<void> markInProgress(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'under_review'},
      actionLabel: 'Mark In Progress',
    );
    await _ensureFieldStaffAssigned(complaintId);
    await _ensureModuleDefaults(complaintId);
    await _complaints.doc(complaintId).update({
      'status': 'in_progress',
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _sendEmailNotification(
      complaintId,
      'Complaint Work Started',
      'Field staff have been assigned and work on your complaint is now in progress.',
    );
  }
  Future<void> assignFieldStaff({
    required String complaintId,
    required List<String> assignedWorkerIds, // Changed to List
    required List<String> assignedEmails,    // Changed to List
    String assignmentMode = 'manual',
    String assignmentReason = 'Team assigned by AE',
    required List<String> assignedWorkerNames,
    required List<String> assignedWorkerRoles,
  }) async {
    // Added 'in_progress' to allowed statuses so the AE can update the crew mid-job
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'classified', 'under_review', 'pending_assignment', 'assigned', 'pending', 'in_progress'},
      actionLabel: 'Assign Field Staff',
    );
    await _ensureModuleDefaults(complaintId);

    // If the list is empty, mark as unassigned
    if (assignedWorkerIds.isEmpty) {
      return _complaints.doc(complaintId).update({
        'assignedWorkerIds': [],
        'assignedWorkerEmails': [],
        'assignedWorkerRole': 'Unassigned',
        'assignmentMode': assignmentMode,
        'assignmentReason': 'Unassigned',
        'routingVersion': 'v2', // Bumped version
        'lastUpdated': FieldValue.serverTimestamp(),
        'assignedWorkerId': FieldValue.delete(),
        'assignedWorkerEmail': FieldValue.delete(),
      });
    }

    final complaintRef = _complaints.doc(complaintId);

    return _firestore.runTransaction((transaction) async {
      final complaintSnapshot = await transaction.get(complaintRef);
      if (!complaintSnapshot.exists) {
        throw StateError('Complaint does not exist.');
      }

      final complaintData = complaintSnapshot.data() ?? <String, dynamic>{};
      final complaintStatus = _normalizeStatus((complaintData['status'] ?? '').toString());
      List<String> previousWorkerIds = [];
      if (complaintData['assignedWorkerIds'] != null) {
        previousWorkerIds = List<String>.from(complaintData['assignedWorkerIds']);
      } else if (complaintData['assignedWorkerId'] != null) {
        final legacyId = complaintData['assignedWorkerId'].toString().trim();
        if (legacyId.isNotEmpty && legacyId.toLowerCase() != 'unassigned') {
          previousWorkerIds = [legacyId];
        }
      }

      // Determine exactly who was added and who was removed
      final Set<String> oldSet = previousWorkerIds.toSet();
      final Set<String> newSet = assignedWorkerIds.toSet();

      final Set<String> workersToAdd = newSet.difference(oldSet);
      final Set<String> workersToRemove = oldSet.difference(newSet);

      // Fetch all required worker documents (adds and removes)
      Map<String, DocumentSnapshot<Map<String, dynamic>>> workerSnapshots = {};
      Map<String, DocumentReference<Map<String, dynamic>>> workerRefs = {};

      // Fetch workers being added
      for (String wId in workersToAdd) {
        var ref = _firestore.collection('Users').doc(wId);
        var snap = await transaction.get(ref);
        if (!snap.exists) {
          ref = _firestore.collection('field_workers').doc(wId);
          snap = await transaction.get(ref);
          if (!snap.exists) throw StateError('Selected worker $wId does not exist.');
        }
        workerRefs[wId] = ref;
        workerSnapshots[wId] = snap;
      }

      // Fetch workers being removed
      for (String wId in workersToRemove) {
        var ref = _firestore.collection('Users').doc(wId);
        var snap = await transaction.get(ref);
        if (!snap.exists) {
          ref = _firestore.collection('field_workers').doc(wId);
          snap = await transaction.get(ref);
        }
        if (snap.exists) {
          workerRefs[wId] = ref;
          workerSnapshots[wId] = snap;
        }
      }

      // ==========================================
      // 2. VALIDATION
      // ==========================================

      for (String wId in workersToAdd) {
        final wData = workerSnapshots[wId]!.data() ?? {};
        final workerStatus = (wData['status'] ?? 'free').toString().toLowerCase();
        final activeJobs = _asInt(wData['activeJobs'], 0);
        final maxJobs = _asInt(wData['maxJobs'], 3);

        if (workerStatus == 'offline') {
          throw StateError('Worker $wId is currently offline.');
        }
        if (activeJobs >= maxJobs) {
          throw StateError('Worker $wId has reached maximum active jobs.');
        }
      }

      // ==========================================
      // 3. APPLY ALL WRITES
      // ==========================================

      // A. Decrement load for removed workers
      for (String wId in workersToRemove) {
        if (!workerSnapshots.containsKey(wId)) continue;

        final wData = workerSnapshots[wId]!.data() ?? {};
        final activeJobs = _asInt(wData['activeJobs'], 0);
        final maxJobs = _asInt(wData['maxJobs'], 3);
        final decrementedJobs = activeJobs > 0 ? activeJobs - 1 : 0;

        transaction.update(workerRefs[wId]!, {
          'activeJobs': decrementedJobs,
          'status': decrementedJobs >= maxJobs ? 'busy' : 'free',
        });
      }

      // B. Increment load for newly added workers
      for (String wId in workersToAdd) {
        final wData = workerSnapshots[wId]!.data() ?? {};
        final activeJobs = _asInt(wData['activeJobs'], 0);
        final maxJobs = _asInt(wData['maxJobs'], 3);
        final incrementedJobs = activeJobs + 1;

        transaction.update(workerRefs[wId]!, {
          'activeJobs': incrementedJobs,
          'status': incrementedJobs >= maxJobs ? 'busy' : 'free',
          'lastAssignedAt': FieldValue.serverTimestamp(),
        });
      }

      // C. Update the main Complaint document
      transaction.update(complaintRef, {
        'assignedWorkerIds': assignedWorkerIds,
        'assignedWorkerEmails': assignedEmails,
        'assignmentMode': assignmentMode,
        'assignmentReason': assignmentReason,
        'routingVersion': 'v2',
        'assignedWorkerNames': assignedWorkerNames,
        'assignedWorkerRoles': assignedWorkerRoles,
        if (complaintStatus == 'pending_assignment') 'status': 'under_review',
        'lastUpdated': FieldValue.serverTimestamp(),

        // Clear legacy fields to migrate the document fully to array-based tracking
        'assignedWorkerId': FieldValue.delete(),
        'assignedWorkerEmail': FieldValue.delete(),
      });
    });
  }
  Future<void> markPendingAssignment(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'classified', 'under_review', 'pending_assignment'},
      actionLabel: 'Mark Pending Assignment',
    );
    await _ensureModuleDefaults(complaintId);

    return _complaints.doc(complaintId).update({
      'status': 'pending_assignment',
      'assignmentMode': 'manual',
      'assignmentReason': 'No eligible same-ward worker available',
      'routingVersion': 'v1',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
  Future<void> markResolved({
    required String complaintId,
    required String resolutionNote,
    required String proofImage,
  }) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'in_progress'},
      actionLabel: 'Resolution Entry',
    );
    await _ensureModuleDefaults(complaintId);

    final complaintRef = _complaints.doc(complaintId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(complaintRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? <String, dynamic>{};
      final assignedWorkerId = (data['assignedWorkerId'] ?? '').toString().trim();

      DocumentReference<Map<String, dynamic>>? workerRef;
      DocumentSnapshot<Map<String, dynamic>>? workerSnapshot;

      if (assignedWorkerId.isNotEmpty) {
        workerRef = _firestore.collection('Users').doc(assignedWorkerId);
        workerSnapshot = await transaction.get(workerRef);

        if (!workerSnapshot.exists) {
          workerRef = _firestore.collection('field_workers').doc(assignedWorkerId);
          workerSnapshot = await transaction.get(workerRef);
        }
      }
      transaction.update(complaintRef, {
        'status': 'resolved',
        'resolutionNote':
        resolutionNote.trim().isEmpty ? 'Not Added' : resolutionNote.trim(),
        'proofImage':
        proofImage.trim().isEmpty ? 'placeholder_image_url' : proofImage.trim(),
        'proofCollected':false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (workerRef != null && workerSnapshot != null && workerSnapshot.exists) {
        final workerData = workerSnapshot.data() ?? <String, dynamic>{};
        final activeJobs = _asInt(workerData['activeJobs'], 0);
        final maxJobs = _asInt(workerData['maxJobs'], 3);
        final nextActiveJobs = activeJobs > 0 ? activeJobs - 1 : 0;

        transaction.update(workerRef, {
          'activeJobs': nextActiveJobs,
          'status': nextActiveJobs >= maxJobs ? 'busy' : 'free',
        });
      }
    });

    _sendEmailNotification(
      complaintId,
      'Your Complaint Has Been Resolved ✅',
      'Good news! 🎉\n\nYour complaint has been successfully resolved.\n\nPlease open the CivicConnect app and provide your feedback.\n\nThank you for being a responsible citizen!',
    );
  }

  Future<void> reopenComplaint(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'resolved','closed'},
      actionLabel: 'Reopen Complaint',
    );

    final now = DateTime.now();
    final snapshot = await _complaints.doc(complaintId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final priority = (data['priority'] ?? 'Low').toString();

    final complaintRef = _complaints.doc(complaintId);

    return _firestore.runTransaction((transaction) async {
      final complaintSnapshot = await transaction.get(complaintRef);
      if (!complaintSnapshot.exists) return;

      final complaintData = complaintSnapshot.data() ?? <String, dynamic>{};
      final assignedWorkerId = (complaintData['assignedWorkerId'] ?? '').toString().trim();

      DocumentSnapshot<Map<String, dynamic>>? workerSnapshot;
      DocumentReference<Map<String, dynamic>>? workerRef;

      if (assignedWorkerId.isNotEmpty) {

        workerRef = _firestore.collection('Users').doc(assignedWorkerId);
        workerSnapshot = await transaction.get(workerRef!);

        if (!workerSnapshot.exists) {
          workerRef = _firestore.collection('field_workers').doc(assignedWorkerId);
          workerSnapshot = await transaction.get(workerRef);
        }
      }

      transaction.update(complaintRef, {
        'status': 'classified',
        'assignedWorkerId': '',
        'assignedWorkerName': 'Unassigned',
        'assignedWorkerRole': 'Pending',
        'assignedWard': complaintData['ward'] ?? 'Unknown',
        'assignedRole': 'ae',
        'currentOwnerRole': 'AE',
        'assignedAt': FieldValue.serverTimestamp(),
        'slaDeadline': Timestamp.fromDate(now.add(getEscalationDuration(priority))),
        'escalationLevel': 1,
        'isEscalated': false,
        'lastEscalatedAt': null,
        'resolutionNote': 'Not Added',
        'proofImage': 'placeholder_image_url',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (workerSnapshot != null && workerSnapshot.exists && workerRef != null) {
        final workerData = workerSnapshot.data() ?? <String, dynamic>{};
        final activeJobs = _asInt(workerData['activeJobs'], 0);
        final maxJobs = _asInt(workerData['maxJobs'], 3);
        final nextActiveJobs = activeJobs > 0 ? activeJobs - 1 : 0;

        transaction.update(workerRef, {
          'activeJobs': nextActiveJobs,
          'status': nextActiveJobs >= maxJobs ? 'busy' : 'free',
        });
      }
    }).then((_) {
      _sendEmailNotification(
        complaintId,
        'Complaint Reopened',
        'Your complaint has been reopened and is being actively looked into entirely anew by the officials.',
      );
    });
  }

  Future<void> deleteComplaint(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'resolved'},
      actionLabel: 'Delete Complaint',
    );
    return _complaints.doc(complaintId).delete();
  }

  Future<void> _ensureAllowedCurrentStatus(
      String complaintId, {
        required Set<String> allowed,
        required String actionLabel,
      }) async {
    final snapshot = await _complaints.doc(complaintId).get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final status = _normalizeStatus((data['status'] ?? '').toString());

    if (!allowed.contains(status)) {
      throw StateError(
        '$actionLabel is not allowed when status is $status.',
      );
    }
  }

  Future<void> _ensureFieldStaffAssigned(String complaintId) async {
    final snapshot = await _complaints.doc(complaintId).get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final assignedTo = _normalizeStatus((data['assignedTo'] ?? '').toString());
    final assignedRoleRaw = (data['assignedStaffRole'] ?? '').toString();
    final fallbackAssignedRoleRaw = (data['assignedRole'] ?? '').toString();

    final assignedRole = _normalizeStatus(
      assignedRoleRaw.trim().isEmpty && !_isOwnerRole(fallbackAssignedRoleRaw)
          ? fallbackAssignedRoleRaw
          : assignedRoleRaw,
    );

    const assignedOfficial = 'sakthi@gmail.com';
    final isOfficialDefaultOnly =
        assignedTo == assignedOfficial &&
            (assignedRole.isEmpty || assignedRole == 'pending');

    if (assignedTo.isEmpty ||
        assignedTo == 'pending' ||
        assignedTo == 'unassigned' ||
        assignedRole.isEmpty ||
        assignedRole == 'pending' ||
        isOfficialDefaultOnly) {
      throw StateError('Assign field staff before marking in progress.');
    }
  }

  Future<void> _ensureModuleDefaults(String complaintId) async {
    final ref = _complaints.doc(complaintId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{};

      if (data['ward'] == null) updates['ward'] = 'Unknown';
      if (data['assignedTo'] == null) updates['assignedTo'] = 'Unassigned';
      if (data['assignedStaffRole'] == null) {
        if (!_isOwnerRole((data['assignedRole'] ?? '').toString())) {
          updates['assignedStaffRole'] =
              (data['assignedRole'] ?? 'Pending').toString();
        } else {
          updates['assignedStaffRole'] = 'Pending';
        }
      }
      if (data['assignedRole'] == null) updates['assignedRole'] = 'ae';
      if (data['currentOwnerRole'] == null) updates['currentOwnerRole'] = 'AE';
      final createdAt = data['createdAt'];
      final assignedAt = data['assignedAt'];

      DateTime referenceTime;
      if (assignedAt is Timestamp) {
        referenceTime = assignedAt.toDate();
      } else if (createdAt is Timestamp) {
        referenceTime = createdAt.toDate();
      } else {
        referenceTime = DateTime.now();
      }

      if (data['assignedAt'] == null) {
        updates['assignedAt'] =
            createdAt is Timestamp ? createdAt : Timestamp.fromDate(referenceTime);
      }

      if (data['slaDeadline'] == null) {
        final priority = (data['priority'] ?? 'Low').toString();
        updates['slaDeadline'] =
            Timestamp.fromDate(referenceTime.add(getEscalationDuration(priority)));
      }

      if (data['escalationLevel'] == null) {
        updates['escalationLevel'] = _roleToLevel(
          (data['assignedRole'] ?? 'ae').toString(),
        );
      }

      if (data['isEscalated'] == null) {
        final history = data['escalationHistory'];
        updates['isEscalated'] = history is List && history.isNotEmpty;
      }

      if (data['lastEscalatedAt'] == null) {
        updates['lastEscalatedAt'] = null;
      }

      if (data['escalationHistory'] == null) updates['escalationHistory'] = const [];
      if (data['resolutionNote'] == null) updates['resolutionNote'] = 'Not Added';
      if (data['proofImage'] == null) {
        updates['proofImage'] = 'placeholder_image_url';
      }

      if (updates.isNotEmpty) {
        transaction.update(ref, updates);
      }
    });
  }

  bool _isOwnerRole(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'ae' || normalized == 'aee' || normalized == 'ee';
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'aee') return 'aee';
    if (normalized == 'ee') return 'ee';
    return 'ae';
  }

  String _displayRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 'AEE';
    if (normalized == 'ee') return 'EE';
    return 'AE';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _roleToLevel(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 2;
    if (normalized == 'ee') return 3;
    return 1;
  }

  bool _isEligibleForAutoEscalation(String role, String status) {
    final normalizedRole = _normalizeRole(role);
    final normalizedStatus = _normalizeStatus(status);

    if (normalizedStatus == 'resolved' || normalizedStatus == 'approved') {
      return false;
    }

    if (normalizedRole == 'aee') {
      return normalizedStatus == 'in_progress' || normalizedStatus == 'pending' || normalizedStatus == 'pending_assignment';
    }

    return true;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _sendEmailNotification(
      String complaintId, String subject, String body) async {
    try {
      final doc = await _complaints.doc(complaintId).get();
      if (!doc.exists) return;

      final data = doc.data() ?? <String, dynamic>{};
      final userId = data['userId'];
      final title = data['title'] ?? 'Complaint';
      if (userId == null) return;

      final userDoc = await _firestore.collection('Users').doc(userId.toString()).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? <String, dynamic>{};
      final email = userData['email']?.toString() ?? '';
      final name = userData['name']?.toString() ?? 'Citizen';

      if (email.isNotEmpty) {
        final fullBody =
            "Hi $name,\n\n$body\n\nComplaint ID: $complaintId\nTitle: $title\n\nRegards,\nCivic Connect Team";
        await EmailService().sendStatusEmail(email, subject, fullBody);
      }
    } catch (e) {
      // Best-effort failure
    }
  }
}