import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashadvance/services/auth_service.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:cashadvance/services/notification_service.dart';

// PDF and Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NotificationService _notificationService = NotificationService();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _notificationService.listenForUserUpdates();
  }

  // Helper to show toast at top right
  void _showToast(String message, {bool isError = true}) {
    // Remove existing overlay if any
    _overlayEntry?.remove();

    // Create overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Add overlay to the current overlay state
    Overlay.of(context).insert(_overlayEntry!);

    // Auto remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  // 1. Helper to generate an 8-character clean reference ID
  String _generateCleanRefId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // 2. Helper function to convert number to words for the PDF
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

  // 3. Helper to get fund classification text
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

  // 4. Updated PDF Generation with Position and Department
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
    final String userPosition = userData['position'] ?? "";
    final String userDepartment = userData['department'] ?? "";

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

    double netAmount = amount - totalVatAmount;
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
                // Header with Fund Type on left
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
                    pw.SizedBox(), // Empty spacer
                  ],
                ),
                pw.SizedBox(height: 20),
                _pdfRow("Pay to", employeeName),
                pw.SizedBox(height: 3),
                if (userPosition.isNotEmpty)
                  _pdfRow("Position", userPosition),
                if (userDepartment.isNotEmpty)
                  _pdfRow("Department", userDepartment),
                pw.SizedBox(height: 5),
                // Show items list - WITHOUT AMOUNTS
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
                                  item['description'], // Only description, no amount
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
                _buildPdfTable(itemsWithVat, totalVatAmount, netAmount, amount),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signatureBlock(
                      "PREPARED BY:",
                      "$employeeName\n${userPosition.isNotEmpty ? userPosition : "EMPLOYEE"}\n${userDepartment.isNotEmpty ? userDepartment : ""}",
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
    double netAmount,
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

    // Add Total Credit row (shows total amount in credit column)
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

    // Add Total row (shows total in debit and credit)
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
    bool isCleared = data['isCleared'] ?? false;
    String? reason = data['reason'];

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
                              if (status == 'Approved') ...[
                                const Divider(height: 12),
                                _detailRow(
                                  "Clearance Status",
                                  isCleared ? "CLEARED" : "UNCLEARED",
                                  valueColor: isCleared
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Reason/Remarks Section
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.note_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Reason",
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reason,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

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

                        // Edit Button (if pending or rejected)
                        if (status == 'Pending' || status == 'Rejected')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context); // Close the details modal
                                  // Open the edit popup
                                  _showApplyPopup(
                                    context,
                                    data['userId'],
                                    editDocId: data['referenceId'] != null ? null : null,
                                    existingData: data,
                                  );
                                },
                                icon: Icon(
                                  status == 'Rejected' ? Icons.refresh : Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  status == 'Rejected' ? "Resubmit Application" : "Edit Request",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return ListenableBuilder(
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
                          "Notifications",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    if (_notificationService.notifications.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await _notificationService.markAllUserRead();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.done_all, size: 16),
                              label: const Text(
                                "Read All",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await _notificationService
                                    .clearUserNotifications();
                                setDialogState(() {});
                              },
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 16,
                                color: Colors.red,
                              ),
                              label: const Text(
                                "Clear All",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: _notificationService.notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_off_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No notifications",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _notificationService.notifications.length,
                          itemBuilder: (context, index) {
                            final note =
                                _notificationService.notifications[index];
                            return Dismissible(
                              key: Key(note.id),
                              onDismissed: (direction) async {
                                await _notificationService
                                    .clearUserNotifications();
                              },
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: note.color.withValues(
                                    alpha: 0.2,
                                  ),
                                  radius: 12,
                                  child: CircleAvatar(
                                    backgroundColor: note.color,
                                    radius: 6,
                                  ),
                                ),
                                title: Text(
                                  note.title,
                                  style: GoogleFonts.inter(
                                    fontWeight: note.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  note.message,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'hh:mm a',
                                      ).format(note.timestamp),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (!note.isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  await _notificationService.markAsRead(
                                    'notifications',
                                    note.id,
                                  );
                                  setDialogState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Close",
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

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
                ListenableBuilder(
                  listenable: _notificationService,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: IconButton(
                          icon: Badge(
                            label: Text(_notificationService.count.toString()),
                            isLabelVisible: _notificationService.count > 0,
                            backgroundColor: Colors.red,
                            child: const Icon(
                              Icons.notifications_none_outlined,
                              color: AppColors.textMain,
                              size: 26,
                            ),
                          ),
                          onPressed: () => _showNotificationDialog(context),
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, right: 8.0),
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
                        if (value == 'logout') {
                          await authService.signOut();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        }
                      },
                      itemBuilder: (context) => _buildMenuItems(uid),
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
  }

  Widget _buildResponsiveSummary(String uid) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

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

  Widget _buildSliverAdvanceList(String uid) {
    if (uid.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advances')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

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

    String fundDisplay = "Class ${data['fundClassification'] ?? '1'}";

    // Get display text from items or purpose
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
                data['referenceId'] ?? "",
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$fundDisplay • $purposeDisplay",
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
                  tooltip: status == 'Rejected'
                      ? 'Resubmit as New'
                      : 'Edit Application',
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
                  tooltip: 'Download PDF',
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                  onPressed: () => _generatePDF(data, action: 'download'),
                ),
                IconButton(
                  tooltip: 'Print PDF',
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
      ),
    );
  }

  void _showApplyPopup(
    BuildContext context,
    String uid, {
    String? editDocId,
    Map<String, dynamic>? existingData,
  }) async {
    if (uid.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? {};

    // Create controllers for items
    List<TextEditingController> descriptionControllers = [];
    List<TextEditingController> amountControllers = [];

    // Initialize items list and controllers
    List<Map<String, dynamic>> items = [];
    if (existingData != null && existingData['items'] != null) {
      items = List<Map<String, dynamic>>.from(existingData['items']);
    } else {
      items = [
        {'description': '', 'amount': 0.0},
      ];
    }

    // Create controllers for each item
    for (var item in items) {
      descriptionControllers.add(
        TextEditingController(text: item['description']),
      );
      amountControllers.add(
        TextEditingController(
          text: item['amount'] > 0 ? item['amount'].toString() : '',
        ),
      );
    }

    int selectedFundVal = existingData?['fundClassification'] ?? 1;
    
    // Add controller for reasons/remarks
    final TextEditingController reasonController = TextEditingController(
      text: existingData?['reason'] ?? '',
    );

    // Track items validation warning
    bool localShowItemsWarning = false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          bool localShowReasonWarning = false; // Local warning state for reason
          
          // Helper to add new item
          void addItem() {
            setModalState(() {
              items.add({'description': '', 'amount': 0.0});
              descriptionControllers.add(TextEditingController(text: ''));
              amountControllers.add(TextEditingController(text: ''));
            });
          }

          // Helper to remove item
          void removeItem(int index) {
            setModalState(() {
              // Dispose controllers before removing
              descriptionControllers[index].dispose();
              amountControllers[index].dispose();
              descriptionControllers.removeAt(index);
              amountControllers.removeAt(index);
              items.removeAt(index);
            });
          }

          // Helper to update item data from controllers
          void updateItemsFromControllers() {
            for (int i = 0; i < items.length; i++) {
              items[i]['description'] = descriptionControllers[i].text;
              items[i]['amount'] =
                  double.tryParse(amountControllers[i].text) ?? 0;
            }
          }

          // Calculate total amount
          updateItemsFromControllers();
          double totalAmount = items.fold(
            0,
            (total, item) => total + (item['amount'] ?? 0),
          );

          return Container(
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
                    editDocId == null
                        ? "Apply for Advance"
                        : (existingData?['status'] == 'Rejected'
                              ? "Resubmit Application"
                              : "Edit Request"),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _infoRow(
                    "Employee",
                    "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}",
                  ),
                  _infoRow(
                    "ID / Dept",
                    "${userData['employeeId'] ?? ''} | ${userData['department'] ?? ''}",
                  ),
                  const SizedBox(height: 15),
                  // Fund Classification Dropdown
                  DropdownButtonFormField<int>(
                    initialValue: selectedFundVal,
                    decoration: _inputStyle("Fund Classification"),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Class 1")),
                      DropdownMenuItem(value: 2, child: Text("Class 2")),
                      DropdownMenuItem(value: 3, child: Text("Class 3")),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedFundVal = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Items Header with Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Items/Particulars",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "*",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            " (Required)",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: addItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Item"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Dynamic Items List with Warning
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: localShowItemsWarning
                            ? Colors.red
                            : Colors.grey[200]!,
                        width: localShowItemsWarning ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...items.asMap().entries.map((entry) {
                          int index = entry.key;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Item ${index + 1}",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (items.length > 1)
                                      IconButton(
                                        onPressed: () => removeItem(index),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        color: Colors.red,
                                        tooltip: "Remove item",
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: descriptionControllers[index],
                                  decoration: InputDecoration(
                                    labelText: "Item Description",
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: localShowItemsWarning && descriptionControllers[index].text.trim().isEmpty
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.primary),
                                    ),
                                  ),
                                  maxLines: 2,
                                  onChanged: (_) {
                                    setModalState(() {
                                      updateItemsFromControllers();
                                      if (descriptionControllers[index].text.trim().isNotEmpty && 
                                          (amountControllers[index].text.trim().isNotEmpty && double.tryParse(amountControllers[index].text) != null && double.tryParse(amountControllers[index].text)! > 0)) {
                                        localShowItemsWarning = false;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: amountControllers[index],
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Amount (₱)",
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: localShowItemsWarning && (amountControllers[index].text.trim().isEmpty || double.tryParse(amountControllers[index].text) == 0)
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppColors.primary),
                                    ),
                                    prefixText: "₱ ",
                                    prefixStyle: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  onChanged: (_) {
                                    setModalState(() {
                                      updateItemsFromControllers();
                                      if (descriptionControllers[index].text.trim().isNotEmpty && 
                                          amountControllers[index].text.trim().isNotEmpty &&
                                          double.tryParse(amountControllers[index].text) != null &&
                                          double.tryParse(amountControllers[index].text)! > 0) {
                                        localShowItemsWarning = false;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        // Items Error Message
                        if (localShowItemsWarning)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Please add at least one item with description and amount greater than 0.",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Reasons/Remarks Field with Error Message INSIDE the red box
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Reason / Purpose",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "*",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              " (Required)",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            hintText: "Please provide a reason for this request (e.g., Urgent office supplies, Team building expenses, etc.)",
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          maxLines: 3,
                          maxLength: 500,
                          onChanged: (_) {
                            setModalState(() {
                              if (reasonController.text.trim().isNotEmpty) {
                                localShowReasonWarning = false;
                              }
                            });
                          },
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                            return Text(
                              "$currentLength/$maxLength",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                        ),
                        // Error Message INSIDE the red box below the field
                        if (localShowReasonWarning && reasonController.text.trim().isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, left: 4.0, right: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Please provide a reason for this request. This field is required.",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Total Amount Display
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount:",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          "₱${NumberFormat('#,##0.00').format(totalAmount)}",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Submit Button
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
                      onPressed: () {
                        // Validate at least one item has description and amount
                        updateItemsFromControllers();
                        bool hasValidItem = items.any(
                          (item) =>
                              item['description']
                                  .toString()
                                  .trim()
                                  .isNotEmpty &&
                              (item['amount'] ?? 0) > 0,
                        );

                        if (!hasValidItem) {
                          setModalState(() {
                            localShowItemsWarning = true;
                          });
                          _showToast("Please add at least one item with description and amount greater than 0");
                          return;
                        }

                        // Validate reason is provided
                        if (reasonController.text.trim().isEmpty) {
                          setModalState(() {
                            localShowReasonWarning = true;
                          });
                          _showToast("Please provide a reason for this request");
                          return;
                        }

                        _submit(
                          context,
                          uid,
                          totalAmount,
                          items,
                          selectedFundVal,
                          reason: reasonController.text.trim(),
                          editDocId: editDocId,
                          existingStatus: existingData?['status'],
                          existingRefId: existingData?['referenceId'],
                        );
                      },
                      child: Text(
                        editDocId == null
                            ? "Submit"
                            : (existingData?['status'] == 'Rejected'
                                  ? "Submit as New"
                                  : "Update Request"),
                        style: const TextStyle(
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
          );
        },
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    String uid,
    double totalAmount,
    List<Map<String, dynamic>> items,
    int fundClassification, {
    String? reason,
    String? editDocId,
    String? existingStatus,
    String? existingRefId,
  }) async {
    if (totalAmount <= 0) {
      _showToast("Please add at least one valid item with amount");
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final String fullName =
        "${userDoc.data()?['firstName'] ?? 'User'} ${userDoc.data()?['lastName'] ?? ''}";

    final data = {
      'userId': uid,
      'amount': totalAmount,
      'items': items,
      'fundClassification': fundClassification,
      'status': 'Pending',
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };

    try {
      if (editDocId == null || existingStatus == 'Rejected') {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['referenceId'] = _generateCleanRefId();

        if (existingStatus == 'Rejected') {
          data['resubmittedFrom'] = editDocId!;
        }

        await FirebaseFirestore.instance.collection('advances').add(data);

        await _notificationService.notifyAdminOfNewRequest(
          requesterName: fullName,
          amount: totalAmount,
        );
        
        // Close the popup and show success message
        if (context.mounted) {
          Navigator.pop(context);
          _showToast("Request submitted successfully!", isError: false);
        }
      } else {
        data['referenceId'] = existingRefId ?? _generateCleanRefId();
        await FirebaseFirestore.instance
            .collection('advances')
            .doc(editDocId)
            .update(data);
        
        if (context.mounted) {
          Navigator.pop(context);
          _showToast("Request updated successfully!", isError: false);
        }
      }
    } catch (e) {
      debugPrint("Error submitting: $e");
      _showToast("Error: $e");
    }
  }

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

  List<PopupMenuEntry<String>> _buildMenuItems(String uid) {
    return [
      PopupMenuItem(
        enabled: false,
        child: uid.isEmpty
            ? const Text("User")
            : FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
                builder: (context, snapshot) {
                  String name = "User";
                  if (snapshot.hasData && snapshot.data!.exists) {
                    name = snapshot.data!['firstName'] ?? "User";
                  }
                  return Text(
                    "Hi, $name",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  );
                },
              ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'logout', child: Text("Log Out")),
    ];
  }
}
