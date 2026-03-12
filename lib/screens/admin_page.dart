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
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // For Pending, Approved, Rejected
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
              // --- TAB BAR FOR FILTERING ---
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
              // --- TAB BAR VIEW CONTENT ---
              SizedBox(
                height: 500, // Fixed height for the scrollable list area
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

  // --- APPLICATIONS SECTION (UPDATED) ---

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
                // Display Reference ID
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
                const SizedBox(height: 6),
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
          // Actions: Only show approve/reject buttons if the status is currently Pending
          if (status == "Pending") ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
              onPressed: () => _confirmAction(context, docId, "Approved"),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 32),
              onPressed: () => _confirmAction(context, docId, "Rejected"),
            ),
          ] else ...[
            // For Approved/Rejected, show a simple status icon
            Icon(
              status == "Approved" ? Icons.verified : Icons.error_outline,
              color: status == "Approved" ? Colors.green : Colors.redAccent,
              size: 24,
            ),
          ],
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
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
