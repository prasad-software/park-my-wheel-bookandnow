import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import '../../../utils/sts_utils.dart';
import '../../../pageloader.dart';

class CustomReportScreen extends StatefulWidget {
  final String vendorid;
  const CustomReportScreen({super.key, required this.vendorid});

  @override
  State<CustomReportScreen> createState() => _CustomReportScreenState();
}

class _CustomReportScreenState extends State<CustomReportScreen> {
  DateTime _selectedStartDateTime = DateTime.now().subtract(
    const Duration(hours: 1),
  );
  DateTime _selectedEndDateTime = DateTime.now();

  bool _isLoading = false;
  String? _error;
  List<Bookingdata> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final start = DateFormat('dd-MM-yyyy').format(_selectedStartDateTime);
      final end = DateFormat('dd-MM-yyyy').format(_selectedEndDateTime);
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fast-summary/${widget.vendorid}?startDate=$start&endDate=$end',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to load bookings (${response.statusCode})');
      }

      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      final List<dynamic>? data = jsonResponse['bookings'];
      final list =
          (data ?? const <dynamic>[])
              .whereType<Map>()
              .map((m) => Bookingdata.fromJson(Map<String, dynamic>.from(m)))
              .toList();

      if (!mounted) return;
      setState(() {
        _bookings = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  DateTime? _combineDateTime(String date, String time) {
    try {
      final combined = '$date $time'.toUpperCase();
      try {
        return DateFormat('dd-MM-yyyy hh:mm a').parse(combined);
      } catch (_) {
        try {
          return DateFormat('dd-MM-yyyy HH:mm').parse(combined);
        } catch (_) {
          try {
            return DateFormat('d-M-yyyy hh:mm a').parse(combined);
          } catch (_) {
            return DateFormat('d-M-yyyy HH:mm').parse(combined);
          }
        }
      }
    } catch (e) {
      return null;
    }
  }

  List<Bookingdata> _filteredBookings() {
    return _bookings.where((b) {
      if (b.Vendorid != widget.vendorid) return false;

      final bookingDateTime = _combineDateTime(b.bookingDate, b.bookingTime);
      final exitDateTime =
          (b.exitvehicledate.trim().isNotEmpty &&
                  b.exitvehicletime.trim().isNotEmpty)
              ? _combineDateTime(b.exitvehicledate, b.exitvehicletime)
              : null;

      bool isBookedInRange = false;
      if (bookingDateTime != null) {
        isBookedInRange =
            (bookingDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                bookingDateTime.isAfter(_selectedStartDateTime)) &&
            (bookingDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                bookingDateTime.isBefore(_selectedEndDateTime));
      }

      bool isExitedInRange = false;
      if (exitDateTime != null) {
        isExitedInRange =
            (exitDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                exitDateTime.isAfter(_selectedStartDateTime)) &&
            (exitDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                exitDateTime.isBefore(_selectedEndDateTime));
      }

      return isBookedInRange || isExitedInRange;
    }).toList();
  }

  double _amountForBooking(Bookingdata b) {
    final s = (b.totalamout.trim().isNotEmpty ? b.totalamout : b.amount).trim();
    final baseAmount = double.tryParse(s) ?? 0.0;
    final sts = b.sts.trim().toLowerCase();
    final isPassOrSub =
        isSubscriptionSts(sts) ||
        RegExp(r'^\d+(?:hr|h)$', caseSensitive: false).hasMatch(sts);
    final valetAmount =
        isPassOrSub ? 0.0 : (double.tryParse(b.valetCharge) ?? 0.0);
    return baseAmount + valetAmount;
  }

  _CustomSummaryTotals _computeTotals(List<Bookingdata> list) {
    final totals = _CustomSummaryTotals();
    for (final b in list) {
      final amount = _amountForBooking(b);
      final sts = b.sts.trim().toLowerCase();

      if (RegExp(r'^\d+(?:hr|h)$', caseSensitive: false).hasMatch(sts)) {
        final hours = int.tryParse(sts.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        totals.addPassHours(hours, amount);
      } else if (sts == 'weekly' || sts == '7day' || sts == '7days') {
        totals.weeklyCount++;
        totals.weeklyAmount += amount;
      } else if (sts == '15day' || sts == '15days') {
        totals.pass15Count++;
        totals.pass15Amount += amount;
      } else if (sts == 'monthly' || sts == '30day' || sts == '30days') {
        totals.monthlyCount++;
        totals.monthlyAmount += amount;
      } else if (isSubscriptionSts(sts)) {
        totals.monthlyCount++;
        totals.monthlyAmount += amount;
      } else {
        totals.hourlyCount++;
        totals.hourlyAmount += amount;
      }

      final pm = b.paymentmode.toString().trim().toLowerCase();
      if (pm == 'cash') {
        totals.cashTotal += amount;
      } else if (pm.contains('online') ||
          pm.contains('upi') ||
          pm.contains('qr')) {
        totals.onlineTotal += amount;
      } else {
        totals.cashTotal += amount;
      }
    }
    return totals;
  }

  Future<void> _selectDateTime(bool isStart) async {
    DateTime initialDate =
        isStart ? _selectedStartDateTime : _selectedEndDateTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ColorUtils.primarycolor(),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: ColorUtils.primarycolor(),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: ColorUtils.primarycolor(),
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: ColorUtils.primarycolor(),
                ),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _selectedStartDateTime = newDateTime;
            if (_selectedEndDateTime.isBefore(_selectedStartDateTime)) {
              _selectedEndDateTime = _selectedStartDateTime.add(
                const Duration(hours: 1),
              );
            }
          } else {
            _selectedEndDateTime = newDateTime;
            if (_selectedStartDateTime.isAfter(_selectedEndDateTime)) {
              _selectedStartDateTime = _selectedEndDateTime.subtract(
                const Duration(hours: 1),
              );
            }
          }
        });
        _fetchBookings();
      }
    }
  }

  Future<void> _printReport(
    List<Bookingdata> list,
    _CustomSummaryTotals totals,
  ) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookings found for selected range')),
      );
      return;
    }

    String vendorName = 'Parking Location';
    for (final b in list) {
      if (b.vendorname.trim().isNotEmpty) {
        vendorName = b.vendorname.trim();
        break;
      }
    }

    final entryCount = list.length;
    final exitCount =
        list.where((b) => b.exitvehicledate.trim().isNotEmpty).length;

    final now = DateTime.now();
    final reportDate = DateFormat('dd-MM-yyyy').format(now);
    final reportTime = DateFormat('hh:mm a').format(now);

    final startLabel = DateFormat(
      'dd-MM-yyyy hh:mm a',
    ).format(_selectedStartDateTime);
    final endLabel = DateFormat(
      'dd-MM-yyyy hh:mm a',
    ).format(_selectedEndDateTime);

    try {
      await UniversalPrintHelper.printSummaryReport(
        context: context,
        vendorId: widget.vendorid,
        vendorName: vendorName,
        empId: 'Custom',
        reportDate: reportDate,
        reportTime: reportTime,
        fromDate: startLabel.split(' ').first,
        fromTime: startLabel.split(' ').sublist(1).join(' '),
        toDate: endLabel.split(' ').first,
        toTime: endLabel.split(' ').sublist(1).join(' '),
        entry: entryCount.toString(),
        exit: exitCount.toString(),
        hourlyCount: totals.hourlyCount,
        hourlyAmount: totals.hourlyAmount,
        pass12Count: totals.pass12Count,
        pass12Amount: totals.pass12Amount,
        pass24Count: totals.pass24Count,
        pass24Amount: totals.pass24Amount,
        pass48Count: totals.pass48Count,
        pass48Amount: totals.pass48Amount,
        pass72Count: totals.pass72Count,
        pass72Amount: totals.pass72Amount,
        weeklyCount: totals.weeklyCount,
        weeklyAmount: totals.weeklyAmount,
        pass15Count: totals.pass15Count,
        pass15Amount: totals.pass15Amount,
        monthlyCount: totals.monthlyCount,
        monthlyAmount: totals.monthlyAmount,
        cashTotal: totals.cashTotal,
        onlineTotal: totals.onlineTotal,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: $e')));
    }
  }

  Widget _buildDateTimeBox(String label, DateTime dateTime, bool isStart) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectDateTime(isStart),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              fontSize: 12,
              color: ColorUtils.primarycolor(),
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month,
                size: 16,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  DateFormat('dd-MM-yyyy hh:mm a').format(dateTime),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBookings();
    final totals = _computeTotals(filtered);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom Report',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                children: [
                  Text(
                    'Summary Report',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading:
            false, // Hide default back button since we have custom one
      ),
      body:
          _isLoading
              ? const Center(child: LoadingGif())
              : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildDateTimeBox('From', _selectedStartDateTime, true),
                        const SizedBox(width: 12),
                        _buildDateTimeBox('To', _selectedEndDateTime, false),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CustomSummaryRow(
                                label: 'Hourly',
                                count: totals.hourlyCount,
                                amount: totals.hourlyAmount,
                              ),
                              _CustomSummaryRow(
                                label: '12 Hours Pass',
                                count: totals.pass12Count,
                                amount: totals.pass12Amount,
                              ),
                              _CustomSummaryRow(
                                label: '24 Hours Pass',
                                count: totals.pass24Count,
                                amount: totals.pass24Amount,
                              ),
                              _CustomSummaryRow(
                                label: '48 Hours Pass',
                                count: totals.pass48Count,
                                amount: totals.pass48Amount,
                              ),
                              _CustomSummaryRow(
                                label: '72 Hours Pass',
                                count: totals.pass72Count,
                                amount: totals.pass72Amount,
                              ),
                              _CustomSummaryRow(
                                label: 'Weekly Pass (7 Days)',
                                count: totals.weeklyCount,
                                amount: totals.weeklyAmount,
                              ),
                              _CustomSummaryRow(
                                label: '15 Days Pass',
                                count: totals.pass15Count,
                                amount: totals.pass15Amount,
                              ),
                              _CustomSummaryRow(
                                label: 'Monthly Pass (30 Days)',
                                count: totals.monthlyCount,
                                amount: totals.monthlyAmount,
                              ),
                              const Divider(height: 24, thickness: 1),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cash Total:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${totals.cashTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Online Total:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${totals.onlineTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, thickness: 1),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${(totals.cashTotal + totals.onlineTotal).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'Bookings in range: ${filtered.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _printReport(filtered, totals),
                                  icon: const Icon(Icons.print, size: 20),
                                  label: Text(
                                    'Print Report',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
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
}

class _CustomSummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final double amount;

  const _CustomSummaryRow({
    required this.label,
    required this.count,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              count.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '₹${amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSummaryTotals {
  int hourlyCount = 0;
  double hourlyAmount = 0;

  int pass12Count = 0;
  double pass12Amount = 0;

  int pass24Count = 0;
  double pass24Amount = 0;

  int pass48Count = 0;
  double pass48Amount = 0;

  int pass72Count = 0;
  double pass72Amount = 0;

  int weeklyCount = 0;
  double weeklyAmount = 0;

  int pass15Count = 0;
  double pass15Amount = 0;

  int monthlyCount = 0;
  double monthlyAmount = 0;

  double cashTotal = 0;
  double onlineTotal = 0;

  void addPassHours(int hours, double amount) {
    if (hours == 12) {
      pass12Count++;
      pass12Amount += amount;
    } else if (hours == 24) {
      pass24Count++;
      pass24Amount += amount;
    } else if (hours == 48) {
      pass48Count++;
      pass48Amount += amount;
    } else if (hours == 72) {
      pass72Count++;
      pass72Amount += amount;
    } else {
      hourlyCount++;
      hourlyAmount += amount;
    }
  }
}
