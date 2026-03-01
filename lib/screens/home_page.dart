import 'package:intl/intl.dart'; // Add this to your pubspec.yaml for date formatting
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashadvance/services/auth_service.dart';
import 'package:cashadvance/theme/constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      // 1. ACTION BUTTON TO APPLY
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyPopup(context, uid),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Apply Now",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            centerTitle: true,
            toolbarHeight: 100,
            expandedHeight: 120,
            title: Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                ),
              ),
            ),
            actions: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.menu,
                      color: AppColors.textMain,
                      size: 28,
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') await authService.signOut();
                    },
                    itemBuilder: (context) => _buildMenuItems(uid),
                  ),
                ),
              ),
            ],
          ),

          // 2. DASHBOARD CONTENT & LIST OF ADVANCES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Your Cash Advances",
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildAdvanceList(uid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildAdvanceList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      // Listening to the 'advances' collection for this specific user
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildAdvanceCard(data);
          },
        );
      },
    );
  }

  Widget _buildAdvanceCard(Map<String, dynamic> data) {
    Color statusColor;
    switch (data['status']) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.orange; // Pending
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          "₱${data['amount']}",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['purpose'] ?? "No purpose provided"),
            const SizedBox(height: 4),
            Text(
              DateFormat(
                'MMM dd, yyyy',
              ).format((data['createdAt'] as Timestamp).toDate()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            data['status'],
            style: GoogleFonts.inter(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              "No active cash advances found.",
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // --- APPLICATION POPUP ---

  void _showApplyPopup(BuildContext context, String uid) async {
    // 1. Fetch User Data for Autofill
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};

    final amountController = TextEditingController();
    final purposeController = TextEditingController();
    final String currentDate = DateFormat(
      'MMMM dd, yyyy',
    ).format(DateTime.now());

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 25,
          right: 25,
          top: 25,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "New Cash Advance",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Autofilled Info (Read Only)
              _readOnlyField(
                "Employee",
                "${userData['firstName']} ${userData['lastName']}",
              ),
              _readOnlyField(
                "ID & Dept",
                "${userData['employeeId']} | ${userData['department']}",
              ),
              _readOnlyField("Date", currentDate),

              const SizedBox(height: 15),

              // Input Fields
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: _inputStyle("Amount (₱)", Icons.money),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: purposeController,
                maxLines: 3,
                decoration: _inputStyle(
                  "Purpose of Cash Advance",
                  Icons.description,
                ),
              ),

              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _submitApplication(
                    context,
                    uid,
                    amountController.text,
                    purposeController.text,
                  ),
                  child: Text(
                    "Submit Request",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitApplication(
    BuildContext context,
    String uid,
    String amount,
    String purpose,
  ) async {
    if (amount.isEmpty || purpose.isEmpty) return;

    await FirebaseFirestore.instance.collection('advances').add({
      'userId': uid,
      'amount': amount,
      'purpose': purpose,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) Navigator.pop(context);
  }

  // --- HELPERS ---

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        "$label: $value",
        style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(String uid) {
    return [
      PopupMenuItem<String>(
        enabled: false,
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snapshot) {
            String firstName = snapshot.hasData
                ? (snapshot.data!['firstName'] ?? "User")
                : "User";
            return Text(
              "Hi, $firstName",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'logout', child: Text("Log Out")),
    ];
  }
}
