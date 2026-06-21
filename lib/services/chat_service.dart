import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // bikin dokumen chats/{orderId} kalau belum ada (lazy, pakai merge)
  Future<void> ensureChatExists({
    required String orderId,
    required String customerId,
    required String driverId,
  }) async {
    try {
      final docRef = _db.collection('chats').doc(orderId);
      final doc = await docRef.get();
      if (doc.exists) return;

      await docRef.set({
        'order_id': orderId,
        'customer_id': customerId,
        'driver_id': driverId,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Gagal menyiapkan ruang chat: $e');
    }
  }

  // kirim pesan baru ke subcollection messages
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return;

    try {
      await _db.collection('chats').doc(orderId).collection('messages').add({
        'sender_id': senderId,
        'content': text,
        'sent_at': FieldValue.serverTimestamp(),
        'is_read': false,
      });
    } catch (e) {
      throw Exception('Gagal mengirim pesan: $e');
    }
  }

  // listen pesan real-time, urut sent_at ascending (single field, no index)
  Stream<List<MessageModel>> watchMessages(String orderId) {
    return _db
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // tandai pesan yang BUKAN dari currentUserId jadi is_read = true
  Future<void> markMessagesAsRead({
    required String orderId,
    required String currentUserId,
  }) async {
    try {
      final snapshot = await _db
          .collection('chats')
          .doc(orderId)
          .collection('messages')
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        final senderId = doc.data()['sender_id'] as String? ?? '';
        if (senderId != currentUserId) {
          batch.update(doc.reference, {'is_read': true});
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Gagal menandai pesan dibaca: $e');
    }
  }
}
