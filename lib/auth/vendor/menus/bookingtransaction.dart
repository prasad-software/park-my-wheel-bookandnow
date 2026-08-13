import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/parkindetails.dart';
import 'package:mywheels/boookingtransationdetails.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/pageloader.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../../config/colorcode.dart';

class VehicleBookingTransaction {
  final String bookingDate;
  final String bookingTime;
  final String bookingId;
  final String exitdate;
  final String exittime;
  final String vehiclenumber;
  final String bookingAmount;
  final String vehicleType;
  final String platformFee;
  final String receivable;
  final String amout;
  final String totalamout;
  final String handlingfee;
  final String gstamout;
  final String sts;
  final String status;
  final String vendorid;
  final String otp;
  final String bookingtype;
  final bool isUserBooking;
  final String mobilenumber;
  final String invoice;
  final String username;
  final String vendorname;
  final String invoiceid;
  final String parkedDate;
  final String userid;

  final String parkedTime;
  final String exitvehicledate;
  final String  exitvehicletime;
  final String  subsctiptionenddate;

  VehicleBookingTransaction( {
    required this.invoice,
    required this.parkedDate,
    required this.parkedTime,
    required this.exitvehicledate,
    required this.exitvehicletime,
    required this.subsctiptionenddate,
    required this.invoiceid,
    required this.username,
    required this.status,
    required this.mobilenumber,
    required this.sts,
    required this.vendorid,
    required this.otp,
    required this.bookingtype,
    required this.vehiclenumber,
    required this.platformFee,
    required this.receivable,
    required this.bookingDate,
    required this.bookingTime,
    required this.bookingId,
    required this.bookingAmount,
    required this.vehicleType,
    required this.exitdate,
    required this.exittime,
    required this.amout,
    required this.totalamout,
    required this.handlingfee,
    required this.gstamout,
    required this.isUserBooking,
    required this.vendorname,
    this.userid = '',
  });
}

class VehicleBookingListScreen extends StatefulWidget {
  final String vendorid;

  const VehicleBookingListScreen({super.key, required this.vendorid});

  @override
  _VehicleBookingListScreenState createState() => _VehicleBookingListScreenState();
}

class _VehicleBookingListScreenState extends State<VehicleBookingListScreen> {
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';
  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  final DateTime _endDate = DateTime.now();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  int selectedTabIndex = 0;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  final TextEditingController _dateController = TextEditingController();
  List<VehicleBookingTransaction> userTransactions = [];
  List<VehicleBookingTransaction> nonUserTransactions = [];

