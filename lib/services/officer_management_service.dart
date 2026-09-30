import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class OfficerManagementService {
  static final _db = FirebaseFirestore.instance;
  
  /// Load TNEB Master Data (section → subdivision → division mapping)
  static Future<Map<String, dynamic>> loadTNEBMasterData() async {
    try {
      String data = await rootBundle.loadString('assets/TNEB_Master_Data.json');
      final json = jsonDecode(data);
      
      // Build hierarchical structure: division → subdivision → section
      Map<String, dynamic> structure = {};
      
      if (json['features'] is List) {
        for (var feature in json['features']) {
          if (feature['properties'] != null) {
            final props = feature['properties'];
            String division = props['division_name'] ?? '';
            String subdivision = props['subdivision_name'] ?? '';
            String section = props['section_name'] ?? '';
            
            if (division.isNotEmpty && subdivision.isNotEmpty && section.isNotEmpty) {
              if (!structure.containsKey(division)) {
                structure[division] = {};
              }
              if (!structure[division].containsKey(subdivision)) {
                structure[division][subdivision] = [];
              }
              if (!structure[division][subdivision].contains(section)) {
                structure[division][subdivision].add(section);
              }
            }
          }
        }
      }
      
      return structure;
    } catch (e) {
      print('Error loading TNEB data: $e');
      return {};
    }
  }

  /// Get all officers with their details
  static Future<List<Map<String, dynamic>>> getAllOfficers() async {
    try {
      final snapshot = await _db
          .collection('Users')
          .where('role', isEqualTo: 'OFFICIAL')
          .get();
      
      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'uid': doc.id,
      }).toList();
    } catch (e) {
      print('Error fetching officers: $e');
      return [];
    }
  }

  /// Get officers at a specific level (role + jurisdiction)
  static Future<List<Map<String, dynamic>>> getOfficersAtLevel({
    required String role,
    required String jurisdiction,
  }) async {
    try {
      final snapshot = await _db
          .collection('Users')
          .where('role', isEqualTo: 'OFFICIAL')
          .where('officialRole', isEqualTo: role)
          .get();
      
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            String jField = role == 'AE' ? 'section' : 
                            role == 'AEE' ? 'subdivision' : 'division';
            return data[jField] == jurisdiction;
          })
          .map((doc) => {
            ...doc.data(),
            'uid': doc.id,
          })
          .toList();
    } catch (e) {
      print('Error fetching officers at level: $e');
      return [];
    }
  }

  /// Check if we can safely remove/modify an officer
  /// (requires at least 1 other officer at same level)
  static Future<bool> canModifyOfficer({
    required String officerId,
    required String role,
    required String jurisdiction,
  }) async {
    try {
      final officersAtLevel = await getOfficersAtLevel(
        role: role,
        jurisdiction: jurisdiction,
      );
      
      // Filter out the current officer
      final othersAvailable = officersAtLevel
          .where((o) => o['uid'] != officerId)
          .length;
      
      return othersAvailable >= 1;
    } catch (e) {
      print('Error checking if officer can be modified: $e');
      return false;
    }
  }

  /// Get in_progress complaints assigned to an officer
  static Future<List<Map<String, dynamic>>> getInProgressComplaints(
    String officerId,
  ) async {
    try {
      final snapshot = await _db
          .collection('complaints')
          .where('assignedTo', isEqualTo: officerId)
          .where('status', isEqualTo: 'in_progress')
          .get();
      
      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'complaintId': doc.id,
      }).toList();
    } catch (e) {
      print('Error fetching in_progress complaints: $e');
      return [];
    }
  }

  /// Reassign all of an officer's in_progress complaints to another officer
  static Future<void> reassignComplaints({
    required String fromOfficerId,
    required String toOfficerId,
  }) async {
    try {
      final complaints = await getInProgressComplaints(fromOfficerId);
      
      for (var complaint in complaints) {
        await _db
            .collection('complaints')
            .doc(complaint['complaintId'])
            .update({
              'assignedTo': toOfficerId,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('Error reassigning complaints: $e');
      rethrow;
    }
  }

  /// Delete an officer (after reassigning complaints)
  static Future<void> deleteOfficer(String officerId) async {
    try {
      // Delete from Firestore Users collection
      await _db.collection('Users').doc(officerId).delete();
    } catch (e) {
      print('Error deleting officer: $e');
      rethrow;
    }
  }

  /// Update officer role
  static Future<void> updateOfficerRole({
    required String officerId,
    required String newRole,
  }) async {
    try {
      await _db.collection('Users').doc(officerId).update({
        'officialRole': newRole,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating officer role: $e');
      rethrow;
    }
  }

  /// Update officer jurisdiction
  static Future<void> updateOfficerJurisdiction({
    required String officerId,
    required String role,
    required String newJurisdiction,
  }) async {
    try {
      String jField = role == 'AE' ? 'section' : 
                      role == 'AEE' ? 'subdivision' : 'division';
      
      await _db.collection('Users').doc(officerId).update({
        jField: newJurisdiction,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating officer jurisdiction: $e');
      rethrow;
    }
  }

  /// Get officer details by ID
  static Future<Map<String, dynamic>?> getOfficerById(String officerId) async {
    try {
      final doc = await _db.collection('Users').doc(officerId).get();
      if (doc.exists) {
        return {...doc.data()!, 'uid': doc.id};
      }
      return null;
    } catch (e) {
      print('Error fetching officer: $e');
      return null;
    }
  }
}
