import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String complaintId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'user' or 'support'
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? senderProfileImage;

  ChatMessage({
    required this.id,
    required this.complaintId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.senderProfileImage,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'senderProfileImage': senderProfileImage,
    };
  }

  // Create from Firestore document
  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      complaintId: map['complaintId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      senderRole: map['senderRole'] ?? 'user',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      senderProfileImage: map['senderProfileImage'],
    );
  }
}

class ChatThread {
  final String id;
  final String complaintId;
  final String userId;
  final String assignedOfficerId;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String lastMessage;

  ChatThread({
    required this.id,
    required this.complaintId,
    required this.userId,
    required this.assignedOfficerId,
    required this.createdAt,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'userId': userId,
      'assignedOfficerId': assignedOfficerId,
      'createdAt': createdAt,
      'lastMessageAt': lastMessageAt,
      'unreadCount': unreadCount,
      'lastMessage': lastMessage,
    };
  }

  factory ChatThread.fromMap(Map<String, dynamic> map, String id) {
    return ChatThread(
      id: id,
      complaintId: map['complaintId'] ?? '',
      userId: map['userId'] ?? '',
      assignedOfficerId: map['assignedOfficerId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (map['lastMessageAt'] as Timestamp).toDate(),
      unreadCount: map['unreadCount'] ?? 0,
      lastMessage: map['lastMessage'] ?? '',
    );
  }
}