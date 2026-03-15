import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final Color color;
  final bool isRead;
  final bool isCleared;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.color,
    this.isRead = false,
    this.isCleared = false,
  });
}

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<AppNotification> _userNotifications = [];
  final List<AppNotification> _adminNotifications = [];

  List<AppNotification> get notifications => _userNotifications;
  int get count => _userNotifications.where((n) => !n.isRead).length;

  List<AppNotification> get adminNotifications => _adminNotifications;
  int get adminCount => _adminNotifications.where((n) => !n.isRead).length;

  // --- DATABASE ACTIONS ---

  Future<void> notifyAdminOfNewRequest({
    required String requesterName,
    required double amount,
  }) async {
    await _db.collection('admin_notifications').add({
      'title': "New Advance Request",
      'message':
          "$requesterName submitted a request for ₱${amount.toStringAsFixed(2)}.",
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isCleared': false,
    });
  }

  Future<void> notifyUserOfStatusChange({
    required String userId,
    required String status,
    required double amount,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'title': "Request $status",
      'message':
          "Your advance request for ₱${amount.toStringAsFixed(2)} has been $status.",
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isCleared': false,
    });
  }

  Future<void> markAsRead(String collection, String docId) async {
    await _db.collection(collection).doc(docId).update({'isRead': true});
  }

  // --- BATCH UPDATES (Restored and Corrected Names) ---

  /// Marks all current user notifications as read in Firestore
  Future<void> markAllUserRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshots = await _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .where('isCleared', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Marks all admin notifications as read in Firestore
  Future<void> markAllAdminRead() async {
    final snapshots = await _db
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .where('isCleared', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Sets isCleared: true for all user notifications (Used by Home Page)
  Future<void> clearUserNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshots = await _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isCleared', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isCleared': true});
    }
    await batch.commit();
  }

  /// Sets isCleared: true for all admin notifications (Used by Admin Page)
  Future<void> clearAdminNotifications() async {
    final snapshots = await _db
        .collection('admin_notifications')
        .where('isCleared', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;
    final batch = _db.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isCleared': true});
    }
    await batch.commit();
  }

  // --- REAL-TIME LISTENERS ---

  void listenForUserUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isCleared', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _userNotifications.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'pending';
            _userNotifications.add(
              AppNotification(
                id: doc.id,
                title: data['title'] ?? 'Update',
                message: data['message'] ?? '',
                timestamp:
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                isRead: data['isRead'] ?? false,
                isCleared: data['isCleared'] ?? false,
                color: status.toString().toLowerCase() == 'approved'
                    ? Colors.green
                    : Colors.red,
              ),
            );
          }
          notifyListeners();
        });
  }

  void listenForAdminUpdates() {
    _db
        .collection('admin_notifications')
        .where('isCleared', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          _adminNotifications.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _adminNotifications.add(
              AppNotification(
                id: doc.id,
                title: data['title'] ?? 'New Request',
                message: data['message'] ?? '',
                timestamp:
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                isRead: data['isRead'] ?? false,
                isCleared: data['isCleared'] ?? false,
                color: const Color(0xFF2E5BFF),
              ),
            );
          }
          notifyListeners();
        });
  }
}
