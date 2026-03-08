import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashadvance/services/auth_service.dart';
import 'package:cashadvance/theme/constants.dart';

// PDF and Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // --- HELPER: Generate 8-digit unique ID ---
  String _generateReferenceId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      8,
      (index) => chars[Random().nextInt(chars.length)],
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        String userName = "User";
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          userName = userData['firstName'] ?? "User";
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showApplyPopup(context, uid),
            backgroundColor: AppColors.primary,
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  centerTitle: true,
                  toolbarHeight: 90,
                  expandedHeight: 110,
                  title: Padding(
                    padding: const EdgeInsets.only(top: 15.0),
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
                          offset: const Offset(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          onSelected: (value) async {
                            if (value == 'logout') await authService.signOut();
                          },
                          itemBuilder: (context) => _buildMenuItems(userName),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildResponsiveSummary(uid),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      "Recent Activity",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ),
                _buildSliverAdvanceList(uid),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI: MENU ITEMS ---
  List<PopupMenuEntry<String>> _buildMenuItems(String name) {
    return [
      PopupMenuItem<String>(
        enabled: false,
        child: Text(
          "Hi, $name",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: [
            Icon(Icons.logout, size: 18, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Log Out"),
          ],
        ),
      ),
    ];
  }

  // --- UI: SUMMARY CARDS ---
  Widget _buildResponsiveSummary(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        double totalApproved = 0;
        int pendingCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'Approved') {
              totalApproved += double.tryParse(data['amount'].toString()) ?? 0;
            } else if (data['status'] == 'Pending') {
              pendingCount++;
            }
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isSmall = constraints.maxWidth < 360;
            return isSmall
                ? Column(
                    children: [
                      _summaryCard(
                        "Total Approved",
                        "₱${NumberFormat('#,##0.00').format(totalApproved)}",
                        Icons.payments,
                        AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      _summaryCard(
                        "Pending Requests",
                        pendingCount.toString(),
                        Icons.history,
                        Colors.orange,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          "Total Approved",
                          "₱${NumberFormat('#,##0.00').format(totalApproved)}",
                          Icons.payments,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          "Pending",
                          pendingCount.toString(),
                          Icons.history,
                          Colors.orange,
                        ),
                      ),
                    ],
                  );
          },
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: ADVANCE LIST ---
  Widget _buildSliverAdvanceList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildAdvanceCard(context, data, doc.id);
            }, childCount: snapshot.data!.docs.length),
          ),
        );
      },
    );
  }

  Widget _buildAdvanceCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    String status = data['status'] ?? 'Pending';
    Color statusColor = status == 'Approved'
        ? Colors.green
        : (status == 'Rejected' ? Colors.redAccent : Colors.orange);
    String refId = data['referenceId'] ?? '--------';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "₱${NumberFormat('#,##0.00').format(data['amount'])}",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            Text(
              refId,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fund Class: ${data['fundClassification'] ?? 'N/A'}",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            Text(
              data['purpose'] ?? "No purpose",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              data['createdAt'] != null
                  ? DateFormat(
                      'MM/dd/yyyy',
                    ).format((data['createdAt'] as Timestamp).toDate())
                  : "",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (status == 'Pending' || status == 'Rejected')
              IconButton(
                icon: Icon(
                  status == 'Rejected' ? Icons.refresh : Icons.edit_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
                onPressed: () => _showApplyPopup(
                  context,
                  data['userId'],
                  editDocId: docId,
                  existingData: data,
                ),
              ),
            if (status == 'Approved') ...[
              IconButton(
                icon: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
                onPressed: () => _generatePDF(data, action: 'download'),
              ),
              IconButton(
                icon: const Icon(
                  Icons.print_outlined,
                  color: Colors.green,
                  size: 20,
                ),
                onPressed: () => _generatePDF(data, action: 'print'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- LOGIC: PDF GENERATION (UPDATED) ---
  Future<void> _generatePDF(
    Map<String, dynamic> data, {
    String action = 'print',
  }) async {
    final pdf = pw.Document();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(data['userId'])
        .get();
    final userData = userDoc.data() ?? {};

    final String employeeName =
        "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}";
    final String employeeId = userData['employeeId']?.toString() ?? "N/A";
    final String refId = data['referenceId'] ?? 'N/A';
    final String fundClass = data['fundClassification'] ?? 'N/A';
    final String dateStr = data['createdAt'] != null
        ? DateFormat(
            'MM/dd/yyyy',
          ).format((data['createdAt'] as Timestamp).toDate())
        : 'N/A';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "CASH ADVANCE REQUEST",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "REF: $refId",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _pdfLabelValue("EMPLOYEE:", employeeName),
                        _pdfLabelValue("EMP NO:", employeeId),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfLabelValue("FUND CLASS:", fundClass),
                        _pdfLabelValue("DATE:", dateStr),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            "PURPOSE DESCRIPTION",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            "AMOUNT",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(data['purpose'] ?? ""),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "PHP ${NumberFormat('#,##0.00').format(data['amount'])}",
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                // --- Updated Signature Block Section ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfSignatureBlock(
                      "Requested by:",
                      "Name & Signature of Employee",
                    ),
                    _pdfSignatureBlock("Checked by:", "Department Head"),
                  ],
                ),
                pw.SizedBox(height: 30),
                _pdfSignatureBlock(
                  "Released by:",
                  "Disbursing Officer / Cashier",
                ),
              ],
            ),
          );
        },
      ),
    );

    if (action == 'print') {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Advance_$refId.pdf',
      );
    }
  }

  // --- UI: FORM MODAL ---
  void _showApplyPopup(
    BuildContext context,
    String uid, {
    String? editDocId,
    Map<String, dynamic>? existingData,
  }) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};

    final amountController = TextEditingController(
      text: existingData != null ? existingData['amount'].toString() : "",
    );
    final purposeController = TextEditingController(
      text: existingData != null ? existingData['purpose'] : "",
    );

    String selectedFundClass = existingData?['fundClassification'] ?? '1';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  editDocId == null ? "Apply for Advance" : "Edit Request",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (existingData?['referenceId'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Reference: ${existingData!['referenceId']}",
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                _infoRow(
                  "Employee",
                  "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}",
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: selectedFundClass,
                  decoration: _inputStyle("Fund Classification"),
                  items: ['1', '2', '3']
                      .map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text("Fund Class $val"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setModalState(() => selectedFundClass = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputStyle("Amount (₱)"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purposeController,
                  maxLines: 2,
                  decoration: _inputStyle("Purpose"),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _submit(
                      context,
                      uid,
                      amountController.text,
                      purposeController.text,
                      selectedFundClass,
                      editDocId: editDocId,
                      existingStatus: existingData?['status'],
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- LOGIC: SUBMISSION ---
  Future<void> _submit(
    BuildContext context,
    String uid,
    String amount,
    String purpose,
    String fundClass, {
    String? editDocId,
    String? existingStatus,
  }) async {
    if (amount.isEmpty || purpose.isEmpty) return;

    final data = {
      'userId': uid,
      'amount': double.tryParse(amount) ?? 0,
      'purpose': purpose,
      'fundClassification': fundClass,
      'status': 'Pending',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (editDocId == null || existingStatus == 'Rejected') {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['referenceId'] = _generateReferenceId();
      await FirebaseFirestore.instance.collection('advances').add(data);
    } else {
      await FirebaseFirestore.instance
          .collection('advances')
          .doc(editDocId)
          .update(data);
    }

    if (context.mounted) Navigator.pop(context);
  }

  // --- SHARED UI HELPERS ---
  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(
          "No applications found.",
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Text(
      "$label: $value",
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
  );

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: "$label ",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfSignatureBlock(String label, String subLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 25),
        pw.Container(
          width: 180,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 1),
            ),
          ),
        ),
        if (subLabel.isNotEmpty)
          pw.Text(subLabel, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
