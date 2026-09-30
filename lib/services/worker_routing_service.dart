import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/field_worker_model.dart';

class WorkerRoutingService {
  WorkerRoutingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

    /// All field workers now live as user documents in the `Users` collection.
    ///
    /// We treat any user with `role = 'FIELD_WORKER'` (and typically
    /// `officialRole = 'Lineman' | 'Foreman'`) as an assignable field
    /// worker. Placeholder workers that are auto-seeded per section are
    /// also stored here.
    CollectionReference<Map<String, dynamic>> get _workers =>
      _firestore.collection('Users');

  /// Ensure that a given AE section has exactly four default field workers
  /// seeded for it. If any worker already exists for that section, we assume
  /// seeding has been done and skip creation.
  Future<void> ensureDefaultWorkersForSection(String aeSection) async {
    final section = aeSection.trim();
    if (section.isEmpty) return;

    final existing = await _workers
        .where('section', isEqualTo: section)
        .where('role', isEqualTo: 'FIELD_WORKER')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final normalizedKey = section
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

    final List<Map<String, String>> defaults = [
      {
        'id': 'fw_${normalizedKey}_1',
        'name': 'Section Tech 1',
        'officialRole': 'Lineman',
        'phone': '9000000001',
      },
      {
        'id': 'fw_${normalizedKey}_2',
        'name': 'Section Tech 2',
        'officialRole': 'Lineman',
        'phone': '9000000002',
      },
      {
        'id': 'fw_${normalizedKey}_3',
        'name': 'Section Tech 3',
        'officialRole': 'Lineman',
        'phone': '9000000003',
      },
      {
        'id': 'fw_${normalizedKey}_4',
        'name': 'Section Supervisor',
        'officialRole': 'Foreman',
        'phone': '9000000004',
      },
    ];

    for (final entry in defaults) {
      final id = entry['id']!;
      final ref = _workers.doc(id);
      final snapshot = await ref.get();
      if (snapshot.exists) continue;

      final worker = FieldWorkerModel(
        id: id,
        name: entry['name']!,
        role: 'FIELD_WORKER',
        officialRole: entry['officialRole']!,
        section: section,
        contact: entry['phone']!,
        ward: '',
        status: 'free',
        activeJobs: 0,
        maxJobs: 3,
        email: '',
        password: '',
      );

      await ref.set(worker.toMap());
    }
  }

  /// Legacy compatibility helper used from the admin dashboard.
  ///
  /// It scans the `complaints` collection for distinct `tnebAeSection`
  /// values and ensures that each such section has its default workers
  /// seeded via [ensureDefaultWorkersForSection].
  Future<void> ensureSeedWorkers() async {
    final complaintsSnapshot = await _firestore
        .collection('complaints')
        .where('tnebAeSection', isGreaterThan: '')
        .get();

    final sections = complaintsSnapshot.docs
        .map((doc) => (doc.data()['tnebAeSection'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final section in sections) {
      await ensureDefaultWorkersForSection(section);
    }
  }

  /// Get eligible workers for a complaint based on its AE section.
  ///
  /// This ignores wards entirely and filters only by the `section` field,
  /// which we treat as the TNEB AE section.
  Future<List<FieldWorkerModel>> getEligibleWorkersForSection(
    String aeSection,
  ) async {
    final section = aeSection.trim();
    if (section.isEmpty) return const <FieldWorkerModel>[];

    final snapshot = await _workers
      .where('section', isEqualTo: section)
      .where('role', isEqualTo: 'FIELD_WORKER')
      .get();
    final workers = snapshot.docs
        .map(FieldWorkerModel.fromDocument)
        .where(
          (worker) =>
              worker.status.toLowerCase() != 'offline' &&
              worker.activeJobs < worker.maxJobs,
        )
        .toList(growable: false)
      ..sort((left, right) {
        final loadCompare = left.activeJobs.compareTo(right.activeJobs);
        if (loadCompare != 0) return loadCompare;

        final leftAssigned = left.lastAssignedAt;
        final rightAssigned = right.lastAssignedAt;
        if (leftAssigned == null && rightAssigned == null) return 0;
        if (leftAssigned == null) return -1;
        if (rightAssigned == null) return 1;
        return leftAssigned.compareTo(rightAssigned);
      });

    return workers;
  }

  FieldWorkerModel? recommendWorker({
    required List<FieldWorkerModel> eligibleWorkers,
    required String complaintPriority,
    required String complaintStatus,
  }) {
    if (eligibleWorkers.isEmpty) return null;

    final normalizedPriority = complaintPriority.trim().toLowerCase();
    final normalizedStatus = complaintStatus.trim().toLowerCase();
    final preferredRole =
        (normalizedPriority == 'high' || normalizedStatus == 'reopened')
            ? 'foreman'
            : 'lineman';

    for (final worker in eligibleWorkers) {
      if (worker.officialRole.toLowerCase().contains(preferredRole)) {
        return worker;
      }
    }

    return eligibleWorkers.first;
  }
}
