import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String content;
  final DateTime? sentAt;
  final bool isRead;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.content,
    this.sentAt,
    this.isRead = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      messageId: doc.id,
      senderId: data['sender_id'] as String? ?? '',
      content: data['content'] as String? ?? '',
      sentAt: (data['sent_at'] as Timestamp?)?.toDate(),
      isRead: data['is_read'] as bool? ?? false,
    );
  }
}
