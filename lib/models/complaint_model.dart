import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String complaintId;
  final String title;
  final String description;
  final String category;
  String status;
  final String priority;
  final String ebservicenumber;
  final DateTime date;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String userId;
  String assignedTo;
  double? distance;
  double? rating;
  final String? feedback;
  final String proofImage;
  final String resolutionNote;
  final String signatureUrl;
  final DateTime lastUpdated;
  final List<String> assignedWorkerIds;
  final String assignedWorkerName;
  final String assignedWorkerRole;

  // ─── New Fields From Your Firebase Document ───────────────────────────────
  final String sectionId; // Maps to 'section_id'
  final double? officeLat; // Maps to 'office_lat'
  final double? officeLon; // Maps to 'office_lon'

  Complaint({
    required this.complaintId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    required this.ebservicenumber,
    required this.date,
    this.imageUrl,
    this.latitude,
    this.longitude,
    required this.userId,
    this.assignedTo = 'sakthi@gmail.com',
    this.distance,
    required this.feedback,
    required this.rating,
    required this.resolutionNote,
    required this.proofImage,
    this.signatureUrl = '',
    required this.lastUpdated,
    required this.assignedWorkerIds,
    required this.assignedWorkerName,
    required this.assignedWorkerRole,
    // ─── New Constructor Fields ─────────────────────────────────────────────
    required this.sectionId,
    this.officeLat,
    this.officeLon,
  });

  factory Complaint.fromFirestore(Map<String, dynamic> data) {
    return Complaint(
      complaintId: data['complaintId'] ?? '',
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      status: data['status'] ?? 'Submitted',
      priority: data['priority'] ?? 'MEDIUM',
      ebservicenumber: data['ebservicenumber'] ?? '',
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      userId: data['userId'] ?? '',

      // ─── FIX: Bulletproof string fallback normalization ───
      assignedTo: (data['assigned_To'] ?? data['assignedTo'] ??
          'sakthi@gmail.com').toString(),

      rating: data['rating']?.toDouble(),
      feedback: data['feedback'],
      resolutionNote: (data['resolutionNote'] ?? 'Not Added').toString(),
      proofImage: (data['proofImage'] ?? 'placeholder_image_url').toString(),
      signatureUrl: (data['signatureUrl'] ?? '').toString(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      assignedWorkerIds: data['assignedWorkerIds'] != null
          ? List<String>.from(data['assignedWorkerIds'])
          : [],
      assignedWorkerName: '',
      assignedWorkerRole: '',
      sectionId: (data['section_id'] ?? '').toString(),
      officeLat: data['office_lat']?.toDouble(),
      officeLon: data['office_lon']?.toDouble(),
    );
  }

  factory Complaint.fromWorkerFirestore(Map<String, dynamic> data,
      String docId) {
    return Complaint(
      complaintId: docId,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      status: data['status'] ?? 'Submitted',
      priority: data['priority'] ?? 'MEDIUM',
      ebservicenumber: data['ebservicenumber'] ?? '',
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      userId: data['userId'] ?? '',

      // ─── FIX: Bulletproof string fallback normalization ───
      assignedTo: (data['assigned_To'] ?? data['assignedTo'] ??
          'sakthi@gmail.com').toString(),

      rating: data['rating']?.toDouble(),
      feedback: data['feedback'],
      resolutionNote: (data['resolutionNote'] ?? 'Not Added').toString(),
      proofImage: (data['proofImage'] ?? 'placeholder_image_url').toString(),
      signatureUrl: (data['signatureUrl'] ?? '').toString(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      assignedWorkerIds: data['assignedWorkerIds'] != null
          ? List<String>.from(data['assignedWorkerIds'])
          : [],
      assignedWorkerName: '',
      assignedWorkerRole: '',
      sectionId: (data['section_id'] ?? '').toString(),
      officeLat: data['office_lat']?.toDouble(),
      officeLon: data['office_lon']?.toDouble(),
    );
  }
}