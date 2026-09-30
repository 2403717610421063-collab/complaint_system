import 'package:cloud_firestore/cloud_firestore.dart';

class UserCollectionBridge {
  UserCollectionBridge({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DocumentReference<Map<String, dynamic>>?> findUserRefById(String uid) async {
    final usersRef = _firestore.collection('Users').doc(uid);
    final usersSnapshot = await usersRef.get();
    if (usersSnapshot.exists) return usersRef;

    final lowerRef = _firestore.collection('users').doc(uid);
    final lowerSnapshot = await lowerRef.get();
    if (lowerSnapshot.exists) return lowerRef;

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findUserByEmail(String email) async {
    final usersQuery = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (usersQuery.docs.isNotEmpty) {
      return usersQuery.docs.first;
    }

    final lowerQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (lowerQuery.docs.isNotEmpty) {
      return lowerQuery.docs.first;
    }

    return null;
  }
}
