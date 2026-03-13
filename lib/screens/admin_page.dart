import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:cashadvance/services/notification_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Listen for new requests submitted by users
    _notificationService.listenForAdminUpdates();
  }

  // --- AUTH LOGIC ---

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // --- NOTIFICATION LOGIC (User Alerts) ---

  Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type, // e.g., 'Approved' or 'Rejected'
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _showAdminNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: _notificationService,
        builder: (context, child) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "New Requests",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                if (_notificationService.adminNotifications.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        _notificationService.clearAdminNotifications(),
                    child: const Text(
                      "Clear All",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _notificationService.adminNotifications.isEmpty
                  ? const Text("No unread alerts.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notificationService.adminNotifications.length,
                      itemBuilder: (context, index) {
                        final note =
                            _notificationService.adminNotifications[index];
                        return ListTile(
                          title: Text(
                            note.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            note.message,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            _notificationService.markAsRead(
                              'admin_notifications',
                              note.id,
                            );
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textMain,
          centerTitle: false,
          toolbarHeight: 90,
          leading: Padding(
            padding: const EdgeInsets.only(left: 15.0, top: 10.0, bottom: 10.0),
            child: Image.asset(
              'assets/images/logo.png',
              height: 65,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance_wallet,
                color: AppColors.primary,
                size: 40,
              ),
            ),
          ),
          leadingWidth: 80,
          title: Text(
            "Admin Dashboard",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            ListenableBuilder(
              listenable: _notificationService,
              builder: (context, child) {
                return IconButton(
                  icon: Badge(
                    label: Text(_notificationService.adminCount.toString()),
                    isLabelVisible: _notificationService.adminCount > 0,
                    child: const Icon(Icons.notifications_none_outlined),
                  ),
                  onPressed: () => _showAdminNotifications(context),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => _showLogoutConfirmation(context),
              tooltip: 'Logout',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("User Management"),
              _buildUserSection(context),
              const SizedBox(height: 24),
              _buildSectionHeader("Transaction History"),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.primary,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  tabs: const [
                    Tab(text: "Pending"),
                    Tab(text: "Approved"),
                    Tab(text: "Rejected"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 500,
                child: TabBarView(
                  children: [
                    _buildApplicationsSection(context, "Pending"),
                    _buildApplicationsSection(context, "Approved"),
                    _buildApplicationsSection(context, "Rejected"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- USER MANAGEMENT SECTION ---

  Widget _buildUserSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        final bool showAllButton = users.length > 2;
        final displayUsers = showAllButton ? users.take(2).toList() : users;

        return Column(
          children: [
            ...displayUsers.map((doc) => _buildUserCard(context, doc)),
            if (showAllButton)
              TextButton.icon(
                onPressed: () => _showAllUsersPopup(context, users),
                icon: const Icon(Icons.group, size: 18),
                label: const Text("View All Users"),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isAdmin = data['isAdmin'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1),
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: isAdmin ? Colors.amber : Colors.blue,
          ),
        ),
        title: Text(
          "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          data['email'] ?? 'No Email',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          onPressed: () => _showEditUserPopup(context, doc.id, data),
        ),
      ),
    );
  }

  // --- APPLICATIONS SECTION ---

  Widget _buildApplicationsSection(BuildContext context, String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('status', isEqualTo: statusFilter)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No $statusFilter applications");
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildApplicationCard(context, doc.id, data, statusFilter);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String status,
  ) {
    final String fundClass = "Class ${data['fundClassification'] ?? '1'}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "REF: ${data['referenceId'] ?? 'N/A'}",
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fundClass,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['userId'])
                      .get(),
                  builder: (context, userSnap) {
                    final name = userSnap.hasData
                        ? "${userSnap.data!['firstName'] ?? ''} ${userSnap.data!['lastName'] ?? ''}"
                        : "Loading...";
                    return Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  "₱${NumberFormat('#,##0.00').format(data['amount'])}",
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  data['purpose'] ?? 'No purpose provided',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (status == "Pending") ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
              onPressed: () => _confirmAction(context, docId, data, "Approved"),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 32),
              onPressed: () => _confirmAction(context, docId, data, "Rejected"),
            ),
          ] else
            Icon(
              status == "Approved" ? Icons.verified : Icons.error_outline,
              color: status == "Approved" ? Colors.green : Colors.redAccent,
              size: 24,
            ),
        ],
      ),
    );
  }

  // --- DIALOGS & ACTIONS ---

  void _confirmAction(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String status,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$status Application?"),
        content: Text("Mark this request as $status?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('advances')
                  .doc(docId)
                  .update({
                    'status': status,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

              final String amount = NumberFormat(
                '#,##0.00',
              ).format(data['amount']);
              final String ref = data['referenceId'] ?? 'N/A';

              await _sendNotificationToUser(
                userId: data['userId'],
                title: "Application $status",
                message: status == "Approved"
                    ? "Your request for ₱$amount (REF: $ref) has been approved."
                    : "Your request for ₱$amount (REF: $ref) was rejected.",
                type: status,
              );

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              "Yes, $status",
              style: TextStyle(
                color: status == "Approved" ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllUsersPopup(
    BuildContext context,
    List<QueryDocumentSnapshot> users,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("All Users"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) =>
                _buildUserCard(context, users[index]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showEditUserPopup(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
  ) {
    final fName = TextEditingController(text: data['firstName'] ?? '');
    final lName = TextEditingController(text: data['lastName'] ?? '');
    final empId = TextEditingController(text: data['employeeId'] ?? '');
    final dept = TextEditingController(text: data['department'] ?? '');
    final pos = TextEditingController(text: data['position'] ?? '');
    bool isAdmin = data['isAdmin'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit User Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(fName, "First Name"),
                _buildEditField(lName, "Last Name"),
                _buildEditField(empId, "Employee ID"),
                _buildEditField(dept, "Department"),
                _buildEditField(pos, "Position"),
                SwitchListTile(
                  title: const Text("Admin Access"),
                  value: isAdmin,
                  onChanged: (v) => setState(() => isAdmin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                      'firstName': fName.text.trim(),
                      'lastName': lName.text.trim(),
                      'employeeId': empId.text.trim(),
                      'department': dept.text.trim(),
                      'position': pos.text.trim(),
                      'isAdmin': isAdmin,
                    });
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Exit the Admin Dashboard?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => _handleLogout(context),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Text(
      title,
      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildEmptyState(String message) => Center(
    child: Text(message, style: const TextStyle(color: Colors.grey)),
  );
}
