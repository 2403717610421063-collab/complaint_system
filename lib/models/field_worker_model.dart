import 'package:cloud_firestore/cloud_firestore.dart';

class FieldWorkerModel {
  final String id;
  final String name;
  final String role;
  final String officialRole;
  final String section;
  final String contact;
  final String email;
  final bool isAvailable;
  final String ward;
  final String status;
  final int activeJobs;
  final int maxJobs;
  final String password;
  final DateTime? lastAssignedAt;

  FieldWorkerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.officialRole,
    required this.section,
    required this.contact,
    required this.email,
    this.isAvailable = true,
    this.ward = '52',
    this.status = 'free',
    this.activeJobs = 0,
    this.maxJobs = 3,
    this.lastAssignedAt,
    this.password = '',
  });

  // ================= FROM FIRESTORE =================
  factory FieldWorkerModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    final active = _asInt(data['activeJobs'], 0);
    final limit = _asInt(data['maxJobs'], 3);

    return FieldWorkerModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? 'OFFICIAL').toString(),
      officialRole: (data['officialRole'] ?? 'Lineman').toString(),
      // Looks for 'section_no' first to match your database, falls back to 'section'
      section: (data['section_no'] ?? data['section_id'] ?? 'Coimbatore Section').toString(),
      contact: (data['contact'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      isAvailable: (data['isAvailable'] ?? true) == true,
      ward: (data['ward'] ?? '52').toString(),
      status: (data['status'] ?? (active >= limit ? 'busy' : 'free')).toString(),
      activeJobs: active,
      maxJobs: limit,
      lastAssignedAt: _asDateTime(data['lastAssignedAt']),
    );
  }

  // ================= TO FIRESTORE =================
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'officialRole': officialRole,
      'section_no': section,
      'contact': contact,
      'email': email,
      'isAvailable': isAvailable,
      'ward': ward,
      'status': status,
      'activeJobs': activeJobs,
      'maxJobs': maxJobs,
      'lastAssignedAt': lastAssignedAt == null
          ? null
          : Timestamp.fromDate(lastAssignedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ================= HELPER FUNCTIONS =================
  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}