  @override
  void initState() {
    super.initState();
    _selectedStartDate = _startDate;
    _selectedEndDate = _endDate;
    _startDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_startDate),
    );
    _endDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_endDate),
    );
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    fetchTransactions();
  }

  String _fmtDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  VehicleBookingTransaction _parseTx(Map<String, dynamic> item) {
    final uid = item['userid']?.toString() ?? item['userId']?.toString() ?? '';
    return VehicleBookingTransaction(
      invoiceid: ((item['invoiceid']?.toString() ?? '').trim().isEmpty)
          ? (item['_id']?.toString() ?? 'N/A')
          : (item['invoiceid']?.toString() ?? 'N/A'),
      vendorname: item['vendorname']?.toString() ?? 'N/A',
      invoice: ((item['invoice']?.toString() ?? '').trim().isEmpty)
          ? (item['_id']?.toString() ?? 'N/A')
          : (item['invoice']?.toString() ?? 'N/A'),
      username: item['username']?.toString() ?? item['personName']?.toString() ?? 'N/A',
      sts: item['sts']?.toString() ?? 'N/A',
      status: item['status']?.toString() ?? 'N/A',
      vendorid: item['vendorid']?.toString() ?? 'N/A',
      otp: item['otp']?.toString() ?? 'N/A',
      bookingtype: item['bookingtype']?.toString() ?? 'N/A',
      exitdate: item['exitdate']?.toString() ?? 'N/A',
      exittime: item['exittime']?.toString() ?? 'N/A',
      vehiclenumber: item['vehiclenumber']?.toString() ?? 'N/A',
      bookingDate: item['bookingDate']?.toString() ?? 'N/A',
      bookingTime: item['bookingTime']?.toString() ?? 'N/A',
      bookingId: item['bookingId']?.toString() ?? item['_id']?.toString() ?? 'N/A',
      bookingAmount: item['amount']?.toString() ?? '0.00',
      vehicleType: item['vehicleType']?.toString() ?? 'N/A',
      amout: item['amount']?.toString() ?? '0.00',
      handlingfee: item['handlingfee']?.toString() ?? '0.00',
      gstamout: item['gstamout']?.toString() ?? '0.00',
      totalamout: item['totalamout']?.toString() ?? '0.00',
      platformFee: item['releasefee']?.toString() ?? '0.00',
      receivable: item['recievableamount']?.toString() ?? '0.00',
      mobilenumber: item['mobileNumber']?.toString() ?? 'N/A',
      parkedDate: item['parkedDate']?.toString() ?? item['bookingDate']?.toString() ?? 'N/A',
      parkedTime: item['parkedTime']?.toString() ?? item['bookingTime']?.toString() ?? 'N/A',
      exitvehicledate: item['exitvehicledate']?.toString() ?? 'N/A',
      exitvehicletime: item['exitvehicletime']?.toString() ?? 'N/A',
      subsctiptionenddate: item['subsctiptionenddate']?.toString() ?? 'N/A',
      userid: uid,
      isUserBooking: uid.isNotEmpty,
    );
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    final start = _fmtDate(_selectedStartDate ?? _startDate);
    final end = _fmtDate(_selectedEndDate ?? _endDate);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fast-transactions/${widget.vendorid}?startDate=$start&endDate=$end'),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> userData = body['userData'] is List ? body['userData'] : [];
        final List<dynamic> nonUserData = body['nonUserData'] is List ? body['nonUserData'] : [];

        if (userData.isEmpty && nonUserData.isEmpty) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No transactions found for this vendor.';
          });
          return;
        }

        setState(() {
          userTransactions = userData.map<VehicleBookingTransaction>((item) => _parseTx(Map<String, dynamic>.from(item))).toList();
          nonUserTransactions = nonUserData.map<VehicleBookingTransaction>((item) => _parseTx(Map<String, dynamic>.from(item))).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to load data: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  List<VehicleBookingTransaction> getFilteredTransactions(bool isUserBooking) {
    final transactions = isUserBooking ? userTransactions : nonUserTransactions;

    if (_selectedStartDate == null || _selectedEndDate == null) {
      return transactions;
    }

    return transactions.where((transaction) {
      try {
        if (transaction.bookingDate == 'N/A' || transaction.bookingDate.isEmpty) {
          return false;
        }

        DateTime? bookingDate;
        const possibleFormats = [
          'dd-MM-yyyy',
          'yyyy-MM-dd',
          'MM/dd/yyyy',
        ];

        for (var format in possibleFormats) {
          try {
            bookingDate = DateFormat(format).parse(transaction.bookingDate);
            break;
          } catch (e) {
            continue;
          }
        }

        if (bookingDate == null) {
          try {
            final timestamp = int.tryParse(transaction.bookingDate);
            if (timestamp != null) {
              bookingDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          } catch (e) {
            debugPrint('Failed to parse bookingDate as timestamp: ${transaction.bookingDate}');
          }
        }

        if (bookingDate == null) {
          debugPrint('Invalid bookingDate: ${transaction.bookingDate}');
          return false;
        }

        final startDate = DateTime(
          _selectedStartDate!.year,
          _selectedStartDate!.month,
          _selectedStartDate!.day,
        );
        final endDate = DateTime(
          _selectedEndDate!.year,
          _selectedEndDate!.month,
          _selectedEndDate!.day,
        );
        final normalizedBookingDate = DateTime(
          bookingDate.year,
          bookingDate.month,
          bookingDate.day,
        );

        return (normalizedBookingDate.isAtSameMomentAs(startDate) ||
            normalizedBookingDate.isAtSameMomentAs(endDate) ||
            (normalizedBookingDate.isAfter(startDate) &&
                normalizedBookingDate.isBefore(endDate)));
      } catch (e) {
        debugPrint('Error parsing date for transaction ${transaction.bookingId}: $e');
        return false;
      }
    }).toList();
  }

  double getTotalReceivable(bool isUserBooking) {
    return getFilteredTransactions(isUserBooking).fold(0.0, (sum, transaction) {
      return sum + (double.tryParse(transaction.receivable) ?? 0.0);
    });
  }

  double getTotalPlatformFee(bool isUserBooking) {
    return getFilteredTransactions(isUserBooking).fold(0.0, (sum, transaction) {
      return sum + (double.tryParse(transaction.platformFee) ?? 0.0);
    });
  }

  double getTotalAmount(bool isUserBooking) {
    return getFilteredTransactions(isUserBooking).fold(0.0, (sum, transaction) {
      return sum + (double.tryParse(transaction.totalamout) ?? 0.0);
    });
  }
  double getbookingAmount(bool isUserBooking) {
    return getFilteredTransactions(isUserBooking).fold(0.0, (sum, transaction) {
      return sum + (double.tryParse(transaction.receivable) ?? 0.0);
    });
  }

  double getTotalGST(bool isUserBooking) {
    return getFilteredTransactions(isUserBooking).fold(0.0, (sum, transaction) {
      return sum + (double.tryParse(transaction.gstamout) ?? 0.0);
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedStartDate = _startDate;
      _selectedEndDate = _endDate;
      _startDateController.text = DateFormat('dd-MM-yyyy').format(_startDate);
      _endDateController.text = DateFormat('dd-MM-yyyy').format(_endDate);
    });
  }

  Future<void> exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Booking Transactions'];

      final totalAmount = getTotalAmount(selectedTabIndex == 1);
      final totalPlatformFee = getTotalPlatformFee(selectedTabIndex == 1);
      final totalReceivable = getTotalReceivable(selectedTabIndex == 1);
      final totalGST = getTotalGST(selectedTabIndex == 1);
      final bookingamout = getbookingAmount(selectedTabIndex == 1);

      if (selectedTabIndex == 1) {
        sheet.appendRow([
          TextCellValue('S.No'),
          TextCellValue('Vehicle Number'),
          TextCellValue('Parking Date'),
          TextCellValue('Parking Time'),
          TextCellValue('Exit Date'),
          TextCellValue('Exit Time'),
          TextCellValue('Charges'),
          TextCellValue('GST'),
          TextCellValue('Handling Fee'),
          TextCellValue('Total Amount'),
          TextCellValue('Platform Fee'),
          TextCellValue('Receivable'),
        ]);

        final userData = getFilteredTransactions(true);
        for (var i = 0; i < userData.length; i++) {
          var transaction = userData[i];
          sheet.appendRow([
            TextCellValue((i + 1).toString()),
            TextCellValue(transaction.vehiclenumber),
            TextCellValue(transaction.bookingDate),
            TextCellValue(transaction.bookingTime),
            TextCellValue(transaction.exitdate),
            TextCellValue(transaction.exittime),
            TextCellValue('₹${transaction.bookingAmount}'),
            TextCellValue('₹${transaction.gstamout}'),
            TextCellValue('₹${transaction.handlingfee}'),
            TextCellValue('₹${transaction.totalamout}'),
            TextCellValue('₹${transaction.platformFee}'),
            TextCellValue('₹${transaction.receivable}'),
          ]);
        }

        sheet.appendRow([TextCellValue('')]);
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(''),

          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue('Total:'),
          TextCellValue('₹${totalAmount.toStringAsFixed(2)}'),

          TextCellValue('₹${totalPlatformFee.toStringAsFixed(2)}'),
          TextCellValue('₹${totalReceivable.toStringAsFixed(2)}'),
        ]);
      } else {
        sheet.appendRow([
          TextCellValue('S.No'),
          TextCellValue('Booking ID'),
          TextCellValue('Parking Date'),
          TextCellValue('Parking Time'),
          TextCellValue('Exit Date'),
          TextCellValue('Exit Time'),
          TextCellValue('Amount'),
          TextCellValue('Platform Fee'),
          TextCellValue('Receivable'),

        ]);

        final nonUserData = getFilteredTransactions(false);
        for (var i = 0; i < nonUserData.length; i++) {
          var transaction = nonUserData[i];
          sheet.appendRow([
            TextCellValue((i + 1).toString()),
            TextCellValue(transaction.vehiclenumber),
            TextCellValue(transaction.bookingDate),
            TextCellValue(transaction.bookingTime),
            TextCellValue(transaction.exitdate),
            TextCellValue(transaction.exittime),
            TextCellValue('₹${transaction.bookingAmount}'),
            TextCellValue('₹${transaction.platformFee}'),
            TextCellValue('₹${transaction.receivable}'),
          ]);
        }

        sheet.appendRow([TextCellValue('')]);
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue('Total:'),
          TextCellValue(''),
          TextCellValue('₹${bookingamout.toStringAsFixed(2)}'),
          TextCellValue('₹${totalPlatformFee.toStringAsFixed(2)}'),
          TextCellValue('₹${totalReceivable.toStringAsFixed(2)}'),
        ]);
      }

      String fileName = 'vendor_payments_${selectedTabIndex == 1 ? 'user' : 'vendor'}';
      if (_selectedStartDate != null && _selectedEndDate != null) {
        fileName += '_${DateFormat('ddMMyy').format(_selectedStartDate!)}_to_${DateFormat('ddMMyy').format(_selectedEndDate!)}';
      }
      fileName += '_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await OpenFile.open(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported successfully to $filePath')),
        );
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title:  Text('Booking Transactions',style: GoogleFonts.poppins(
          color: Colors.black,
          // fontWeight: FontWeight.bold,
          fontSize: 18,
        ),),
        backgroundColor: ColorUtils.secondarycolor(),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: exportToExcel,
            tooltip: 'Export to Excel',
          ),
          if (_selectedStartDate != _startDate || _selectedEndDate != _endDate)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateFilter,
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body:
      isLoading
          ? const LoadingGif()
          :SafeArea(
            child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: CustomSlidingSegmentedControl<int>(
                  initialValue: selectedTabIndex,
                  isStretch: true,
                  children: {
                    0: Text('Vendor Bookings', style: GoogleFonts.poppins(fontSize: 14)),
                    1: Text('User Bookings', style: GoogleFonts.poppins(fontSize: 14)),
                  },
                  onValueChanged: (value) {
                    setState(() {
                      selectedTabIndex = value;
                    });
                  },
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  thumbDecoration: BoxDecoration(
                    color: ColorUtils.secondarycolor(),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInToLinear,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: IndexedStack(
                  index: selectedTabIndex,
                  children: [
                    _buildTransactionList(false),
                    _buildTransactionList(true),
                  ],
                ),
              ),
            ],
                    ),
                  ),
          ),
    );
  }
  Widget _buildTransactionList(bool isUserBooking) {
    final filteredTransactions = getFilteredTransactions(isUserBooking);
    final totalAmount = getTotalAmount(isUserBooking);
    final totalReceivable = getTotalReceivable(isUserBooking);
    final totalPlatformFee = getTotalPlatformFee(isUserBooking);
    final totalGST = getTotalGST(isUserBooking);
    final bookingamout = getbookingAmount(isUserBooking);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Select Date ',
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            isUserBooking ?
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Total: ₹${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: ColorUtils.primarycolor(),
                  ),
                ),
              ),
            ) : Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Total: ₹${bookingamout.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: ColorUtils.primarycolor(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(_selectedStartDate ?? _startDate),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Text('to'),
            const SizedBox(width: 4),
            Text(
              DateFormat('dd MMM yyyy').format(_selectedEndDate ?? _endDate),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filteredTransactions.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No ${isUserBooking ? 'user' : 'vendor'} transactions found',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                if (_selectedStartDate != null || _selectedEndDate != null)
                  Text(
                    'for selected date range.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          )
              : Column(
            children: [
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
                              children: isUserBooking
                                  ? [
                                _buildTableHeader('S.No', 60),
                                _buildTableHeader('Vehicle Number', 150),
                                _buildTableHeader('Parking Date', 100),
                                _buildTableHeader('Parking Time', 100),
                                _buildTableHeader('Exit Date', 100),
                                _buildTableHeader('Exit Time', 80),
                                _buildTableHeader('Charges', 100),
                                _buildTableHeader('GST', 100),
                                _buildTableHeader('Handling Fee', 100),
                                _buildTableHeader('Total Amount', 120),
                                _buildTableHeader('Platform Fee', 100),
                                _buildTableHeader('Receivable', 100),
                              ]
                                  : [
                                _buildTableHeader('S.No', 60),
                                _buildTableHeader('Vehicle Number', 150),
                                _buildTableHeader('Parking Date', 100),
                                _buildTableHeader('Parking Time', 100),
                                _buildTableHeader('Exit Date', 100),
                                _buildTableHeader('Exit Time', 80),
                                _buildTableHeader('Amount', 100),
                                _buildTableHeader('Platform Fee', 100),
                                _buildTableHeader('Receivable', 100),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: filteredTransactions.asMap().entries.map((entry) {
                            int index = entry.key;
                            var item = entry.value;
                            return GestureDetector(
                              onTap: () {
                                // Use booking _id for getbooking API, not invoiceid
                                // final bookingMongoId = item.bookingId;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => bookingtransactiondetails(
                                      parkeddate: item.parkedDate,
                                      parkedtime: item.parkedTime,
                                      subscriptionenddate:item.subsctiptionenddate,
                                      exitdate:item.exitvehicledate,
                                      exittime:item.exitvehicletime,
                                      invoiceid: item.invoiceid,
                                      username: item.username,
                                      mobilenumber: item.mobilenumber,
                                      bookedid: item.bookingId,
                                      schedule: item.bookingDate,
                                      bookeddate: item.bookingDate,
                                      vehiclenumber: item.vehiclenumber,
                                      vendorname: item.vendorname,
                                      vendorid: item.vendorid,
                                      parkingdate: item.bookingDate,
                                      parkingtime: item.bookingTime,
                                      vehicletype: item.vehicleType,
                                      status: item.status,
                                      bookingtype: item.bookingtype,
                                      sts: item.sts,
                                      otp: item.otp, amount: item.amout, totalamount: item.totalamout, invoice: item.invoice,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(top: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: isUserBooking
                                        ? [
                                      _buildTableCell('${index + 1}', 60),
                                      _buildTableCell(
                                        item.vehiclenumber,
                                        150,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      _buildTableCell(item.bookingDate, 100),
                                      _buildTableCell(item.bookingTime, 100),
                                      _buildTableCell(item.exitdate, 100),
                                      _buildTableCell(item.exittime, 80),
                                      _buildTableCell('₹${item.bookingAmount}', 100),
                                      _buildTableCell('₹${item.gstamout}', 100),
                                      _buildTableCell('₹${item.handlingfee}', 100),
                                      _buildTableCell('₹${item.totalamout}', 120),
                                      _buildTableCell('₹${item.platformFee}', 100),
                                      _buildTableCell('₹${item.receivable}', 100),
                                    ]
                                        : [
                                      _buildTableCell('${index + 1}', 60),
                                      _buildTableCell(
                                        item.vehiclenumber,
                                        150,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      _buildTableCell(item.bookingDate, 100),
                                      _buildTableCell(item.bookingTime, 100),
                                      _buildTableCell(item.exitdate, 100),
                                      _buildTableCell(item.exittime, 80),
                                      _buildTableCell('₹${item.bookingAmount}', 100),
                                      _buildTableCell('₹${item.platformFee}', 100),
                                      _buildTableCell('₹${item.receivable}', 100),
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
              Card(
                color: Colors.grey[100],
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 16), // Added bottom margin
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: isUserBooking
                        ? [
                      Column(
                        children: [
                          Text(
                            'Platform Fee',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₹${totalPlatformFee.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Total Receivable',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₹${totalReceivable.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ]
                        : [
                      Column(
                        children: [
                          Text(
                            'Platform Fee',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₹${totalPlatformFee.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Total Receivables',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₹${bookingamout.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildTableCell(String text, double width, {TextOverflow? overflow}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: ColorUtils.primarycolor(),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: overflow,
        ),
      ),
    );
  }

  void _selectDate(BuildContext context) async {
    final initialRange = PickerDateRange(
      _selectedStartDate ?? _startDate,
      _selectedEndDate ?? _endDate,
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: SizedBox(
            width: 300,
            height: 300,
            child: SfDateRangePicker(
              backgroundColor: Colors.white,
              selectionColor: ColorUtils.primarycolor(),
              startRangeSelectionColor: ColorUtils.primarycolor(),
              endRangeSelectionColor: ColorUtils.primarycolor(),
              rangeSelectionColor: ColorUtils.primarycolor().withOpacity(0.3),
              todayHighlightColor: ColorUtils.primarycolor().withOpacity(0.1),
              selectionMode: DateRangePickerSelectionMode.range,
              minDate: DateTime(1901, 1, 1),
              maxDate: DateTime.now(),
              initialSelectedRange: initialRange,
              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                  _selectedStartDate = args.value.startDate;
                  _selectedEndDate = args.value.endDate ?? args.value.startDate;
                }
              },
              headerStyle: const DateRangePickerHeaderStyle(
                backgroundColor: Colors.white,
                textStyle: TextStyle(color: Colors.black, fontSize: 18),
              ),
              monthViewSettings: const DateRangePickerMonthViewSettings(
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                  backgroundColor: Colors.white,
                  textStyle: TextStyle(color: Colors.black),
                ),
              ),
              monthCellStyle: DateRangePickerMonthCellStyle(
                todayCellDecoration: BoxDecoration(
                  color: ColorUtils.primarycolor().withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                disabledDatesDecoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                textStyle: const TextStyle(color: Colors.black),
                todayTextStyle: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          actions: [
            Container(
              height: 25,
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _startDateController.text =
                        DateFormat('dd-MM-yyyy').format(_selectedStartDate ?? _startDate);
                    _endDateController.text =
                        DateFormat('dd-MM-yyyy').format(_selectedEndDate ?? _endDate);
                  });
                  Navigator.of(context).pop();
                  fetchTransactions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  elevation: 0,
                ),
                child: const Center(child: Text('OK')),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}