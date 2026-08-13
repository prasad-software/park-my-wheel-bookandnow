import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:mywheels/pageloader.dart';
import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';

class VendorPayment {
  final String id;
  final String orderId;
  final String parkingAmount;
  final String platformFee;
  final String gst;
  final List<String> tds;
  final String payableAmount;
  final String date;
  final String time;
  final String status;
  final String settlementId;
  final String bookingTotal;
  final List<dynamic> bookings;

  VendorPayment({
    required this.id,
    required this.orderId,
    required this.parkingAmount,
    required this.platformFee,
    required this.gst,
    required this.tds,
    required this.payableAmount,
    required this.date,
    required this.time,
    required this.status,
    required this.settlementId,
    required this.bookingTotal,
    required this.bookings,
  });

  factory VendorPayment.fromJson(Map<String, dynamic> json) {
    return VendorPayment(
      id: json['_id'] ?? 'N/A',
      orderId: json['orderid'] ?? 'N/A',
      parkingAmount: json['parkingamout']?.toString() ?? '0.00',
      platformFee: json['platformfee']?.toString() ?? '0.00',
      gst: json['gst']?.toString() ?? '0.00',
      tds: List<String>.from(json['tds']?.map((x) => x.toString()) ?? []),
      payableAmount: json['payableammout']?.toString() ?? '0.00',
      date: json['date'] ?? 'N/A',
      time: json['time'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      settlementId: json['settlementid'] ?? 'N/A',
      bookingTotal: json['bookingtotal']?.toString() ?? '0.00',
      bookings: json['bookings'] ?? [],
    );
  }
}

class vendorpayments extends StatefulWidget {
  final String vendorid;
  const vendorpayments({super.key, required this.vendorid});

  @override
  _vendorpaymentsState createState() => _vendorpaymentsState();
}

class _vendorpaymentsState extends State<vendorpayments> {
  bool isLoading = false;
  List<VendorPayment> settlements = [];

  @override
  void initState() {
    super.initState();
    fetchSettlements();
  }

  Future<void> fetchSettlements() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchsettlement/${widget.vendorid}'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> data = responseData['data'];

        setState(() {
          settlements = data.map((item) => VendorPayment.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Error fetching settlements')),
        // );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Vendor Settlements',
          style: GoogleFonts.poppins(
            fontSize: 18,
            // fontWeight: FontWeight.w600,
            color: Colors.black, // adjust color as needed
          ),
        ),
        backgroundColor: ColorUtils.secondarycolor(),
      ),
      body:
      isLoading
          ? const LoadingGif()
          :Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (settlements.isEmpty) // Check if settlements list is empty
              Expanded(
                child: Center(
                  child: Text(
                    'No vendor payouts',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: ColorUtils.primarycolor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                _buildTableHeader('S.No', 60),
                                _buildTableHeader('Order ID', 120),
                                _buildTableHeader('Date', 100),
                                _buildTableHeader('Time', 80),
                                _buildTableHeader('Parking Amt', 100),
                                _buildTableHeader('Platform Fee', 100),
                                _buildTableHeader('Receivable Amt', 120),
                                _buildTableHeader('Status', 100),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: settlements.asMap().entries.map((entry) {
                            int index = entry.key;
                            VendorPayment item = entry.value;
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VendorPaymentDetailsPage(payment: item),
                                  ),
                                );
                              },
                              child: Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(top: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      _buildTableCell('${index + 1}', 60),
                                      _buildTableCell(item.settlementId, 120),
                                      _buildTableCell(
                                        _formatDate(item.date),
                                        100,
                                      ),
                                      _buildTableCell(item.time, 80),
                                      _buildTableCell('₹${item.parkingAmount}', 100),
                                      _buildTableCell('₹${item.platformFee}', 120),
                                      _buildTableCell('₹${item.payableAmount}', 100),
                                      _buildTableCell(
                                        item.status.toUpperCase(),
                                        100,
                                        color: item.status == 'settled'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, double width,
      {TextOverflow? overflow, Color? color}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: color ?? ColorUtils.primarycolor(),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: overflow,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr; // Return original string if parsing fails
    }
  }
}

class VendorPaymentDetailsPage extends StatelessWidget {
  final VendorPayment payment;

  const VendorPaymentDetailsPage({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Settlement Details',
          style: GoogleFonts.poppins( // Change to any font you like
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black, // Optional if your appBar has a colored background
          ),
        ),
        backgroundColor: ColorUtils.secondarycolor(),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
          children: [
            _buildDetailRow("Settlement ID", payment.settlementId),


          Card(color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContainer(_buildDetailRow("Date", _formatDate(payment.date))),
                  _buildContainer(_buildDetailRow("Time", payment.time)),
                  _buildContainer(_buildDetailRow("Parking Amount", '₹${payment.parkingAmount}')),
                  _buildContainer(_buildDetailRow("Total Bookings", payment.bookingTotal)),
                  _buildContainer(_buildDetailRow("Platform Fee", '₹${payment.platformFee}')),
                  _buildContainer(_buildDetailRow("GST", '₹${payment.gst}')),
                  _buildContainer(_buildDetailRow("TDS", payment.tds.join(', '))),
                  _buildContainer(_buildDetailRow("Receivable Amount", '₹${payment.payableAmount}')),
                ],
              ),
            ),
          ),

// Helper method to wrap each row in a Container



            const SizedBox(height: 20),
            Text(
              "Bookings List:",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),

            // Scrollable Table Layout
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  _buildTableHeaderRow(),
                  ...payment.bookings.map((booking) => _buildBookingRow(booking)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),);
  }

