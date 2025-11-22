import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  factory AppNotification.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'info',
      title: data['title'] as String? ?? '알림',
      message: data['message'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userCollection(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items');
  }

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _userCollection(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AppNotification.fromDoc).toList(growable: false));
  }

  Future<void> markAllRead(String userId) async {
    final batch = _firestore.batch();
    final query =
        await _userCollection(userId).where('isRead', isEqualTo: false).get();
    if (query.docs.isEmpty) {
      return;
    }
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
  }) async {
    await _userCollection(userId).add({
      'type': type,
      'title': title,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return _userCollection(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
