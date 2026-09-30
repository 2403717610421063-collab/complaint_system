import 'package:cloud_firestore/cloud_firestore.dart';

class SectionDetailsModel {
  final String sectionId;
  final String sectionName;
  final String aeId;
  final String circleId;
  final String circleName;
  final String divisionId;
  final String divisionName;
  final double officeLat;
  final double officeLon;
  final String regionId;
  final String regionName;
  final String subdivisionId;
  final String subdivisionName;

  SectionDetailsModel({
    required this.sectionId,
    required this.sectionName,
    required this.aeId,
    required this.circleId,
    required this.circleName,
    required this.divisionId,
    required this.divisionName,
    required this.officeLat,
    required this.officeLon,
    required this.regionId,
    required this.regionName,
    required this.subdivisionId,
    required this.subdivisionName,
  });

  factory SectionDetailsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SectionDetailsModel(
      sectionId: (data['section_id'] ?? '').toString(),
      sectionName: (data['section_name'] ?? '').toString(),
      aeId: (data['ae_id'] ?? '').toString(),
      circleId: (data['circle_id'] ?? '').toString(),
      circleName: (data['circle_name'] ?? '').toString(),
      divisionId: (data['division_id'] ?? '').toString(),
      divisionName: (data['division_name'] ?? '').toString(),
      officeLat: data['office_lat'] ?? 0.0,
      officeLon: data['office_lon'] ?? 0.0,
      regionId: (data['region_id'] ?? '').toString(),
      regionName: (data['region_name'] ?? '').toString(),
      subdivisionId: (data['subdivision_id'] ?? '').toString(),
      subdivisionName: (data['subdivision_name'] ?? '').toString(),
    );
  }
}

class SectionDetailsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch section details by section_id from Firebase 'sections' collection
  Future<SectionDetailsModel?> getSectionById(String sectionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('sections')
          .where('section_id', isEqualTo: sectionId.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return SectionDetailsModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('Error fetching section details: $e');
      return null;
    }
  }

  /// Stream section details for real-time updates
  Stream<SectionDetailsModel?> streamSectionById(String sectionId) {
    return _firestore
        .collection('sections')
        .where('section_id', isEqualTo: sectionId.trim())
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return SectionDetailsModel.fromFirestore(snapshot.docs.first);
    });
  }
}