  // Header Row
  Widget _buildTableHeaderRow() {
    return Card(
      color: ColorUtils.primarycolor(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildTableHeader('Booking ID', 100),

            // _buildTableHeader('Booking Date', 100),
            _buildTableHeader('Parking Date', 100),
            _buildTableHeader('Parking Time', 100),
            _buildTableHeader('Amount', 80),
            _buildTableHeader('Platform Fee', 100),
            _buildTableHeader('Receivable', 100),
            // _buildTableHeader('Exit Date', 100),
            // _buildTableHeader('Exit Time', 100),
            // _buildTableHeader('Vendor', 100),
            // _buildTableHeader('Vehicle Type', 100),
            // _buildTableHeader('Vehicle No.', 100),
          ],
        ),
      ),
    );
  }

  // Booking Row
  Widget _buildBookingRow(Map<String, dynamic> booking) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            _buildTableCell(booking['_id'] ?? 'N/A', 100),

            // _buildTableCell(booking['bookingDate'] ?? 'N/A', 100),
            _buildTableCell(booking['parkingDate'] ?? 'N/A', 100),
            _buildTableCell(booking['parkingTime'] ?? 'N/A', 100),
            _buildTableCell('₹${booking['amount'] ?? '0.00'}', 80),
            _buildTableCell('₹${booking['platformfee'] ?? '0.00'}', 100),
            _buildTableCell('₹${booking['receivableAmount'] ?? '0.00'}', 100),
            // _buildTableCell(booking['exitvehicledate'] ?? 'N/A', 100),
            // _buildTableCell(booking['exitvehicletime'] ?? 'N/A', 100),
            // _buildTableCell(booking['vendorName'] ?? 'N/A', 100),
            // _buildTableCell(booking['vehicleType'] ?? 'N/A', 100),
            // _buildTableCell(booking['vehicleNumber'] ?? 'N/A', 100),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, double width,
      {TextOverflow? overflow, Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color ?? Colors.black87,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
        overflow: overflow,
      ),
    );
  }
  Widget _buildContainer(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }

// Sample _buildDetailRow method (adjust if yours is different)
  Widget _buildDetailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
  // Widget _buildDetailRow(String label, String value, {Color? color}) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6.0),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           "$label: ",
  //           style: GoogleFonts.poppins(
  //             fontWeight: FontWeight.bold,
  //             fontSize: 14,
  //           ),
  //         ),
  //         Expanded(
  //           child: Text(
  //             value,
  //             style: GoogleFonts.poppins(
  //               fontSize: 14,
  //               color: color ?? Colors.black87,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
