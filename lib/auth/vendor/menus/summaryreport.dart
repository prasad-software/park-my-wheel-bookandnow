import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:tab_container/tab_container.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import '../../../utils/sts_utils.dart';
import '../../../pageloader.dart';
import 'custom_report.dart'; // Import CustomReportScreen

class SummaryReportScreen extends StatefulWidget {
  final String vendorid;
  const SummaryReportScreen({super.key, required this.vendorid});

  @override
  State<SummaryReportScreen> createState() => _SummaryReportScreenState();
}

class _SummaryReportScreenState extends State<SummaryReportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isFirstReport = true;
  DateTime? _lastReportEndTime;
  List<dynamic> _pastReports = [];
  bool _isLoadingHistory = false;
  int? _selectedReportIndex;

  final DateTime _defaultStartDate = DateTime.now();
  final DateTime _defaultEndDate = DateTime.now();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  final TextEditingController _empIdController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  List<Bookingdata> _bookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedStartDate = _defaultStartDate;
    _selectedEndDate = _defaultEndDate;
    _startDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_selectedStartDate!),
    );
    _endDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_selectedEndDate!),
    );
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchReports();
    await _fetchBookings();
  }

  /// Fetches report history and seeds the start-date from the most-recent report.
  /// Replaces the former _fetchLastReport + _fetchReportHistory (both hit the same endpoint).
  Future<void> _fetchReports() async {
    setState(() {
      _isLoadingHistory = true;
    });
    final url = Uri.parse(
      '${ApiConfig.baseUrl}vendor/getreports/${widget.vendorid}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reports = (data['reports'] as List?) ?? [];

        // Seed start date from the most-recent report (replaces _fetchLastReport)
        if (reports.isNotEmpty) {
          final toDateStr = reports.first['todate_time']?.toString() ?? '';
          try {
            DateTime lastEnd;
            if (toDateStr.contains('AM') || toDateStr.contains('PM')) {
              lastEnd = DateFormat('dd-MM-yyyy hh:mm a').parse(toDateStr);
            } else {
              lastEnd = DateFormat('dd-MM-yyyy HH:mm').parse(toDateStr);
            }
            setState(() {
              _lastReportEndTime = lastEnd;
              _isFirstReport = false;
              _selectedStartDate = _lastReportEndTime;
              _selectedEndDate = DateTime.now();
              _startDateController.text = DateFormat(
                'dd-MM-yyyy hh:mm a',
              ).format(_selectedStartDate!);
              _endDateController.text = DateFormat(
                'dd-MM-yyyy hh:mm a',
              ).format(_selectedEndDate!);
            });
          } catch (_) {}
        }

        setState(() {
          _pastReports = reports;
        });
      }
    } catch (_) {
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  DateTime? _combineDateTime(String date, String time) {
    try {
      // Try multiple formats for time
      // Standardize input string to handle lowercase am/pm
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
      print('Error combining date time ($date $time): $e');
      return null;
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _empIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final start = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedStartDate ?? _defaultStartDate);
      final end = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedEndDate ?? _defaultEndDate);
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

  void _selectDateRange(BuildContext context) async {
    final initialRange = PickerDateRange(
      _selectedStartDate ?? _defaultStartDate,
      _selectedEndDate ?? _defaultEndDate,
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
              rangeSelectionColor: ColorUtils.primarycolor().withAlpha(
                77,
              ), // ~30%
              todayHighlightColor: ColorUtils.primarycolor().withAlpha(
                26,
              ), // ~10%
              selectionMode: DateRangePickerSelectionMode.range,
              minDate: DateTime(1901, 1, 1),
              maxDate: DateTime.now(),
              initialSelectedRange: initialRange,
              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                  setState(() {
                    _selectedStartDate = args.value.startDate;
                    _selectedEndDate =
                        args.value.endDate ?? args.value.startDate;
                  });
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
                  color: ColorUtils.primarycolor().withAlpha(230), // ~90%
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
            SizedBox(
              height: 28,
              width: 70,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _startDateController.text = DateFormat(
                      'dd-MM-yyyy',
                    ).format(_selectedStartDate ?? _defaultStartDate);
                    _endDateController.text = DateFormat(
                      'dd-MM-yyyy',
                    ).format(_selectedEndDate ?? _defaultEndDate);
                  });
                  Navigator.of(context).pop();
                  _fetchBookings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Center(child: Text('OK')),
              ),
            ),
          ],
        );
      },
    );
  }

  DateTime? _tryParseBookingDateOnly(String date) {
    try {
      final d = date.trim();
      if (d.isEmpty) return null;
      try {
        return DateFormat('dd-MM-yyyy').parse(d);
      } catch (_) {
        // Fallback for single-digit days/months
        return DateFormat('d-M-yyyy').parse(d);
      }
    } catch (_) {
      return null;
    }
  }

  List<Bookingdata> _filteredBookings() {
    DateTime start = _selectedStartDate ?? _defaultStartDate;
    DateTime end = _selectedEndDate ?? _defaultEndDate;

    if (_isFirstReport) {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    }

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
            (bookingDateTime.isAtSameMomentAs(start) ||
                bookingDateTime.isAfter(start)) &&
            (bookingDateTime.isAtSameMomentAs(end) ||
                bookingDateTime.isBefore(end));
      }

      bool isExitedInRange = false;
      if (exitDateTime != null) {
        isExitedInRange =
            (exitDateTime.isAtSameMomentAs(start) ||
                exitDateTime.isAfter(start)) &&
            (exitDateTime.isAtSameMomentAs(end) || exitDateTime.isBefore(end));
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

    // If it is a purely hourly/instant booking and hasn't been completed yet,
    // the amount hasn't been collected. Wait for exit.
    if (!isPassOrSub && b.status.trim().toUpperCase() == 'PARKED') {
      return 0.0;
    }

    final valetAmount =
        isPassOrSub ? 0.0 : (double.tryParse(b.valetCharge) ?? 0.0);
    return baseAmount + valetAmount;
  }

  _SummaryTotals _computeTotals(List<Bookingdata> list) {
    final totals = _SummaryTotals();
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
        // Legacy subscription marker: treat as monthly by default
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

  Future<void> _saveReportToBackend({
    required _SummaryTotals totals,
    required int entryCount,
    required int exitCount,
    required String fromDateTime,
    required String toDateTime,
    required String reportDateTime,
    required String empId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/savereport');
      final headers = {'Content-Type': 'application/json'};
      final body = json.encode({
        'vendorid': widget.vendorid,
        'empid': empId,
        'fromdate_time': fromDateTime,
        'todate_time': toDateTime,
        'entry': entryCount,
        'exit': exitCount,
        '12hrsveh': totals.pass12Count,
        '24hrsveh': totals.pass24Count,
        '48hrsveh': totals.pass48Count,
        '72hrsveh': totals.pass72Count,
        '7daysveh': totals.weeklyCount,
        '15daysveh': totals.pass15Count,
        '30daysveh': totals.monthlyCount,
        '12hrsvehamt': totals.pass12Amount,
        '24hrsvehamt': totals.pass24Amount,
        '48hrsvehamt': totals.pass48Amount,
        '72hrsvehamt': totals.pass72Amount,
        '7daysvehamt': totals.weeklyAmount,
        '15daysvehamt': totals.pass15Amount,
        '30daysvehamt': totals.monthlyAmount,
        'totals': totals.cashTotal + totals.onlineTotal,
        'cash': totals.cashTotal,
        'online': totals.onlineTotal,
        'hourlycount': totals.hourlyCount,
        'hourlyamount': totals.hourlyAmount,
        'reportdate_time': reportDateTime,
      });

      final response = await http.post(url, headers: headers, body: body);
    } catch (e) {
      print(
        '[SummaryReport.saveReportToBackend] ERROR POST ${ApiConfig.baseUrl}vendor/savereport -> $e',
      );
      // Save failure is silent — print still proceeds
    }
  }

  Future<void> _printReport() async {
    final empId = _empIdController.text.trim();
    if (empId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID is required to generate a report'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    _selectedEndDate = now;

    final list = _filteredBookings();
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookings found for selected range')),
      );
      return;
    }

    final totals = _computeTotals(list);

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

    final reportDate = DateFormat('dd-MM-yyyy').format(now);
    final reportTime = DateFormat('hh:mm a').format(now);
    final startDate = _selectedStartDate ?? _defaultStartDate;
    final endDate = now;

    // Normalize the printed start time to 00:00:00 for the first report
    // so it perfectly matches the inclusive filter applied to bookings.
    final printedStartDate =
        _isFirstReport
            ? DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0)
            : startDate;

    final startLabel = DateFormat(
      'dd-MM-yyyy hh:mm a',
    ).format(printedStartDate);
    final endLabel = DateFormat('dd-MM-yyyy hh:mm a').format(endDate);

    await _saveReportToBackend(
      totals: totals,
      entryCount: entryCount,
      exitCount: exitCount,
      fromDateTime: startLabel,
      toDateTime: endLabel,
      reportDateTime: '$reportDate $reportTime',
      empId: empId,
    );

    if (mounted) {
      setState(() {
        _isFirstReport = false;
        _lastReportEndTime = now;
        _selectedStartDate = now;
        _selectedEndDate = now;
        final formatted = DateFormat('dd-MM-yyyy hh:mm a').format(now);
        _startDateController.text = formatted;
        _endDateController.text = formatted;
      });
    }

    // Refresh history after saving (so Past Reports is up-to-date)
    await _fetchReports();

    await UniversalPrintHelper.printSummaryReport(
      context: context,
      vendorId: widget.vendorid,
      vendorName: vendorName,
      empId: empId,
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

    if (mounted) {
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBookings();
    final totals = _computeTotals(filtered);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Summary Report',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.article, color: ColorUtils.primarycolor()),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          CustomReportScreen(vendorid: widget.vendorid),
                ),
              );
            },
          ),
          if (_isFirstReport)
            IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: ColorUtils.primarycolor(),
              ),
              onPressed: () => _selectDateRange(context),
            ),
        ],
      ),

      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(),
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(8),
          child: TabContainer(
            controller: _tabController,
            borderRadius: BorderRadius.circular(10),
            tabEdge: TabEdge.top,
            curve: Curves.easeIn,
            colors: const <Color>[Colors.white, Colors.white],
            selectedTextStyle: GoogleFonts.poppins(
              fontSize: 14.0,
              color: ColorUtils.primarycolor(),
              fontWeight: FontWeight.bold,
            ),
            unselectedTextStyle: GoogleFonts.poppins(
              fontSize: 13.0,
              color: Colors.white,
            ),
            tabs: const [Text('New Report'), Text('Past Reports')],
            children: [
              // Tab 1: New Report
              _isLoading
                  ? const Center(child: LoadingGif())
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _startDateController.text,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'to',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _endDateController.text,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _empIdController,
                          decoration: InputDecoration(
                            labelText: 'Employee ID',
                            labelStyle: GoogleFonts.poppins(fontSize: 13),
                            hintText: 'Enter Emp ID',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _error!,
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            color: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SummaryRow(
                                      label: 'Hourly',
                                      count: totals.hourlyCount,
                                      amount: totals.hourlyAmount,
                                    ),
                                    _SummaryRow(
                                      label: '12 Hours Pass',
                                      count: totals.pass12Count,
                                      amount: totals.pass12Amount,
                                    ),
                                    _SummaryRow(
                                      label: '24 Hours Pass',
                                      count: totals.pass24Count,
                                      amount: totals.pass24Amount,
                                    ),
                                    _SummaryRow(
                                      label: '48 Hours Pass',
                                      count: totals.pass48Count,
                                      amount: totals.pass48Amount,
                                    ),
                                    _SummaryRow(
                                      label: '72 Hours Pass',
                                      count: totals.pass72Count,
                                      amount: totals.pass72Amount,
                                    ),
                                    _SummaryRow(
                                      label: 'Weekly Pass (7 Days)',
                                      count: totals.weeklyCount,
                                      amount: totals.weeklyAmount,
                                    ),
                                    _SummaryRow(
                                      label: '15 Days Pass',
                                      count: totals.pass15Count,
                                      amount: totals.pass15Amount,
                                    ),
                                    _SummaryRow(
                                      label: 'Monthly Pass (30 Days)',
                                      count: totals.monthlyCount,
                                      amount: totals.monthlyAmount,
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Cash Total:',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '₹${totals.cashTotal.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Online Total:',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '₹${totals.onlineTotal.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Amount:',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '₹${(totals.cashTotal + totals.onlineTotal).toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'Bookings in range: ${filtered.length}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _printReport,
                            icon: const Icon(Icons.print),
                            label: Text(
                              'Generate & Print Report',
                              style: GoogleFonts.poppins(
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

              // Tab 2: Past Reports
              _buildReportHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHistoryList() {
    if (_isLoadingHistory) {
      return const Center(child: LoadingGif());
    }
    if (_pastReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No past reports found',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      itemCount: _pastReports.length,
      itemBuilder: (context, index) {
        final report = _pastReports[index];
        return _buildReportCard(report, index);
      },
    );
  }

  Widget _buildReportCard(dynamic report, int index) {
    final isSelected = _selectedReportIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReportIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date & Emp ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report['reportdate_time'] ?? 'N/A',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
              Text(
                'Emp ID: ${report['empid'] ?? 'N/A'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Cash, Online, Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash: ₹${report['cash'] ?? '0'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Online: ₹${report['online'] ?? '0'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total: ₹${report['totals'] ?? (double.parse(report['cash']?.toString() ?? '0') + double.parse(report['online']?.toString() ?? '0')).toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1),
          ),

          // Row 3: From & To
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabeledText('From: ', report['fromdate_time'] ?? 'N/A'),
              _buildLabeledText('To: ', report['todate_time'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: Entries & Exits (Car and Bike)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Car Stats
              Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    color: ColorUtils.primarycolor(),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  _buildLabeledText(
                    'Entries: ',
                    '${report['entry'] ?? 0}',
                    isBoldValue: true,
                  ),
                  const SizedBox(width: 12),
                  _buildLabeledText(
                    'Exits: ',
                    '${report['exit'] ?? 0}',
                    isBoldValue: true,
                  ),
                ],
              ),
              // Bike Stats (Using same entry/exit counts for now as backend doesn't split them)
              Row(
                children: [
                  Icon(
                    Icons.two_wheeler,
                    color: ColorUtils.primarycolor(),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  _buildLabeledText(
                    'Entries: ',
                    '${report['entry'] ?? 0}',
                    isBoldValue: true,
                  ),
                  const SizedBox(width: 12),
                  _buildLabeledText(
                    'Exits: ',
                    '${report['exit'] ?? 0}',
                    isBoldValue: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 5: Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _reprintReport(report),
                    icon: Icon(
                      Icons.print,
                      size: 16,
                      color: ColorUtils.primarycolor(),
                    ),
                    label: Text(
                      'Re-print Report',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.primarycolor(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor().withOpacity(
                        0.1,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showReportDetails(report);
                    },
                    icon: const Icon(
                      Icons.visibility,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'View Details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor(),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  void _showReportDetails(dynamic report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Report Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogRow('Hourly', report['hourlycount']?.toString() ?? '0', report['hourlyamount']?.toString() ?? '0'),
                  _buildDialogRow('12 Hours Pass', report['12hrsveh']?.toString() ?? '0', report['12hrsvehamt']?.toString() ?? '0'),
                  _buildDialogRow('24 Hours Pass', report['24hrsveh']?.toString() ?? '0', report['24hrsvehamt']?.toString() ?? '0'),
                  _buildDialogRow('48 Hours Pass', report['48hrsveh']?.toString() ?? '0', report['48hrsvehamt']?.toString() ?? '0'),
                  _buildDialogRow('72 Hours Pass', report['72hrsveh']?.toString() ?? '0', report['72hrsvehamt']?.toString() ?? '0'),
                  _buildDialogRow('Weekly Pass\n(7 Days)', report['7daysveh']?.toString() ?? '0', report['7daysvehamt']?.toString() ?? '0', isMultiline: true),
                  _buildDialogRow('15 Days Pass', report['15daysveh']?.toString() ?? '0', report['15daysvehamt']?.toString() ?? '0'),
                  _buildDialogRow('Monthly Pass\n(30 Days)', report['30daysveh']?.toString() ?? '0', report['30daysvehamt']?.toString() ?? '0', isMultiline: true),
                  const Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cash Total:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(report['cash']?.toString() ?? '0')}',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Online Total:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(report['online']?.toString() ?? '0')}',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_formatAmount(report['totals']?.toString() ?? (double.parse(report['cash']?.toString() ?? '0') + double.parse(report['online']?.toString() ?? '0')).toString())}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatAmount(String amountStr) {
    double parsed = double.tryParse(amountStr) ?? 0.0;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toStringAsFixed(2);
  }

  Widget _buildDialogRow(String label, String count, String amount, {bool isMultiline = false}) {
    double parsedAmount = double.tryParse(amount) ?? 0.0;
    String displayAmount = parsedAmount.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
              count,
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
              '₹$displayAmount',
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

  Widget _buildLabeledText(
    String label,
    String value, {
    bool isBoldValue = false,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
          ),
          TextSpan(
            text: value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reprintReport(dynamic report) async {
    try {
      // Fetch vendor name from the first booking if available, or use default
      String vendorName = 'Parking Location';
      if (_bookings.isNotEmpty) {
        vendorName =
            _bookings.first.vendorname.trim().isNotEmpty
                ? _bookings.first.vendorname
                : 'Parking Location';
      }

      final fromDateTime = report['fromdate_time']?.toString() ?? '';
      final toDateTime = report['todate_time']?.toString() ?? '';

      final fromParts = fromDateTime.split(' ');
      final toParts = toDateTime.split(' ');

      final reportFullDate = report['reportdate_time']?.toString() ?? '';
      final reportDate = reportFullDate.split(' ').first;
      final reportTime = reportFullDate.split(' ').sublist(1).join(' ');

      await UniversalPrintHelper.printSummaryReport(
        context: context,
        vendorId: widget.vendorid,
        vendorName: vendorName,
        empId: report['empid']?.toString() ?? 'N/A',
        reportDate: reportDate,
        reportTime: reportTime,
        fromDate: fromParts.isNotEmpty ? fromParts.first : 'N/A',
        fromTime:
            fromParts.length > 1 ? fromParts.sublist(1).join(' ') : '00:00',
        toDate: toParts.isNotEmpty ? toParts.first : 'N/A',
        toTime: toParts.length > 1 ? toParts.sublist(1).join(' ') : '23:59',
        entry: report['entry']?.toString() ?? '0',
        exit: report['exit']?.toString() ?? '0',
        hourlyCount:
            int.tryParse(report['hourlycount']?.toString() ?? '0') ?? 0,
        hourlyAmount:
            double.tryParse(report['hourlyamount']?.toString() ?? '0') ?? 0.0,
        pass12Count: int.tryParse(report['12hrsveh']?.toString() ?? '0') ?? 0,
        pass12Amount:
            double.tryParse(report['12hrsvehamt']?.toString() ?? '0') ?? 0.0,
        pass24Count: int.tryParse(report['24hrsveh']?.toString() ?? '0') ?? 0,
        pass24Amount:
            double.tryParse(report['24hrsvehamt']?.toString() ?? '0') ?? 0.0,
        pass48Count: int.tryParse(report['48hrsveh']?.toString() ?? '0') ?? 0,
        pass48Amount:
            double.tryParse(report['48hrsvehamt']?.toString() ?? '0') ?? 0.0,
        pass72Count: int.tryParse(report['72hrsveh']?.toString() ?? '0') ?? 0,
        pass72Amount:
            double.tryParse(report['72hrsvehamt']?.toString() ?? '0') ?? 0.0,
        weeklyCount: int.tryParse(report['7daysveh']?.toString() ?? '0') ?? 0,
        weeklyAmount:
            double.tryParse(report['7daysvehamt']?.toString() ?? '0') ?? 0.0,
        pass15Count: int.tryParse(report['15daysveh']?.toString() ?? '0') ?? 0,
        pass15Amount:
            double.tryParse(report['15daysvehamt']?.toString() ?? '0') ?? 0.0,
        monthlyCount: int.tryParse(report['30daysveh']?.toString() ?? '0') ?? 0,
        monthlyAmount:
            double.tryParse(report['30daysvehamt']?.toString() ?? '0') ?? 0.0,
        cashTotal: double.tryParse(report['cash']?.toString() ?? '0') ?? 0.0,
        onlineTotal:
            double.tryParse(report['online']?.toString() ?? '0') ?? 0.0,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reprint failed: $e')));
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final double amount;

  const _SummaryRow({
    required this.label,
    required this.count,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              count.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 90,
            child: Text(
              '₹${amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTotals {
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
