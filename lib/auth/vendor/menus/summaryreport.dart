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
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../customer/parking/bookparking.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    final url = Uri.parse(
      '${ApiConfig.baseUrl}vendor/getreports/${widget.vendorid}',
    );
    try {
      var data = LocalDbService.getCachedApiResponse(url.toString());
      if (isOnline) {
        try {
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final serverData = json.decode(response.body);
            final serverReports = (serverData['reports'] as List?) ?? [];
            final localReports = (data?['reports'] as List?) ?? [];

            // Merge local and server reports, avoiding duplicates by reportdate_time
            final Map<String, dynamic> mergedMap = {};
            for (var r in localReports) {
              final key = r['reportdate_time']?.toString() ?? '';
              if (key.isNotEmpty) mergedMap[key] = r;
            }
            for (var r in serverReports) {
              final key = r['reportdate_time']?.toString() ?? '';
              if (key.isNotEmpty) mergedMap[key] = r;
            }

            final mergedList = mergedMap.values.toList();
            // Sort descending by trying to parse the date
            mergedList.sort((a, b) {
              final strA = a['reportdate_time']?.toString() ?? '';
              final strB = b['reportdate_time']?.toString() ?? '';
              try {
                DateTime dA;
                DateTime dB;
                try {
                  dA = DateFormat(
                    'dd-MM-yyyy hh:mm a',
                  ).parse(strA.toUpperCase());
                } catch (_) {
                  dA = DateFormat('d-M-yyyy hh:mm a').parse(strA.toUpperCase());
                }
                try {
                  dB = DateFormat(
                    'dd-MM-yyyy hh:mm a',
                  ).parse(strB.toUpperCase());
                } catch (_) {
                  dB = DateFormat('d-M-yyyy hh:mm a').parse(strB.toUpperCase());
                }
                return dB.compareTo(dA);
              } catch (_) {
                return 0;
              }
            });

            data = {'reports': mergedList};
            LocalDbService.cacheApiResponse(url.toString(), data);
          }
        } catch (_) {}
      }

      if (data != null) {
        final reports = (data['reports'] as List?) ?? [];

        // Seed start date from the most-recent report (replaces _fetchLastReport)
        if (reports.isNotEmpty) {
          final toDateStr = reports.first['todate_time']?.toString() ?? '';
          try {
            DateTime lastEnd;
            final upperToDateStr = toDateStr.toUpperCase();
            if (upperToDateStr.contains('AM') ||
                upperToDateStr.contains('PM')) {
              try {
                lastEnd = DateFormat(
                  'dd-MM-yyyy hh:mm a',
                ).parse(upperToDateStr);
              } catch (_) {
                lastEnd = DateFormat('d-M-yyyy hh:mm a').parse(upperToDateStr);
              }
            } else {
              try {
                lastEnd = DateFormat('dd-MM-yyyy HH:mm').parse(toDateStr);
              } catch (_) {
                lastEnd = DateFormat('d-M-yyyy HH:mm').parse(toDateStr);
              }
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

  @override
  void dispose() {
    _tabController.dispose();
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
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      final now = DateTime.now();
      DateTime earliestStart = _selectedStartDate ?? _defaultStartDate;
      if (now.isBefore(earliestStart)) {
        earliestStart = now;
      }
      DateTime latestEnd = _selectedEndDate ?? _defaultEndDate;
      if (now.isAfter(latestEnd)) {
        latestEnd = now;
      }

      // Buffer API query by 1 day on both sides to handle UTC vs IST timezone disparities (e.g. 12:00 AM - 05:30 AM IST).
      // Exact filtering is performed locally in _filteredBookings() and _computeTotals().
      final queryStart = DateFormat(
        'dd-MM-yyyy',
      ).format(earliestStart.subtract(const Duration(days: 1)));
      final queryEnd = DateFormat(
        'dd-MM-yyyy',
      ).format(latestEnd.add(const Duration(days: 1)));

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
            "Online fetch failed in SummaryReport, falling back to cache: $e",
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
                  final s = args.value.startDate as DateTime?;
                  final e =
                      (args.value.endDate ?? args.value.startDate) as DateTime?;
                  setState(() {
                    _selectedStartDate =
                        s != null
                            ? DateTime(s.year, s.month, s.day, 0, 0, 0)
                            : null;
                    _selectedEndDate =
                        e != null
                            ? DateTime(e.year, e.month, e.day, 23, 59, 59, 999)
                            : null;
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

  bool _isDateTimeAfterStart(DateTime dt, DateTime start, bool isFirstReport) {
    if (isFirstReport) {
      return dt.isAtSameMomentAs(start) || dt.isAfter(start);
    }
    // For subsequent reports, start represents the cutoff of the previous report.
    // If dt is at or before start, it was already included in the previous report.
    if (dt.isBefore(start) || dt.isAtSameMomentAs(start)) {
      return false;
    }
    // If start is at minute precision (seconds == 0 and ms == 0),
    // any booking occurring in that same minute (e.g. 15:52:15 when cutoff is 15:52:00)
    // was already covered in that previous report.
    if (start.second == 0 && start.millisecond == 0) {
      if (dt.year == start.year &&
          dt.month == start.month &&
          dt.day == start.day &&
          dt.hour == start.hour &&
          dt.minute == start.minute) {
        return false;
      }
    }
    return dt.isAfter(start);
  }

  List<Bookingdata> _filterBookingsInRange({
    required DateTime start,
    required DateTime end,
    required bool isInclusiveStart,
  }) {
    return _bookings.where((b) {
      if (b.Vendorid.isNotEmpty &&
          widget.vendorid.isNotEmpty &&
          b.Vendorid.trim().toLowerCase() != widget.vendorid.trim().toLowerCase()) {
        return false;
      }

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
            _isDateTimeAfterStart(bookingDateTime, start, isInclusiveStart) &&
            (bookingDateTime.isAtSameMomentAs(end) ||
                bookingDateTime.isBefore(end));
      }

      final isExitedStatus = _isBookingExited(b);

      bool isExitedInRange = false;
      if (isExitedStatus && exitDateTime != null) {
        isExitedInRange =
            _isDateTimeAfterStart(exitDateTime, start, isInclusiveStart) &&
            (exitDateTime.isAtSameMomentAs(end) || exitDateTime.isBefore(end));
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

  List<Bookingdata> _filteredBookings() {
    DateTime start = _selectedStartDate ?? _defaultStartDate;
    DateTime end = _selectedEndDate ?? _defaultEndDate;

    if (_isFirstReport) {
      start = DateTime(start.year, start.month, start.day, 0, 0, 0);
      end = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    } else {
      final now = DateTime.now();
      if (end.isBefore(now)) {
        end = now.add(const Duration(minutes: 5));
      }
    }

    return _filterBookingsInRange(
      start: start,
      end: end,
      isInclusiveStart: _isFirstReport,
    );
  }

  List<Bookingdata> _filteredTodayBookings() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return _filterBookingsInRange(
      start: start,
      end: end,
      isInclusiveStart: true,
    );
  }

  double _amountForBooking(Bookingdata b) {
    String s = b.totalamout.trim();
    if (s.isEmpty || s == '0' || s == '0.0' || s == '0.00') {
      s = b.amount.trim();
    }
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

    // totalamout / amount already contains the complete final collected amount (base parking + valet charge + fees).
    // Do not add valetAmount again to prevent double counting.
    return baseAmount;
  }

  _SummaryTotals _computeTotals(
    List<Bookingdata> list, {
    DateTime? customStart,
    DateTime? customEnd,
    bool? customInclusiveStart,
  }) {
    DateTime start;
    DateTime end;
    bool inclusive;

    if (customStart != null && customEnd != null) {
      start = customStart;
      end = customEnd;
      inclusive = customInclusiveStart ?? true;
    } else {
      start = _selectedStartDate ?? _defaultStartDate;
      end = _selectedEndDate ?? _defaultEndDate;

      if (_isFirstReport) {
        start = DateTime(start.year, start.month, start.day, 0, 0, 0);
        end = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
      } else {
        final now = DateTime.now();
        if (end.isBefore(now)) {
          end = now.add(const Duration(minutes: 5));
        }
      }
      inclusive = _isFirstReport;
    }

    final totals = _SummaryTotals();
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
            _isDateTimeAfterStart(bookingDateTime, start, inclusive) &&
            (bookingDateTime.isAtSameMomentAs(end) ||
                bookingDateTime.isBefore(end));
      }

      final isExitedStatus = _isBookingExited(b);

      bool isExitedInRange = false;
      if (isExitedStatus && exitDateTime != null) {
        isExitedInRange =
            _isDateTimeAfterStart(exitDateTime, start, inclusive) &&
            (exitDateTime.isAtSameMomentAs(end) || exitDateTime.isBefore(end));
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
    final bodyData = {
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
    };

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (isOnline) {
        final url = Uri.parse('${ApiConfig.baseUrl}vendor/savereport');
        final headers = {'Content-Type': 'application/json'};
        final body = json.encode(bodyData);

        try {
          await http.post(url, headers: headers, body: body);
        } catch (_) {}
      }

      // ALWAYS Add this report to the local cache so it appears in Past Reports,
      // even if online, in case the backend takes time to index the new report.
      final urlStr = '${ApiConfig.baseUrl}vendor/getreports/${widget.vendorid}';
      var data = LocalDbService.getCachedApiResponse(urlStr) ?? {'reports': []};
      List<dynamic> reports = data['reports'] ?? [];
      reports.insert(0, bodyData);
      data['reports'] = reports;
      LocalDbService.cacheApiResponse(urlStr, data);
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

    final startDate = _selectedStartDate ?? _defaultStartDate;
    final endDate = now;

    // Normalize the printed start time to 00:00:00 for the first report
    // so it perfectly matches the inclusive filter applied to bookings.
    final printedStartDate =
        _isFirstReport
            ? DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0)
            : startDate;

    final entryCount =
        _bookings.where((b) {
          if (b.Vendorid != widget.vendorid) return false;
          final dt = _combineDateTime(b.bookingDate, b.bookingTime);
          if (dt == null) return false;
          return _isDateTimeAfterStart(dt, printedStartDate, _isFirstReport) &&
              (dt.isAtSameMomentAs(endDate) || dt.isBefore(endDate));
        }).length;

    final exitCount =
        _bookings.where((b) {
          if (b.Vendorid != widget.vendorid) return false;
          if (!_isBookingExited(b)) return false;
          final dt = _combineDateTime(b.exitvehicledate, b.exitvehicletime);
          if (dt == null) return false;
          return _isDateTimeAfterStart(dt, printedStartDate, _isFirstReport) &&
              (dt.isAtSameMomentAs(endDate) || dt.isBefore(endDate));
        }).length;

    final reportDate = DateFormat('dd-MM-yyyy').format(now);
    final reportTime = DateFormat('hh:mm a').format(now);

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

    final reportBoundaryTime =
        DateTime(now.year, now.month, now.day, now.hour, now.minute);

    if (mounted) {
      setState(() {
        _isFirstReport = false;
        _lastReportEndTime = reportBoundaryTime;
        _selectedStartDate = reportBoundaryTime;
        _selectedEndDate = reportBoundaryTime;
        final formatted =
            DateFormat('dd-MM-yyyy hh:mm a').format(reportBoundaryTime);
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
        titleSpacing: 0,
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
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: TextButton(
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
              style: TextButton.styleFrom(
                foregroundColor: ColorUtils.primarycolor(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                'Custom Report',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.primarycolor(),
                ),
              ),
            ),
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
            colors: const <Color>[
              Colors.white,
              Colors.white,
              Colors.white,
            ],
            selectedTextStyle: GoogleFonts.poppins(
              fontSize: 12.0,
              color: ColorUtils.primarycolor(),
              fontWeight: FontWeight.bold,
            ),
            unselectedTextStyle: GoogleFonts.poppins(
              fontSize: 11.5,
              color: Colors.white,
            ),
            tabs: const [
              Text('New Report'),
              Text('Past Reports'),
              Text("Today's Reports"),
            ],
            children: [
              // Tab 1: New Report
              _isLoading
                  ? const Center(child: LoadingGif())
                  : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
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
                          child: _buildSummaryCardContent(
                            totals: totals,
                            bookingCount: filtered.length,
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

              // Tab 3: Today's Reports
              _buildTodayReportTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCardContent({
    required _SummaryTotals totals,
    required int bookingCount,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  'Bookings in range: $bookingCount',
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
    );
  }

  Widget _buildTodayReportTab() {
    if (_isLoading) {
      return const Center(child: LoadingGif());
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final todayFiltered = _filteredTodayBookings();
    final todayTotals = _computeTotals(
      todayFiltered,
      customStart: todayStart,
      customEnd: todayEnd,
      customInclusiveStart: true,
    );

    final todayStr = DateFormat('dd-MM-yyyy').format(now);
    final currentTimeStr = DateFormat('hh:mm a').format(now);

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 12,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$todayStr 12:00 AM',
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
                  '$todayStr $currentTimeStr',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _isLoading ? null : () => _fetchBookings(),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: ColorUtils.primarycolor(),
                    ),
                  ),
                ),
              ],
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
              child: _buildSummaryCardContent(
                totals: todayTotals,
                bookingCount: todayFiltered.length,
              ),
            ),
          ],
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
      ),
    );
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
                  _buildDialogRow(
                    'Hourly',
                    report['hourlycount']?.toString() ?? '0',
                    report['hourlyamount']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    '12 Hours Pass',
                    report['12hrsveh']?.toString() ?? '0',
                    report['12hrsvehamt']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    '24 Hours Pass',
                    report['24hrsveh']?.toString() ?? '0',
                    report['24hrsvehamt']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    '48 Hours Pass',
                    report['48hrsveh']?.toString() ?? '0',
                    report['48hrsvehamt']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    '72 Hours Pass',
                    report['72hrsveh']?.toString() ?? '0',
                    report['72hrsvehamt']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    'Weekly Pass\n(7 Days)',
                    report['7daysveh']?.toString() ?? '0',
                    report['7daysvehamt']?.toString() ?? '0',
                    isMultiline: true,
                  ),
                  _buildDialogRow(
                    '15 Days Pass',
                    report['15daysveh']?.toString() ?? '0',
                    report['15daysvehamt']?.toString() ?? '0',
                  ),
                  _buildDialogRow(
                    'Monthly Pass\n(30 Days)',
                    report['30daysveh']?.toString() ?? '0',
                    report['30daysvehamt']?.toString() ?? '0',
                    isMultiline: true,
                  ),
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

  Widget _buildDialogRow(
    String label,
    String count,
    String amount, {
    bool isMultiline = false,
  }) {
    double parsedAmount = double.tryParse(amount) ?? 0.0;
    String displayAmount = parsedAmount.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
