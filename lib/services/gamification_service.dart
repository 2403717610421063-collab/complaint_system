import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:complaint_system/models/user_model.dart';
import 'package:complaint_system/services/user_collection_bridge.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserCollectionBridge _userBridge = UserCollectionBridge();

  // Award points when a complaint is resolved
  Future<void> awardPointsForResolution(String userId) async {
    try {
      final userRef = await _userBridge.findUserRefById(userId);
      if (userRef == null) {
        debugPrint("❌ User not found for points award: $userId");
        return;
      }

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) return;

        final currentPoints = (snapshot.data()?['points'] ?? 0) as int;

        transaction.update(userRef, {
          'points': currentPoints + 50,
        });
      });

      debugPrint("✅ Points awarded to user $userId");
    } catch (e) {
      debugPrint("❌ Error awarding points: $e");
    }
  }

  // Stream of top users for the leaderboard
  Stream<List<UserModel>> getLeaderboard() {
    return _db
        .collection('Users')
        .orderBy('points', descending: true)
        .limit(10)
        .snapshots()
        .handleError((e) {
      debugPrint("❌ Firestore Leaderboard Error: $e");
    })
        .map((snapshot) {
      debugPrint("📦 Leaderboard docs: ${snapshot.docs.length}");

      return snapshot.docs.map((doc) {
        debugPrint("👤 User data: ${doc.data()}");
        return UserModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

}
