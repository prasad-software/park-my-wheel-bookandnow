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
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../customer/parking/bookparking.dart';

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
  Vendor? _vendor = GlobalVendorDashCache.vendor;

  Future<void> _fetchVendorData() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] != null && mounted) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            GlobalVendorDashCache.vendor = _vendor;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    if (_vendor == null) {
      _fetchVendorData();
    }
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      final queryStart = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedStartDateTime.subtract(const Duration(days: 1)));
      final queryEnd = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedEndDateTime.add(const Duration(days: 1)));

      List<Bookingdata> list = [];
      bool fetchSuccess = false;

      if (isOnline) {
        try {
          final url = Uri.parse(
            '${ApiConfig.baseUrl}vendor/fast-summary/${widget.vendorid}?startDate=$queryStart&endDate=$queryEnd',
          );
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final Map<String, dynamic> jsonResponse = json.decode(
              response.body,
            );
            final List<dynamic>? data = jsonResponse['bookings'];
            final List<Map<String, dynamic>> mapsList =
                (data ?? [])
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList();
            LocalDbService.applyPendingExitsToMaps(mapsList);
            list = mapsList.map((m) => Bookingdata.fromJson(m)).toList();
            fetchSuccess = true;
          }
        } catch (e) {
          print(
            "Online fetch failed in CustomReport, falling back to cache: $e",
          );
        }
      }

      if (!fetchSuccess) {
        // Offline mode or fallback: Combine all cached dashboard bookings
        List<Map<String, dynamic>> allBookingsMap =
            LocalDbService.getAllCachedDashboardBookings(widget.vendorid);

        Map<String, Map<String, dynamic>> combined = {};
        for (var b in allBookingsMap) {
          String id = b['_id']?.toString() ?? b['id']?.toString() ?? '';
          if (id.isNotEmpty) combined[id] = b;
        }

        final mapsList = combined.values.toList();
        LocalDbService.applyPendingExitsToMaps(mapsList);
        list = mapsList.map((m) => Bookingdata.fromJson(m)).toList();
      }

      // ALWAYS append pending offline bookings, since they might not be on the server yet
      List<Map<String, dynamic>> pendingOffline =
          LocalDbService.getOfflineBookingsForVendor(widget.vendorid, '');
      List<Bookingdata> pendingList =
          pendingOffline
              .map((m) => Bookingdata.fromJson(Map<String, dynamic>.from(m)))
              .toList();

      Map<String, Bookingdata> finalMap = {};
      for (var b in pendingList) {
        if (b.id.isNotEmpty) finalMap[b.id] = b;
      }
      for (var b in list) {
        if (b.id.isNotEmpty) finalMap[b.id] = b;
      }

      list = finalMap.values.toList();

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
    final d = date.trim();
    final t = time.trim();
    if (d.isEmpty || d.toLowerCase() == 'null') return null;

    final isoFromDate = DateTime.tryParse(d);
    if (isoFromDate != null && (t.isEmpty || t.toLowerCase() == 'null')) {
      return isoFromDate;
    }

    final combined =
        (t.isEmpty || t.toLowerCase() == 'null')
            ? d
            : '$d $t'.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();

    final isoFromCombined = DateTime.tryParse(combined);
    if (isoFromCombined != null) return isoFromCombined;

    const formats = [
      'dd-MM-yyyy hh:mm:ss a',
      'dd-MM-yyyy hh:mm a',
      'dd-MM-yyyy h:mm:ss a',
      'dd-MM-yyyy h:mm a',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm:ss.SSS',
      'dd-MM-yyyy HH:mm',
      'd-M-yyyy hh:mm:ss a',
      'd-M-yyyy hh:mm a',
      'd-M-yyyy h:mm:ss a',
      'd-M-yyyy h:mm a',
      'd-M-yyyy HH:mm:ss',
      'd-M-yyyy HH:mm',
      'yyyy-MM-dd hh:mm:ss a',
      'yyyy-MM-dd hh:mm a',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'd-M-yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(combined);
      } catch (_) {}
    }
    return null;
  }

  bool _isBookingExited(Bookingdata b) {
    final status = b.status.trim().toUpperCase();
    final exitDate = b.exitvehicledate.trim();
    final exitTime = b.exitvehicletime.trim();

    final hasExitDate = exitDate.isNotEmpty && exitDate.toLowerCase() != 'null';
    final hasExitTime = exitTime.isNotEmpty && exitTime.toLowerCase() != 'null';

    if (status == 'COMPLETED') {
      return true;
    }

    if (GlobalRecentExits.exitedBookingIds.contains(b.id)) {
      return true;
    }

    // If it has valid exit date/time and is not in an active parked/booked status
    if (hasExitDate &&
        hasExitTime &&
        status != 'PARKED' &&
        status != 'BOOKED' &&
        status != 'PENDING' &&
        status != 'APPROVED' &&
        status != 'ACTIVE') {
      return true;
    }

    return false;
  }

  List<Bookingdata> _filteredBookings() {
    return _bookings.where((b) {
      if (b.Vendorid != widget.vendorid) return false;

      final bookingDateTime = _combineDateTime(
        b.bookingDate.isNotEmpty ? b.bookingDate : (b.parkeddate.isNotEmpty ? b.parkeddate : b.parkingDate),
        b.bookingTime.isNotEmpty ? b.bookingTime : (b.parkedtime.isNotEmpty ? b.parkedtime : b.parkingTime),
      );
      final exitDateTime = _combineDateTime(
        b.exitvehicledate,
        b.exitvehicletime,
      ) ?? bookingDateTime;

      bool isBookedInRange = false;
      if (bookingDateTime != null) {
        isBookedInRange =
            (bookingDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                bookingDateTime.isAfter(_selectedStartDateTime)) &&
            (bookingDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                bookingDateTime.isBefore(_selectedEndDateTime));
      }

      final isExitedStatus = _isBookingExited(b);

      bool isExitedInRange = false;
      if (isExitedStatus && exitDateTime != null) {
        isExitedInRange =
            (exitDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                exitDateTime.isAfter(_selectedStartDateTime)) &&
            (exitDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                exitDateTime.isBefore(_selectedEndDateTime));
      }

      final isPassOrSub = isPassOrSubscriptionSts(b.sts, b.bookType);

      // Passes (12, 24/Full Day, 48, 72) and Subscriptions (Weekly, 15-day, Monthly)
      // are paid upfront upon booking -> include in summary report when booked in range!
      if (isPassOrSub) {
        return isBookedInRange;
      }

      // Purely Hourly / Instant parking (no pass) is paid upon exit:
      // DO NOT add count and amount when booked / parked.
      // ONLY add count and amount after vehicle has exited within range.
      return isExitedStatus && isExitedInRange;
    }).toList();
  }

  double _amountForBooking(Bookingdata b) {
    final s = (b.totalamout.trim().isNotEmpty ? b.totalamout : b.amount).trim();
    double baseAmount = double.tryParse(s) ?? 0.0;
    final isPassOrSub = isPassOrSubscriptionSts(b.sts, b.bookType);

    // Purely Hourly / Instant bookings (no pass): strictly collected upon exit.
    // While booked / parked (not exited), amount must be 0.0.
    if (!isPassOrSub && !_isBookingExited(b)) {
      return 0.0;
    }

    final v = _vendor ?? GlobalVendorDashCache.vendor;
    if (!isPassOrSub && v != null) {
      final vType = b.vehicletype.toLowerCase();
      double cap = 0.0;
      if (vType.contains('bike')) {
        cap = v.maxBikeAmount;
      } else if (vType.contains('car')) {
        cap = v.maxCarAmount;
      } else {
        cap = v.maxOthersAmount;
      }
      if (cap > 0 && baseAmount > cap) {
        baseAmount = cap;
      }
    }

    final valetAmount =
        isPassOrSub ? 0.0 : (double.tryParse(b.valetCharge) ?? 0.0);
    double total = baseAmount;
    if (v == null || v.maxCarAmount <= 0 || baseAmount < v.maxCarAmount) {
      total += valetAmount;
      if (v != null && v.maxCarAmount > 0 && total > v.maxCarAmount) {
        total = v.maxCarAmount;
      }
    }
    return total;
  }

  _CustomSummaryTotals _computeTotals(List<Bookingdata> list) {
    final totals = _CustomSummaryTotals();
    for (final b in list) {
      final bookingDateTime = _combineDateTime(
        b.bookingDate.isNotEmpty ? b.bookingDate : (b.parkeddate.isNotEmpty ? b.parkeddate : b.parkingDate),
        b.bookingTime.isNotEmpty ? b.bookingTime : (b.parkedtime.isNotEmpty ? b.parkedtime : b.parkingTime),
      );
      final exitDateTime = _combineDateTime(
        b.exitvehicledate,
        b.exitvehicletime,
      ) ?? bookingDateTime;

      bool isBookedInRange = false;
      if (bookingDateTime != null) {
        isBookedInRange =
            (bookingDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                bookingDateTime.isAfter(_selectedStartDateTime)) &&
            (bookingDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                bookingDateTime.isBefore(_selectedEndDateTime));
      }

      final isExitedStatus = _isBookingExited(b);

      bool isExitedInRange = false;
      if (isExitedStatus && exitDateTime != null) {
        isExitedInRange =
            (exitDateTime.isAtSameMomentAs(_selectedStartDateTime) ||
                exitDateTime.isAfter(_selectedStartDateTime)) &&
            (exitDateTime.isAtSameMomentAs(_selectedEndDateTime) ||
                exitDateTime.isBefore(_selectedEndDateTime));
      }

      final isPassOrSub = isPassOrSubscriptionSts(b.sts, b.bookType);

      // Passes and Subscriptions are paid upfront; only include in totals if booked during this report's range.
      if (isPassOrSub && !isBookedInRange) {
        continue;
      }

      // Purely Hourly / Instant parking (no pass): do NOT add count and amount when booked.
      // Only include count and amount after vehicle has exited within range.
      if (!isPassOrSub && (!isExitedStatus || !isExitedInRange)) {
        continue;
      }

      final amount = _amountForBooking(b);
      final sts = b.sts.trim().toLowerCase();

      if (RegExp(r'^\d+(?:hr|h)?$', caseSensitive: false).hasMatch(sts) ||
          sts == 'fullday' ||
          sts == 'full day' ||
          b.bookType.trim().toLowerCase() == '24 hours' ||
          b.bookType.trim().toLowerCase() == '24hours') {
        int hours = 0;
        if (sts == 'fullday' ||
            sts == 'full day' ||
            b.bookType.trim().toLowerCase() == '24 hours' ||
            b.bookType.trim().toLowerCase() == '24hours') {
          hours = 24;
        } else {
          hours = int.tryParse(sts.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
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

    final entryCount =
        _bookings.where((b) {
          if (b.Vendorid != widget.vendorid) return false;
          final dt = _combineDateTime(b.bookingDate, b.bookingTime);
          if (dt == null) return false;
          return (dt.isAtSameMomentAs(_selectedStartDateTime) ||
                  dt.isAfter(_selectedStartDateTime)) &&
              (dt.isAtSameMomentAs(_selectedEndDateTime) ||
                  dt.isBefore(_selectedEndDateTime));
        }).length;

    final exitCount =
        _bookings.where((b) {
          if (b.Vendorid != widget.vendorid) return false;
          if (!_isBookingExited(b)) return false;
          final dt = _combineDateTime(b.exitvehicledate, b.exitvehicletime);
          if (dt == null) return false;
          return (dt.isAtSameMomentAs(_selectedStartDateTime) ||
                  dt.isAfter(_selectedStartDateTime)) &&
              (dt.isAtSameMomentAs(_selectedEndDateTime) ||
                  dt.isBefore(_selectedEndDateTime));
        }).length;

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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
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
              Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade700),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 16.0,
                ),
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
                                  onPressed:
                                      () => _printReport(filtered, totals),
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
