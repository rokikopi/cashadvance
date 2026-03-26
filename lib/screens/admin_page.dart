import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:cashadvance/services/notification_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  // --- PDF GENERATION METHODS ---

  String _numberToWords(int number) {
    if (number == 0) return "ZERO";
    final units = [
      "",
      "ONE",
      "TWO",
      "THREE",
      "FOUR",
      "FIVE",
      "SIX",
      "SEVEN",
      "EIGHT",
      "NINE",
      "TEN",
      "ELEVEN",
      "TWELVE",
      "THIRTEEN",
      "FOURTEEN",
      "FIFTEEN",
      "SIXTEEN",
      "SEVENTEEN",
      "EIGHTEEN",
      "NINETEEN",
    ];
    final tens = [
      "",
      "",
      "TWENTY",
      "THIRTY",
      "FORTY",
      "FIFTY",
      "SIXTY",
      "SEVENTY",
      "EIGHTY",
      "NINETY",
    ];

    if (number < 20) return units[number];
    if (number < 100) {
      return "${tens[number ~/ 10]} ${units[number % 10]}".trim();
    }
    if (number < 1000) {
      return "${units[number ~/ 100]} HUNDRED ${_numberToWords(number % 100)}"
          .trim();
    }
    if (number < 1000000) {
      return "${_numberToWords(number ~/ 1000)} THOUSAND ${_numberToWords(number % 1000)}"
          .trim();
    }
    return number.toString();
  }

  String _getFundClassificationText(int? fundClass) {
    switch (fundClass) {
      case 1:
        return "CLASS 1";
      case 2:
        return "CLASS 2";
      case 3:
        return "CLASS 3";
      default:
        return "CLASS 1";
    }
  }

  Future<void> _generatePDF(
    Map<String, dynamic> data, {
    String action = 'print',
  }) async {
    final pdf = pw.Document();

    // Fetch user details for the "Pay to" section
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(data['userId'])
        .get();
    final userData = userDoc.data() ?? {};
    final String employeeName =
        "${userData['lastName'] ?? ''}, ${userData['firstName'] ?? ''}"
            .toUpperCase();
    final String userPosition = userData['position'] ?? "S.L.T. ASSISTANT";

    final String dateStr = data['createdAt'] != null
        ? DateFormat(
            'd-MMM-yy',
          ).format((data['createdAt'] as Timestamp).toDate())
        : 'N/A';

    final String refId = data['referenceId'] ?? "N/A";
    final int fundClass = data['fundClassification'] ?? 1;
    final String fundType = _getFundClassificationText(fundClass);

    double amount = double.tryParse(data['amount'].toString()) ?? 0;
    double totalVatAmount = 0;

    List<dynamic> items = data['items'] ?? [];

    // Calculate VAT for each item and total
    List<Map<String, dynamic>> itemsWithVat = [];
    for (var item in items) {
      double itemAmount = item['amount'] ?? 0;
      double itemVat = (itemAmount * 0.12) / 1.12;
      double itemNet = itemAmount - itemVat;
      totalVatAmount += itemVat;
      itemsWithVat.add({
        'description': item['description'],
        'grossAmount': itemAmount,
        'vatAmount': itemVat,
        'netAmount': itemNet,
      });
    }

    String amountInWords = "${_numberToWords(amount.round())} PESOS ONLY";

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
                // Header with Fund Type
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      fundType,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(),
                  ],
                ),
                pw.SizedBox(height: 20),
                _pdfRow("Pay to", employeeName),
                pw.SizedBox(height: 3),
                // Show items list
                if (items.isNotEmpty) ...[
                  _pdfRow("Items", ""),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    margin: const pw.EdgeInsets.only(left: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: items.asMap().entries.map((entry) {
                        int idx = entry.key + 1;
                        Map<String, dynamic> item = entry.value;
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            children: [
                              pw.SizedBox(width: 30, child: pw.Text("$idx.")),
                              pw.Expanded(
                                child: pw.Text(
                                  "${item['description']} - P${NumberFormat('#,##0.00').format(item['amount'])}",
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                pw.SizedBox(height: 3),
                _pdfRow("Amt in Words", amountInWords),
                pw.SizedBox(height: 3),
                _pdfRow(
                  "Total Amount",
                  "P${NumberFormat('#,##0.00').format(amount)}",
                ),
                pw.SizedBox(height: 15),

                // No. and Date row with Reference ID
                pw.Row(
                  children: [
                    pw.Text(
                      "No. : ",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(refId),
                    pw.SizedBox(width: 30),
                    pw.Text(
                      "Date : ",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(dateStr),
                  ],
                ),
                pw.SizedBox(height: 20),
                _buildPdfTable(itemsWithVat, totalVatAmount, amount),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signatureBlock(
                      "PREPARED BY:",
                      "$employeeName\n$userPosition",
                    ),
                    _signatureBlock(
                      "CHECKED BY:",
                      "DE VILLA, JOANA PAR\nSENIOR FINANCE MANAGER",
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    _signatureBlock(
                      "APPROVED BY:",
                      "DE VILLA, JOANA PAR\nSENIOR FINANCE MANAGER",
                    ),
                  ],
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
        filename: 'PettyCash_${data['referenceId']}.pdf',
      );
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(": "),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTable(
    List<Map<String, dynamic>> itemsWithVat,
    double totalVatAmount,
    double totalAmount,
  ) {
    List<pw.TableRow> rows = [];

    // Header row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _tableCell("Act Code", bold: true),
          _tableCell("Act Name", bold: true),
          _tableCell("Debit", bold: true, align: pw.TextAlign.right),
          _tableCell("Credit", bold: true, align: pw.TextAlign.right),
        ],
      ),
    );

    // Add VAT input row at the top
    rows.add(
      pw.TableRow(
        children: [
          _tableCell("vat input"),
          _tableCell(""),
          _tableCell(
            "P${NumberFormat('#,##0.00').format(totalVatAmount)}",
            align: pw.TextAlign.right,
          ),
          _tableCell(""),
        ],
      ),
    );

    // Add each item as a row
    for (var item in itemsWithVat) {
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(""),
            _tableCell(item['description']),
            _tableCell(
              "P${NumberFormat('#,##0.00').format(item['netAmount'])}",
              align: pw.TextAlign.right,
            ),
            _tableCell(""),
          ],
        ),
      );
    }

    // Add Total Credit row
    rows.add(
      pw.TableRow(
        children: [
          _tableCell(""),
          _tableCell(""),
          _tableCell(""),
          _tableCell(
            "P${NumberFormat('#,##0.00').format(totalAmount)}",
            align: pw.TextAlign.right,
          ),
        ],
      ),
    );

    // Add Total row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _tableCell("TOTAL", bold: true),
          _tableCell(""),
          _tableCell(
            "P${NumberFormat('#,##0.00').format(totalAmount)}",
            bold: true,
            align: pw.TextAlign.right,
          ),
          _tableCell(
            "P${NumberFormat('#,##0.00').format(totalAmount)}",
            bold: true,
            align: pw.TextAlign.right,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _signatureBlock(String title, String name) {
    List<String> lines = name.split('\n');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Container(width: 200, child: pw.Text("_________________________")),
        pw.SizedBox(height: 5),
        for (var line in lines)
          pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // --- TRANSACTION DETAILS MODAL ---

  void _showTransactionDetails(Map<String, dynamic> data) {
    final String refId = data['referenceId'] ?? "N/A";
    final String status = data['status'] ?? 'Pending';
    final String fundDisplay = "Class ${data['fundClassification'] ?? '1'}";
    final double amount = double.tryParse(data['amount'].toString()) ?? 0;
    final String dateStr = data['createdAt'] != null
        ? DateFormat(
            'MM/dd/yyyy hh:mm a',
          ).format((data['createdAt'] as Timestamp).toDate())
        : 'N/A';

    List<dynamic> items = data['items'] ?? [];

    Color statusColor = status == 'Approved'
        ? Colors.green
        : (status == 'Rejected' ? Colors.redAccent : Colors.orange);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Transaction Details",
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Reference: $refId",
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              _detailRow("Date", dateStr),
                              const Divider(height: 12),
                              _detailRow("Fund Classification", fundDisplay),
                              const Divider(height: 12),
                              _detailRow(
                                "Total Amount",
                                "P${NumberFormat('#,##0.00').format(amount)}",
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Items Section
                        Text(
                          "Items/Particulars",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "No items listed",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final itemAmount = item['amount'] ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "${index + 1}",
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['description'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: AppColors.textMain,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Amount: P${NumberFormat('#,##0.00').format(itemAmount)}",
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Total Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "GRAND TOTAL:",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain,
                                ),
                              ),
                              Text(
                                "P${NumberFormat('#,##0.00').format(amount)}",
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                // Close button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Close",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? AppColors.textMain,
          ),
        ),
      ],
    );
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
      'type': type,
      'isRead': false,
      'isCleared': false,
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
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "New Requests",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (_notificationService.adminNotifications.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _notificationService.markAllAdminRead(),
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text(
                            "Read All",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _notificationService.clearAdminNotifications(),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            "Clear All",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _notificationService.adminNotifications.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No unread alerts",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notificationService.adminNotifications.length,
                      itemBuilder: (context, index) {
                        final note =
                            _notificationService.adminNotifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: note.color.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person_outline,
                              color: note.color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: note.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
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
                    backgroundColor: Colors.red,
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

    // Get items display
    String purposeDisplay = '';
    List<dynamic> items = data['items'] ?? [];
    if (items.isNotEmpty) {
      int itemCount = items.length;
      purposeDisplay = "$itemCount item(s)";
      if (itemCount == 1) {
        purposeDisplay = items[0]['description'];
      }
    } else if (data['purpose'] != null) {
      purposeDisplay = data['purpose'];
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(data),
      child: Container(
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
                    purposeDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (status == "Pending") ...[
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                    onPressed: () =>
                        _confirmAction(context, docId, data, "Approved"),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.cancel,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    onPressed: () =>
                        _confirmAction(context, docId, data, "Rejected"),
                  ),
                ] else if (status == "Approved") ...[
                  IconButton(
                    tooltip: 'Print PDF',
                    icon: const Icon(
                      Icons.print_outlined,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () => _generatePDF(data, action: 'print'),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Colors.blue,
                      size: 28,
                    ),
                    onPressed: () => _generatePDF(data, action: 'download'),
                  ),
                  Icon(Icons.verified, color: Colors.green, size: 24),
                ] else
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
              ],
            ),
          ],
        ),
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
