import 'package:cloud_firestore/cloud_firestore.dart';

class EscalationHistoryEntry {
  final String fromRole;
  final String toRole;
  final String reason;
  final DateTime timestamp;

  const EscalationHistoryEntry({
    required this.fromRole,
    required this.toRole,
    required this.reason,
    required this.timestamp,
  });

  factory EscalationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return EscalationHistoryEntry(
      fromRole: (map['fromRole'] ?? 'ae').toString(),
      toRole: (map['toRole'] ?? 'aee').toString(),
      reason: (map['reason'] ?? 'Unresolved within priority time').toString(),
      timestamp: ComplaintModel.toDateTime(map['timestamp']) ?? DateTime.now(),
    );
  }
}

class ComplaintModel {
  final String complaintId;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String userId;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final DateTime? createdAt;
  final String ward;
  final String assignedTo;
  final List<String> assignedWorkerIds;
  final List<String>? assignedWorkerNames;
  final List<String>? assignedWorkerRoles;
  final List<String> assignedWorkerEmails;
  final String assignedWard;
  final String assignedRole;
  final String assignedStaffRole;
  final DateTime? assignedAt;
  final DateTime? slaDeadline;
  final int escalationLevel;
  final bool isEscalated;
  final DateTime? lastEscalatedAt;
  final List<EscalationHistoryEntry> escalationHistory;
  final String resolutionNote;
  final String proofImage;
  final DateTime lastUpdated;
  final int reopenCount;
  final bool isMajorFault;
  final bool isSafetyRisk;
  final String currentOwnerRole;
  final DateTime? aeeDeadline;
  final String assignedResources;
  final String aeeNotes;
  final bool inspectionCompleted;
  final DateTime? inspectionDate;
  final String inspectionReport;
  final bool workOrderIssued;
  final String workOrderNumber;
  final String contractorName;
  final String estimatedCost;
  final bool isCpgrams;
  final bool isCmCell;
  final bool isCourtCase;
  final String budgetSource;
  final bool citizenNotified;
  final String section_id;
  final String ebServiceNumber;
  final String actionTaken;
  final String signatureUrl;

  const ComplaintModel({
    required this.complaintId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.createdAt,
    required this.ward,
    required this.assignedTo,
    this.assignedWorkerIds = const [],
    this.assignedWorkerEmails = const [],
    this.assignedWorkerNames = const [],
    this.assignedWorkerRoles = const [],
    required this.assignedWard,
    required this.assignedRole,
    required this.assignedStaffRole,
    required this.assignedAt,
    required this.slaDeadline,
    required this.escalationLevel,
    required this.isEscalated,
    required this.lastEscalatedAt,
    required this.escalationHistory,
    required this.resolutionNote,
    required this.proofImage,
    required this.lastUpdated,
    this.reopenCount = 0,
    this.isMajorFault = false,
    this.isSafetyRisk = false,
    this.currentOwnerRole = 'AE',
    this.aeeDeadline,
    this.assignedResources = 'Unassigned',
    this.aeeNotes = 'Not Added',
    this.inspectionCompleted = false,
    this.inspectionDate,
    this.inspectionReport = 'Not Entered',
    this.workOrderIssued = false,
    this.workOrderNumber = 'N/A',
    this.contractorName = 'N/A',
    this.estimatedCost = '0',
    this.isCpgrams = false,
    this.isCmCell = false,
    this.isCourtCase = false,
    this.budgetSource = 'State Fund',
    this.citizenNotified = false,
    this.section_id = '',
    this.ebServiceNumber = '',
    this.actionTaken = 'Not Added',
    this.signatureUrl = '',
  });

  factory ComplaintModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? createdAt;
    final createdAtValue = data['createdAt'];
    createdAt = toDateTime(createdAtValue);

    final assignedRoleRaw = (data['assignedRole'] ?? '').toString().trim();
    final currentOwnerRoleRaw =
        (data['currentOwnerRole'] ?? 'AE').toString().trim();
    final ownerRole = _normalizeOwnerRole(
      _isOwnerRole(assignedRoleRaw) ? assignedRoleRaw : currentOwnerRoleRaw,
    );

    final assignedStaffRoleRaw = _isOwnerRole(assignedRoleRaw)
        ? (data['assignedStaffRole'] ?? 'Pending').toString()
        : (data['assignedStaffRole'] ?? data['assignedRole'] ?? 'Pending')
            .toString();

