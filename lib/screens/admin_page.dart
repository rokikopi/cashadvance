import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashadvance/theme/constants.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  // --- AUTH LOGIC ---

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      // Navigates back to the root (AuthGate) which will show Login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
        centerTitle: false,
        // --- INCREASED TOOLBAR HEIGHT ---
        toolbarHeight: 90,
        // --- LOGO IN TOP LEFT ---
        leading: Padding(
          padding: const EdgeInsets.only(
            left: 15.0,
            top: 10.0,
            bottom: 10.0,
          ), // Adjust padding
          child: Image.asset(
            'assets/images/logo.png',
            height: 65, // --- ENLARGED LOGO ---
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.account_balance_wallet,
              color: AppColors.primary,
              size: 40,
            ),
          ),
        ),
        leadingWidth: 80, // Allow more width for the enlarged logo
        title: Text(
          "Admin Dashboard",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // --- LOGOUT BUTTON ---
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
            _buildSectionHeader("Pending Applications"),
            _buildApplicationsSection(context),
          ],
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

  Widget _buildApplicationsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('status', isEqualTo: 'Pending')
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
          return _buildEmptyState("No pending applications");
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildApplicationCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
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
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            onPressed: () => _confirmAction(context, docId, "Approved"),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 32),
            onPressed: () => _confirmAction(context, docId, "Rejected"),
          ),
        ],
      ),
    );
  }

  // --- POPUPS & DIALOGS ---

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
    final firstNameController = TextEditingController(
      text: data['firstName'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: data['lastName'] ?? '',
    );
    final employeeIdController = TextEditingController(
      text: data['employeeId'] ?? '',
    );
    final departmentController = TextEditingController(
      text: data['department'] ?? '',
    );
    final positionController = TextEditingController(
      text: data['position'] ?? '',
    );
    bool isAdmin = data['isAdmin'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            "Edit User Details",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEditField(firstNameController, "First Name"),
                  _buildEditField(lastNameController, "Last Name"),
                  _buildEditField(employeeIdController, "Employee ID"),
                  _buildEditField(departmentController, "Department"),
                  _buildEditField(positionController, "Position"),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        "Admin Access",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        isAdmin
                            ? "Has access to Dashboard"
                            : "Standard Employee",
                      ),
                      value: isAdmin,
                      activeThumbColor: Colors.amber,
                      onChanged: (val) => setState(() => isAdmin = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                      'firstName': firstNameController.text.trim(),
                      'lastName': lastNameController.text.trim(),
                      'employeeId': employeeIdController.text.trim(),
                      'department': departmentController.text.trim(),
                      'position': positionController.text.trim(),
                      'isAdmin': isAdmin,
                    });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                "Save Changes",
                style: TextStyle(color: Colors.white),
              ),
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
        content: const Text(
          "Are you sure you want to exit the Admin Dashboard?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout(context);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, String docId, String status) {
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
              if (context.mounted) Navigator.pop(context);
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

  // --- UI HELPERS ---

  Widget _buildEditField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textMain,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
