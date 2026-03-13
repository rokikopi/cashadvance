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

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.color,
    this.isRead = false,
  });
}

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Separate lists for User and Admin notifications
  final List<AppNotification> _userNotifications = [];
  final List<AppNotification> _adminNotifications = [];

  // Getters for Users
  List<AppNotification> get notifications => _userNotifications;
  int get count => _userNotifications.where((n) => !n.isRead).length;

  // Getters for Admins (Matches the calls in your AdminPage)
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
    });
  }

  Future<void> markAsRead(String collection, String docId) async {
    await _db.collection(collection).doc(docId).update({'isRead': true});
  }

  // --- REAL-TIME LISTENERS ---

  void listenForUserUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
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
                color: const Color(0xFF2E5BFF),
              ),
            );
          }
          notifyListeners();
        });
  }

  // --- CLEAR ACTIONS ---

  void clearUserNotifications() {
    _userNotifications.clear();
    notifyListeners();
  }

  void clearAdminNotifications() {
    _adminNotifications.clear();
    notifyListeners();
  }
}