    final assignedAt = toDateTime(data['assignedAt']) ?? createdAt;
    final escalationLevelRaw = data['escalationLevel'];
    final escalationLevel = escalationLevelRaw is num
      ? escalationLevelRaw.toInt()
      : _roleToLevel(ownerRole);

    final historyRaw = data['escalationHistory'];
    final escalationHistory = historyRaw is List
        ? historyRaw
            .whereType<Map>()
            .map(
              (entry) => EscalationHistoryEntry.fromMap(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList(growable: false)
        : const <EscalationHistoryEntry>[];

    return ComplaintModel(
      complaintId: (data['complaintId'] ?? doc.id).toString(),
      title: (data['title'] ?? 'No Title').toString(),
      description: (data['description'] ?? 'No Description').toString(),
      category: (data['category'] ?? data['aiCategory'] ?? 'Uncategorized')
          .toString(),
      priority: (data['priority'] ?? data['aiPriority'] ?? 'Normal').toString(),
      status: (data['status'] ?? 'Submitted').toString(),
      userId: (data['userId'] ?? 'Unknown User').toString(),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      createdAt: createdAt,
      ward: (data['ward'] ?? 'Unknown').toString(),
      assignedTo: (data['assignedTo'] ?? 'Unassigned').toString(),
      assignedWorkerIds: List<String>.from(data['assignedWorkerIds'] ?? []),
      assignedWorkerEmails: List<String>.from(data['assignedWorkerEmails'] ?? []),
      assignedWard: '',
      assignedWorkerNames: data['assignedWorkerNames'] != null
          ? List<String>.from(data['assignedWorkerNames'])
          : null,
      assignedWorkerRoles: data['assignedWorkerRoles'] != null
          ? List<String>.from(data['assignedWorkerRoles'])
          : null,
      assignedRole: ownerRole,
      assignedStaffRole: assignedStaffRoleRaw,
      assignedAt: assignedAt,
      slaDeadline: toDateTime(data['slaDeadline']),
      escalationLevel: escalationLevel,
      isEscalated: (data['isEscalated'] ?? (escalationHistory.isNotEmpty)) == true,
      lastEscalatedAt: toDateTime(data['lastEscalatedAt']),
      escalationHistory: escalationHistory,
      resolutionNote: (data['resolutionNote'] ?? 'Not Added').toString(),
      proofImage:
      (data['proofImage'] ?? 'placeholder_image_url').toString(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      reopenCount: data['reopenCount'] ?? 0,
      isMajorFault: data['isMajorFault'] ?? false,
      isSafetyRisk: data['isSafetyRisk'] ?? false,
      currentOwnerRole: ownerRole.toUpperCase(),
      aeeDeadline: toDateTime(data['aeeDeadline']),
      assignedResources: (data['assignedResources'] ?? 'Unassigned').toString(),
      aeeNotes: (data['aeeNotes'] ?? 'Not Added').toString(),
      inspectionCompleted: data['inspectionCompleted'] ?? false,
      inspectionDate: toDateTime(data['inspectionDate']),
      inspectionReport: (data['inspectionReport'] ?? 'Not Entered').toString(),
      workOrderIssued: data['workOrderIssued'] ?? false,
      workOrderNumber: (data['workOrderNumber'] ?? 'N/A').toString(),
      contractorName: (data['contractorName'] ?? 'N/A').toString(),
      estimatedCost: (data['estimatedCost'] ?? '0').toString(),
      isCpgrams: data['isCpgrams'] ?? false,
      isCmCell: data['isCmCell'] ?? false,
      isCourtCase: data['isCourtCase'] ?? false,
      budgetSource: (data['budgetSource'] ?? 'State Fund').toString(),
      citizenNotified: data['citizenNotified'] ?? false,
      section_id: (data['section_id'] ?? '').toString(),
      ebServiceNumber: (data['ebServiceNumber'] ?? data['ebServicenumber'] ?? '').toString(),
      actionTaken: (data['actionTaken'] ?? 'Not Added').toString(),
      signatureUrl: (data['signatureUrl'] ?? '').toString(),
    );
  }

  get additionalData => null;





  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _isOwnerRole(String value) {
    final role = value.trim().toLowerCase();
    return role == 'ae' || role == 'aee' || role == 'ee';
  }

  static String _normalizeOwnerRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'aee') return 'aee';
    if (role == 'ee') return 'ee';
    return 'ae';
  }

  static int _roleToLevel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'aee':
        return 2;
      case 'ee':
        return 3;
      default:
        return 1;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}