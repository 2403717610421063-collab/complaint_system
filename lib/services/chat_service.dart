import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a message
  static Future<bool> sendMessage({
    required String complaintId,
    required String message,
    required String senderRole, // 'user' or 'support'
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get sender info
      final userDoc = await _firestore.collection('Users').doc(currentUser.uid).get();
      final senderName = userDoc['name'] ?? 'Unknown';
      final senderProfileImage = userDoc['url'];

      // Create message
      final chatMessage = ChatMessage(
        id: '',
        complaintId: complaintId,
        senderId: currentUser.uid,
        senderName: senderName,
        senderRole: senderRole,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
        senderProfileImage: senderProfileImage,
      );

      // Add to messages subcollection
      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .add(chatMessage.toMap());

      // Update chat thread
      final complaintDoc = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .get();

      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .update({
        'lastMessage': message,
        'lastMessageAt': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Get messages for a complaint (real-time)
  static Stream<List<ChatMessage>> getMessages(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Mark message as read
  static Future<void> markMessageAsRead(
      String complaintId,
      String messageId,
      ) async {
    try {
      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Mark all messages as read for a complaint
  static Future<void> markAllAsRead(String complaintId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final messages = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUser.uid)
          .get();

      for (var doc in messages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Get chat threads for user
  static Stream<List<ChatMessage>> getChatThreads(String userId) {
    return _firestore
        .collectionGroup('messages')
        .where('senderId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get unread message count for a complaint
  static Future<int> getUnreadCount(String complaintId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete a message
  static Future<bool> deleteMessage(String complaintId, String messageId) async {
    try {
      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Search messages
  static Future<List<ChatMessage>> searchMessages(
      String complaintId,
      String searchQuery,
      ) async {
    try {
      final snapshot = await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .where((msg) =>
          msg.message.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }
}