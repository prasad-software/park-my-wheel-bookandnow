import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/vendor/paytimeamount.dart';
import 'package:mywheels/auth/vendor/subscription/vendorsubscriptonbooking.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/utils/sts_utils.dart';
import '../../config/authconfig.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/customer/parking/parkindetails.dart';
import 'package:tab_container/tab_container.dart';
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';

class vSearchScreen extends StatefulWidget {
  final String vendorid;
  const vSearchScreen({super.key, required this.vendorid});

  @override
  _vSearchScreenState createState() => _vSearchScreenState();
}

class _vSearchScreenState extends State<vSearchScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> filteredVendors = [];
  List<Map<String, dynamic>> allVendors = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool hasError = false;
  late Timer _payableTimer;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final Map<String, bool> _isExiting = {};
  final Map<String, bool> _isCheckingExit =
      {}; // awaiting amount before showing exit popup

  static const Duration _printTimeout = Duration(seconds: 18);
  static const Duration _apiTimeout = Duration(seconds: 20);
  static const Duration _exitApiTimeout = Duration(seconds: 30);

  void _setExiting(String bookingId, bool isExiting) {
    if (!mounted || bookingId.isEmpty) return;
    setState(() {
      if (isExiting) {
        _isExiting[bookingId] = true;
      } else {
        _isExiting.remove(bookingId);
      }
    });
  }

  /// Fetch payable amount first. If ₹0, exit directly without popup; otherwise show Exitpage.
  Future<void> _handleExitButtonPressed(
    Map<String, dynamic> vehicle,
    String bookingId,
  ) async {
    if (bookingId.isEmpty || !mounted) return;
    if (_isCheckingExit[bookingId] == true || _isExiting[bookingId] == true)
      return;

    setState(() => _isCheckingExit[bookingId] = true);
    try {
      String amountStr = '0';
      try {
        amountStr = await UniversalPrintHelper.getPrintAmountFromAPI(
          bookingId,
        ).timeout(_apiTimeout);
      } catch (_) {}

      final amountVal = double.tryParse(amountStr.trim()) ?? 0.0;

      if (!mounted) return;

      if (amountVal <= 0) {
        // ₹0 — exit immediately without showing the popup
        setState(() => _isCheckingExit.remove(bookingId));
        await _performQuickExit(vehicle, '0');
      } else {
        setState(() => _isCheckingExit.remove(bookingId));
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return DraggableScrollableSheet(
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Exitpage(
                    currentTabIndex: 0,
                    userid: vehicle['userid'] ?? vehicle['userId'] ?? '',
                    otp: vehicle['otp'] ?? '',
                    vehicletype: vehicle['vehicleType'] ?? '',
                    bookingid: bookingId,
                    parkingdate:
                        vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '',
                    vehiclenumber: vehicle['vehicleNumber'] ?? '',
                    username: vehicle['personName'] ?? '',
                    phoneno: vehicle['mobileNumber'] ?? '',
                    parkingtime:
                        vehicle['parkedTime'] ?? vehicle['parkingTime'] ?? '',
                    bookingtypetemporary: vehicle['status'] ?? '',
                    sts: vehicle['sts'] ?? '',
                    cartype: vehicle['carType'] ?? '',
                    vendorid: vehicle['vendorId'] ?? widget.vendorid,
                    bookType: vehicle['bookType'] ?? '',
                    onExitSuccess: () => fetchVendors(),
                  ),
                );
              },
            );
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingExit.remove(bookingId));
    }
  }

  @override
  void initState() {
    super.initState();
    print('initState: Fetching vendors for vendorid: ${widget.vendorid}');

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
      filterVendors(searchController.text);
    });

    fetchVendors();
    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });
  }

  @override
  void dispose() {
    _payableTimer.cancel();
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void updatePayableTimes() {
    if (!mounted) return;

    print(
      'updatePayableTimes: Updating payable times for ${filteredVendors.length} vehicles',
    );
    setState(() {
      filteredVendors =
          filteredVendors.map((vehicle) {
            if (vehicle['status'] == 'PARKED' ||
                vehicle['status'] == 'parked') {
              try {
                final parkedDateTime = _parseDateTime(
                  vehicle['parkedDate'] ?? vehicle['parkingDate'],
                  vehicle['parkedTime'] ?? vehicle['parkingTime'],
                );
                final elapsed = DateTime.now().difference(parkedDateTime);
                vehicle['payableDuration'] = elapsed;
                print(
                  'updatePayableTimes: Vehicle ${vehicle['vehicleNumber']} duration: $elapsed',
                );
              } catch (e) {
                print(
                  'updatePayableTimes: Error calculating payable time for ${vehicle['vehicleNumber']}: $e',
                );
              }
            }
            return vehicle;
          }).toList();
    });
  }

  DateTime _parseDateTime(String dateStr, String timeStr) {
    print('parseDateTime: Parsing date: $dateStr, time: $timeStr');
    try {
      final dateParts = dateStr.split('-');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeFormat = DateFormat('hh:mm a');
      final time = timeFormat.parse(timeStr);

      final parsedDateTime = DateTime(
        year,
        month,
        day,
        time.hour,
        time.minute,
        time.second,
      );
      print('parseDateTime: Successfully parsed to $parsedDateTime');
      return parsedDateTime;
    } catch (e) {
      print('parseDateTime: Error parsing date/time: $dateStr $timeStr - $e');
      return DateTime.now();
    }
  }

  DateTime? _parseSubscriptionEndDate(String? endDateStr) {
    if (endDateStr == null || endDateStr.isEmpty) return null;
    try {
      final datePart = endDateStr.split(' ')[0];
      final dateParts = datePart.split('-');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      print(
        'parseSubscriptionEndDate: Error parsing end date: $endDateStr - $e',
      );
      return null;
    }
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      default:
        return Icons.directions_transit;
    }
  }

  Future<void> fetchVendors() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}vendor/searchscreen/${widget.vendorid}',
            ),
          )
          .timeout(_apiTimeout);

      List<Map<String, dynamic>> combinedList = [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> bookings =
            data['bookings'] is List ? data['bookings'] as List<dynamic> : [];

        for (var booking in bookings) {
          final String id =
              booking['_id']?.toString() ?? booking['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final Map<String, dynamic> vehicleMap = Map<String, dynamic>.from(
              booking as Map,
            );
            vehicleMap['_id'] = id;
            vehicleMap['id'] = id;
            combinedList.add(vehicleMap);
          }
        }
      }

      if (combinedList.isEmpty) {
        setState(() {
          allVendors = [];
          filteredVendors = [];
          isLoading = false;
        });
        return;
      }

      // Initialize default values for missing fields
      for (var vehicle in combinedList) {
        vehicle['vehicleNumber'] ??= 'Unknown';
        vehicle['status'] ??= 'Unknown';

        // Normalize date/time keys
        final String pDate =
            vehicle['parkedDate'] ??
            vehicle['parkingDate'] ??
            DateFormat('dd-MM-yyyy').format(DateTime.now());
        final String pTime =
            vehicle['parkedTime'] ??
            vehicle['parkingTime'] ??
            DateFormat('hh:mm a').format(DateTime.now());

        vehicle['parkedDate'] = pDate;
        vehicle['parkingDate'] = pDate;
        vehicle['parkedTime'] = pTime;
        vehicle['parkingTime'] = pTime;
        vehicle['vehicleType'] ??= 'Unknown';
        // Use subsctiptiontype (typo in DB) if sts is missing for subscriptions
        vehicle['sts'] =
            (vehicle['sts'] != null &&
                    vehicle['sts'].toString().isNotEmpty &&
                    vehicle['sts'] != 'Unknown')
                ? vehicle['sts']
                : (vehicle['subsctiptiontype'] ?? 'Unknown');

        if (vehicle['status'].toString().toLowerCase() == 'parked' &&
            isVendorShortParkingSts(vehicle['sts'])) {
          try {
            final parkedDateTime = _parseDateTime(
              vehicle['parkedDate'],
              vehicle['parkedTime'],
            );
            vehicle['payableDuration'] = DateTime.now().difference(
              parkedDateTime,
            );
          } catch (e) {
            print(
              'fetchVendors: Error initializing payable time for ${vehicle['vehicleNumber']}: $e',
            );
            vehicle['payableDuration'] = Duration.zero;
          }
        }
      }

      // Sort by latest first
      combinedList.sort((a, b) {
        final createdAtA =
            a['createdAt'] != null
                ? DateTime.parse(a['createdAt'])
                : DateTime(0);
        final createdAtB =
            b['createdAt'] != null
                ? DateTime.parse(b['createdAt'])
                : DateTime(0);
        return createdAtB.compareTo(createdAtA);
      });

      setState(() {
        allVendors = combinedList;
        filterVendors(searchController.text);
        isLoading = false;
      });

      print(
        'fetchVendors: Loaded ${allVendors.length} total bookings from merged APIs',
      );
    } catch (e) {
      print('fetchVendors: Error occurred - $e');
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  bool _isSameDay(String dateStr1, String dateStr2) {
    if (dateStr1.isEmpty || dateStr2.isEmpty) return false;

    // Normalize dates to handle leading zeros (e.g., 2-5-2025 vs 02-05-2025)
    DateTime? d1 = _parseFlexibleDate(dateStr1);
    DateTime? d2 = _parseFlexibleDate(dateStr2);

    if (d1 == null || d2 == null) return dateStr1 == dateStr2;

    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  DateTime? _parseFlexibleDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      // Try multiple formats or split manually
      final parts = dateStr.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        int day, month, year;
        if (parts[0].length == 4) {
          year = int.parse(parts[0]);
          month = int.parse(parts[1]);
          day = int.parse(parts[2]);
        } else {
          day = int.parse(parts[0]);
          month = int.parse(parts[1]);
          year = int.parse(parts[2]);
        }
        return DateTime(year, month, day);
      }
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  bool _subscriptionPassStillActive(Map<String, dynamic> booking) {
    final sts = booking['sts']?.toString() ?? '';
    if (!isSubscriptionSts(sts)) return false;

    // If it has an exit date, it's definitely completed
    final exitDate = booking['exitvehicledate']?.toString() ?? '';
    if (exitDate.trim().isNotEmpty) return false;

    final endRaw = (booking['subsctiptionenddate'] ?? '').toString().trim();
    if (endRaw.isEmpty) return false;

    try {
      final endOnly = _parseFlexibleDate(endRaw.split(' ').first);
      if (endOnly == null) return false;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return !today.isAfter(endOnly);
    } catch (_) {
      return false;
    }
  }

  /// Print receipt then exit (cash). Exit always runs even if print fails or times out.
  Future<void> _handlePrintAndExit(
    Map<String, dynamic> vehicle,
    String bookingId,
  ) async {
    if (bookingId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Booking ID not found')),
        );
      }
      return;
    }

    _setExiting(bookingId, true);
    try {
      print(
        'Print & Exit: Starting for ${vehicle['vehicleNumber']} (ID: $bookingId)',
      );

      String currentAmount;
      try {
        currentAmount = await UniversalPrintHelper.getPrintAmountFromAPI(
          bookingId,
        ).timeout(_apiTimeout);
      } on TimeoutException {
        currentAmount = '0';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not fetch amount in time. Continuing with exit...',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      try {
        await UniversalPrintHelper.printTicket(
          context: context,
          vendorName:
              vehicle['vendorName'] ?? vehicle['vendorname'] ?? 'Vendor',
          bookingId: bookingId,
          invoiceId: vehicle['invoiceid']?.toString(),
          vehicleType: vehicle['vehicleType'] ?? '',
          vehicleNumber: vehicle['vehicleNumber'] ?? '',
          parkingDate: vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '',
          parkingTime: vehicle['parkedTime'] ?? vehicle['parkingTime'] ?? '',
          amount: currentAmount,
          personName: vehicle['personName'] ?? '',
          valetCharge:
              double.tryParse(vehicle['valetCharge']?.toString() ?? '0') ?? 0.0,
          mobileNumber: vehicle['mobileNumber'] ?? '',
          vendorId: vehicle['vendorId'] ?? widget.vendorid,
          bookType: vehicle['bookType'] ?? '',
          sts: vehicle['sts'] ?? '',
          fastPrint: true,
          instantParkingReceipt: true,
        ).timeout(_printTimeout);
      } on TimeoutException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Print timed out. Continuing with exit...'),
            ),
          );
        }
      } catch (e) {
        print('Print & Exit: print failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Print failed. Continuing with exit...')),
          );
        }
      }

      await _performQuickExit(vehicle, currentAmount, manageLoading: false);
    } catch (e) {
      print('Print & Exit: Error: $e');
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exit failed: $msg')));
      }
    } finally {
      _setExiting(bookingId, false);
    }
  }

  Future<void> _performQuickExit(
    Map<String, dynamic> vehicle,
    String amount, {
    bool manageLoading = true,
  }) async {
    final String bookingId =
        vehicle['_id']?.toString() ?? vehicle['id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      print('QuickExit: Error - No ID found in vehicle map: $vehicle');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Booking ID not found')),
        );
      }
      return;
    }

    if (manageLoading) {
      _setExiting(bookingId, true);
    }

    try {
      print('QuickExit: Starting exit flow for $bookingId');
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId',
      );

      // Robust date parsing using keys normalized in fetchVendors
      final parkedDate = vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '';
      final parkedTime = vehicle['parkedTime'] ?? vehicle['parkingTime'] ?? '';

      print('QuickExit: Using dates - Date: $parkedDate, Time: $parkedTime');

      final parkedDateTime =
          UniversalPrintHelper.tryParseDateTime(
            date: parkedDate,
            time: parkedTime,
          ) ??
          DateTime.now();

      var duration = DateTime.now().difference(parkedDateTime);
      if (duration.isNegative) duration = Duration.zero;
      final formattedDuration = _formatDuration(duration);

      final parkingCharge = double.tryParse(amount.trim()) ?? 0.0;

      final Map<String, dynamic> requestBody = {
        'amount': parkingCharge,
        'hour': formattedDuration,
        'paymentMode': 'Cash',
      };

      final userId =
          (vehicle['userid'] ?? vehicle['userId'] ?? '').toString().trim();
      if (userId.isNotEmpty) {
        try {
          final gstData = await _fetchGstFeeForExit().timeout(_apiTimeout);
          final gstPercentage =
              double.tryParse(gstData['gst']?.toString() ?? '0') ?? 0.0;
          final handlingFeeAmount =
              double.tryParse(gstData['handlingfee']?.toString() ?? '0') ?? 0.0;
          final gstBase = parkingCharge + handlingFeeAmount;
          final gstAmount = (gstBase * gstPercentage) / 100;
          final exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
          final finalTotal = _roundUpToNearestRupeeForExit(exactTotal);
          requestBody['gstamout'] = gstAmount;
          requestBody['handlingfee'] = handlingFeeAmount;
          requestBody['totalamout'] = finalTotal;
        } catch (e) {
          print(
            'QuickExit: GST fee fetch failed, continuing without tax fields: $e',
          );
        }
      }

      print(
        'QuickExit: Request payload - Amount: $parkingCharge, Duration: $formattedDuration',
      );

      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_exitApiTimeout);

      print('Quick Exit Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle exited successfully (Cash)!'),
            ),
          );
          fetchVendors();
        }
      } else {
        String errMsg = 'Failed to exit vehicle (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? data['error'] ?? errMsg;
        } catch (_) {}
        throw Exception(errMsg);
      }
    } catch (e) {
      print('Error in _performQuickExit: $e');
      rethrow;
    } finally {
      if (manageLoading) {
        _setExiting(bookingId, false);
      }
    }
  }

  void filterVendors(String query) {
    print('filterVendors: Filtering query: $query, tab: $_selectedTabIndex');
    setState(() {
      filteredVendors =
          allVendors.where((v) {
            final status = v['status']?.toString().toUpperCase() ?? '';
            final vehicleNumber =
                v['vehicleNumber']?.toString().toLowerCase() ?? '';

            // Tab Filtering
            if (_selectedTabIndex == 0) {
              // On Parking Tab: Show PARKED or BOOKED status
              bool isParked =
                  (status == 'PARKED' ||
                      status == 'BOOKED' ||
                      v['status'].toString().toLowerCase() == 'parked');

              // Dashboard consistency: Weekly/monthly from machinecreatebooking use COMPLETED; keep on list until pass end date.
              if (status == 'COMPLETED' && _subscriptionPassStillActive(v)) {
                isParked = true;
              }

              if (!isParked) return false;
            } else if (_selectedTabIndex == 1) {
              // Completed Tab: Show strictly COMPLETED status
              bool isFinished = (status == 'COMPLETED');

              // If it's an active subscription, it belongs in "On Parking", not here.
              if (isFinished && _subscriptionPassStillActive(v)) {
                isFinished = false;
              }

              if (!isFinished) return false;

              // Dashboard consistency: Strictly only show today's completed bookings, even when searching
              final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
              final exitDate = v['exitvehicledate']?.toString() ?? '';

              if (!_isSameDay(exitDate, today)) return false;
            }

            // Search Query Filtering
            return vehicleNumber.contains(query.toLowerCase());
          }).toList();
      print('filterVendors: Results: ${filteredVendors.length}');
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Same endpoint as [Exitpage] in paytimeamount.dart — used for quick exit GST parity.
  Future<Map<String, dynamic>> _fetchGstFeeForExit() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty && data[0] is Map) {
        return Map<String, dynamic>.from(data[0] as Map);
      }
      return {'gst': '0', 'handlingfee': '0'};
    }
    throw Exception('Failed to load GST fees');
  }

  /// Matches [roundUpToNearestRupee] in paytimeamount.dart.
  double _roundUpToNearestRupeeForExit(double amount) {
    final double decimal = amount - amount.floor();
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }

  String formatWithSuffix(DateTime date) {
    int day = date.day;
    String suffix = 'th';
    if (!(day >= 11 && day <= 13)) {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
      }
    }
    return '$day$suffix ${DateFormat('MMMM yyyy').format(date)}';
  }

  DateTime? _calculateSubscriptionEndDate(
    String dateStr,
    String timeStr,
    String sts,
  ) {
    try {
      final startDateTime = _parseDateTime(dateStr, timeStr);
      int days = 30; // default
      final s = sts.toLowerCase();
      if (s.contains('weekly') || s.contains('7day') || s.contains('7 days')) {
        days = 7;
      } else if (s.contains('15day') || s.contains('15 days')) {
        days = 15;
      } else if (s.contains('monthly')) {
        days = 30;
      }
      return startDateTime.add(Duration(days: days));
    } catch (e) {
      print('calculateSubscriptionEndDate: Error calculating end date: $e');
      return null;
    }
  }

  String getRemainingDaysMessage(Map<String, dynamic> vehicle) {
    String? endDateStr = vehicle['subsctiptionenddate']?.toString();
    DateTime? endDate;

    if (endDateStr != null && endDateStr.isNotEmpty) {
      endDate = _parseSubscriptionEndDate(endDateStr);
    }

    if (endDate == null) {
      endDate = _calculateSubscriptionEndDate(
        vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '',
        vehicle['parkedTime'] ?? vehicle['parkingTime'] ?? '',
        vehicle['sts']?.toString() ??
            vehicle['subsctiptiontype']?.toString() ??
            '',
      );
    }

    if (endDate == null) return 'N/A';

    // Parse start date (parked date) for comparison
    DateTime? startDate;
    try {
      final rawStart = vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '';
      if (rawStart.isNotEmpty) {
        final parts = rawStart.split('-');
        startDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

    if (today.isAfter(endOnly)) {
      return 'Expired';
    }

    if (startDate != null) {
      final startOnly = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      if (today.isBefore(startOnly)) {
        // Subscription hasn't started yet — show full period
        final days = endOnly.difference(startOnly).inDays;
        return days == 1 ? '1 day left' : '$days days left';
      }
    }

    // Started: subtract 1 because parked date is day 0
    final remaining = endOnly.difference(today).inDays;
    final adjusted = remaining - 1;
    if (adjusted <= 0) return 'Subscription ends today!';
    return '$adjusted days left';
  }

  @override
  Widget build(BuildContext context) {
    print(
      'build: isLoading: $isLoading, hasError: $hasError, filteredVendors Length: ${filteredVendors.length}',
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Search Parking Booking',
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: TextFormField(
                  controller: searchController,
                  autofocus:
                      true, // Enable autofocus to make the textbox active on page entry
                  onChanged: filterVendors,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF1F2F3),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: ColorUtils.primarycolor(),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: ColorUtils.primarycolor(),
                        width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: ColorUtils.primarycolor(),
                        width: 0.5,
                      ),
                    ),
                    prefixIcon: GestureDetector(
                      onTap: () {
                        print(
                          'build: Search icon tapped, reloading vSearchScreen',
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    vSearchScreen(vendorid: widget.vendorid),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.search,
                        color: ColorUtils.primarycolor(),
                      ),
                    ),
                    constraints: const BoxConstraints(
                      maxHeight: 40,
                      maxWidth: double.infinity,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    hintText: 'Search',
                    hintStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w300,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabContainer(
                  controller: _tabController,
                  duration: Duration.zero,
                  childDuration: Duration.zero,
                  borderRadius: BorderRadius.circular(10),
                  tabEdge: TabEdge.top,
                  curve: Curves.easeIn,
                  colors: <Color>[
                    ColorUtils.primarycolor(),
                    ColorUtils.primarycolor(),
                  ],
                  selectedTextStyle: GoogleFonts.poppins(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  unselectedTextStyle: GoogleFonts.poppins(
                    fontSize: 13.0,
                    color: Colors.black,
                  ),
                  tabs: const [Text('On Parking'), Text('Completed')],
                  children: [
                    Container(color: Colors.white, child: _buildBookingList()),
                    Container(color: Colors.white, child: _buildBookingList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    if (isLoading) {
      return const SizedBox.shrink();
    }
    return hasError
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load data'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: fetchVendors,
                child: const Text('Retry'),
              ),
            ],
          ),
        )
        : filteredVendors.isEmpty
        ? Center(
          child: Text(
            _selectedTabIndex == 0
                ? 'No Active Parked Vehicles Found'
                : 'No Completed Bookings Found',
            style: GoogleFonts.poppins(),
          ),
        )
        : ListView.separated(
          padding: const EdgeInsets.only(top: 15),
          itemCount: filteredVendors.length,
          separatorBuilder:
              (context, index) =>
                  SizedBox(height: _selectedTabIndex == 1 ? 10 : 8),
          itemBuilder: (context, index) {
            final vehicle = filteredVendors[index];
            final String rowBookingId =
                vehicle['_id']?.toString() ?? vehicle['id']?.toString() ?? '';

            if (_selectedTabIndex == 1) {
              final bookingData = Bookingdata.fromJson(vehicle);
              return vendordashright(
                vehicle: bookingData,
                vendorId: widget.vendorid,
                bookType: bookingData.bookType,
              );
            }
            final payableDuration =
                vehicle['payableDuration'] as Duration? ?? Duration.zero;
            final formattedPayableDuration = _formatDuration(payableDuration);

            final parkedDate =
                vehicle['parkedDate'] ?? vehicle['parkingDate'] ?? '';
            final parkedTime =
                vehicle['parkedTime'] ?? vehicle['parkingTime'] ?? '';

            DateTime parsedDate = DateTime.now();
            if (parkedDate.isNotEmpty && parkedTime.isNotEmpty) {
              try {
                parsedDate = _parseDateTime(parkedDate, parkedTime);
              } catch (e) {
                print(
                  'build: Error parsing date for ${vehicle['vehicleNumber']}: $e',
                );
              }
            }

            final isSubscription =
                isSubscriptionSts(vehicle['sts']?.toString()) ||
                isSubscriptionSts(vehicle['subsctiptiontype']?.toString());
            final remainingDaysMessage =
                isSubscription ? getRemainingDaysMessage(vehicle) : '';
            return GestureDetector(
              onTap: () {
                print('build: Vehicle ${vehicle['vehicleNumber']} tapped');
                // Add navigation logic if needed
              },
              child: SizedBox(
                height: 120,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 30,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorUtils.primarycolor(),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Text(
                            'Booking on : ${formatWithSuffix(parsedDate)}, $parkedTime',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.only(
                                  left: 14,
                                  top: 2,
                                  right: 0.0,
                                  bottom: 0.0,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(5.0),
                                    topRight: Radius.circular(5.0),
                                  ),
                                  color: Colors.grey[200],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      vehicle['vehicleNumber'] ?? 'Unknown',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: ColorUtils.primarycolor(),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isVendorShortParkingSts(
                                      vehicle['sts']?.toString(),
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 3.0,
                                          bottom: 5.0,
                                        ),
                                        child: SizedBox(
                                          height: 25,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    final String bId =
                                                        vehicle['_id']
                                                            ?.toString() ??
                                                        vehicle['id']
                                                            ?.toString() ??
                                                        '';
                                                    if (bId.isEmpty) {
                                                      print(
                                                        'Print: Error - No ID found for vehicle',
                                                      );
                                                      return;
                                                    }

                                                    print(
                                                      'Print: Button pressed for vehicle: ${vehicle['vehicleNumber']} (ID: $bId)',
                                                    );
                                                    String currentAmount =
                                                        await UniversalPrintHelper.getPrintAmountFromAPI(
                                                          bId,
                                                        );

                                                    await UniversalPrintHelper.printTicket(
                                                      context: context,
                                                      vendorName:
                                                          vehicle['vendorName'] ??
                                                          vehicle['vendorname'] ??
                                                          'Vendor',
                                                      bookingId: bId,
                                                      invoiceId:
                                                          vehicle['invoiceid']
                                                              ?.toString(),
                                                      vehicleType:
                                                          vehicle['vehicleType'] ??
                                                          '',
                                                      vehicleNumber:
                                                          vehicle['vehicleNumber'] ??
                                                          '',
                                                      parkingDate:
                                                          vehicle['parkedDate'] ??
                                                          vehicle['parkingDate'] ??
                                                          '',
                                                      parkingTime:
                                                          vehicle['parkedTime'] ??
                                                          vehicle['parkingTime'] ??
                                                          '',
                                                      amount: currentAmount,
                                                      personName:
                                                          vehicle['personName'] ??
                                                          '',
                                                      valetCharge:
                                                          double.tryParse(
                                                            vehicle['valetCharge']
                                                                    ?.toString() ??
                                                                '0',
                                                          ) ??
                                                          0.0,
                                                      mobileNumber:
                                                          vehicle['mobileNumber'] ??
                                                          '',
                                                      vendorId:
                                                          vehicle['vendorId'] ??
                                                          widget.vendorid,
                                                      bookType:
                                                          vehicle['bookType'] ??
                                                          '',
                                                      sts: vehicle['sts'] ?? '',
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        ColorUtils.primarycolor(),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    minimumSize: const Size(
                                                      0,
                                                      0,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          const BorderRadius.all(
                                                            Radius.circular(5),
                                                          ),
                                                      side: BorderSide(
                                                        color:
                                                            ColorUtils.primarycolor(),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.print,
                                                        color: Colors.black,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        'Print',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (_selectedTabIndex == 0 &&
                                                  vehicle['sts']?.toString() ==
                                                      'Instant')
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ElevatedButton(
                                                    onPressed:
                                                        (_isExiting[rowBookingId] ==
                                                                true)
                                                            ? null
                                                            : () =>
                                                                _handlePrintAndExit(
                                                                  vehicle,
                                                                  rowBookingId,
                                                                ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      foregroundColor:
                                                          ColorUtils.primarycolor(),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      minimumSize: const Size(
                                                        0,
                                                        0,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                            ),
                                                        side: BorderSide(
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (_isExiting[rowBookingId] ==
                                                            true)
                                                          SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                    Color
                                                                  >(
                                                                    ColorUtils.primarycolor(),
                                                                  ),
                                                            ),
                                                          )
                                                        else
                                                          Icon(
                                                            Icons
                                                                .check_circle_outline,
                                                            color: Colors.black,
                                                            size: 14,
                                                          ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          _isExiting[rowBookingId] ==
                                                                  true
                                                              ? 'Processing...'
                                                              : 'Print & Exit',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                ColorUtils.primarycolor(),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              if (_selectedTabIndex == 0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ElevatedButton(
                                                    onPressed:
                                                        (_isCheckingExit[rowBookingId] ==
                                                                    true ||
                                                                _isExiting[rowBookingId] ==
                                                                    true)
                                                            ? null
                                                            : () =>
                                                                _handleExitButtonPressed(
                                                                  vehicle,
                                                                  rowBookingId,
                                                                ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      foregroundColor:
                                                          Colors.red,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      minimumSize: const Size(
                                                        0,
                                                        0,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                            ),
                                                        side: BorderSide(
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (_isCheckingExit[rowBookingId] ==
                                                            true)
                                                          SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              valueColor:
                                                                  AlwaysStoppedAnimation<
                                                                    Color
                                                                  >(
                                                                    ColorUtils.primarycolor(),
                                                                  ),
                                                            ),
                                                          )
                                                        else
                                                          Icon(
                                                            Icons
                                                                .qr_code_scanner,
                                                            color: Colors.black,
                                                            size: 14,
                                                          ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          _isCheckingExit[rowBookingId] ==
                                                                  true
                                                              ? 'Checking...'
                                                              : 'Exit',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                ColorUtils.primarycolor(),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (isSubscriptionSts(
                                          vehicle['sts']?.toString(),
                                        ) ||
                                        isSubscriptionSts(
                                          vehicle['subsctiptiontype']
                                              ?.toString(),
                                        ))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 3.0,
                                          bottom: 5.0,
                                        ),
                                        child: SizedBox(
                                          height: 25,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_selectedTabIndex == 0 &&
                                                  !isWeeklyOr15DayPassSts(
                                                    vehicle['sts']?.toString(),
                                                  ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      final result = await showModalBottomSheet<
                                                        bool
                                                      >(
                                                        context: context,
                                                        isScrollControlled:
                                                            true,
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        builder: (context) {
                                                          return DraggableScrollableSheet(
                                                            expand: false,
                                                            builder: (
                                                              context,
                                                              scrollController,
                                                            ) {
                                                              return Container(
                                                                decoration: const BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  borderRadius:
                                                                      BorderRadius.vertical(
                                                                        top: Radius.circular(
                                                                          20,
                                                                        ),
                                                                      ),
                                                                ),
                                                                child: RenewParkingSheet(
                                                                  daysleft:
                                                                      remainingDaysMessage,
                                                                  navi: "",
                                                                  onRefresh:
                                                                      () =>
                                                                          fetchVendors(),
                                                                  userid:
                                                                      vehicle['userid'] ??
                                                                      vehicle['userId'] ??
                                                                      '',
                                                                  otp:
                                                                      vehicle['otp'] ??
                                                                      '',
                                                                  vehicletype:
                                                                      vehicle['vehicleType'] ??
                                                                      '',
                                                                  bookingid:
                                                                      vehicle['_id']
                                                                          ?.toString() ??
                                                                      vehicle['id']
                                                                          ?.toString() ??
                                                                      '',
                                                                  parkingdate:
                                                                      vehicle['parkedDate'] ??
                                                                      vehicle['parkingDate'] ??
                                                                      '',
                                                                  vehiclenumber:
                                                                      vehicle['vehicleNumber'] ??
                                                                      '',
                                                                  username:
                                                                      vehicle['personName'] ??
                                                                      '',
                                                                  phoneno:
                                                                      vehicle['mobileNumber'] ??
                                                                      '',
                                                                  parkingtime:
                                                                      vehicle['parkedTime'] ??
                                                                      vehicle['parkingTime'] ??
                                                                      '',
                                                                  bookingtypetemporary:
                                                                      vehicle['status'] ??
                                                                      '',
                                                                  sts:
                                                                      vehicle['sts'] ??
                                                                      '',
                                                                  cartype:
                                                                      vehicle['carType'] ??
                                                                      '',
                                                                  vendorid:
                                                                      vehicle['vendorId'] ??
                                                                      widget
                                                                          .vendorid,
                                                                  parkeddate:
                                                                      vehicle['parkedDate'] ??
                                                                      '',
                                                                  parkedtime:
                                                                      vehicle['parkedTime'] ??
                                                                      '',
                                                                  status:
                                                                      vehicle['status'] ??
                                                                      '',
                                                                  totalamount:
                                                                      vehicle['totalamout'] ??
                                                                      '0',
                                                                  newEndDate:
                                                                      null,
                                                                  gstfee: "0",
                                                                  handlingfee:
                                                                      "0",
                                                                  amout:
                                                                      vehicle['amount'] ??
                                                                      '0',
                                                                  payableduration:
                                                                      "0",
                                                                  venodorname:
                                                                      vehicle['vendorName'] ??
                                                                      vehicle['vendorname'] ??
                                                                      'Vendor',
                                                                  subscriptionEndDate:
                                                                      vehicle['subsctiptionenddate'] ??
                                                                      '',
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      );
                                                      if (result == true) {
                                                        fetchVendors();
                                                      }
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      foregroundColor:
                                                          ColorUtils.primarycolor(),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      minimumSize: const Size(
                                                        0,
                                                        0,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                            ),
                                                        side: BorderSide(
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.refresh,
                                                          color: Colors.black,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          'Renew',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                ColorUtils.primarycolor(),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    final String bId =
                                                        vehicle['_id']
                                                            ?.toString() ??
                                                        vehicle['id']
                                                            ?.toString() ??
                                                        '';
                                                    if (bId.isEmpty) {
                                                      print(
                                                        'Sub Print: Error - No ID found',
                                                      );
                                                      return;
                                                    }
                                                    print(
                                                      'Sub Print: Button pressed for ${vehicle['vehicleNumber']} (ID: $bId)',
                                                    );
                                                    String currentAmount =
                                                        await UniversalPrintHelper.getPrintAmountFromAPI(
                                                          bId,
                                                        );
                                                    await UniversalPrintHelper.printTicket(
                                                      context: context,
                                                      vendorName:
                                                          vehicle['vendorName'] ??
                                                          vehicle['vendorname'] ??
                                                          'Vendor',
                                                      bookingId: bId,
                                                      invoiceId:
                                                          vehicle['invoiceid']
                                                              ?.toString(),
                                                      vehicleType:
                                                          vehicle['vehicleType'] ??
                                                          '',
                                                      vehicleNumber:
                                                          vehicle['vehicleNumber'] ??
                                                          '',
                                                      parkingDate:
                                                          vehicle['parkedDate'] ??
                                                          vehicle['parkingDate'] ??
                                                          '',
                                                      parkingTime:
                                                          vehicle['parkedTime'] ??
                                                          vehicle['parkingTime'] ??
                                                          '',
                                                      amount: currentAmount,
                                                      personName:
                                                          vehicle['personName'] ??
                                                          '',
                                                      valetCharge:
                                                          double.tryParse(
                                                            vehicle['valetCharge']
                                                                    ?.toString() ??
                                                                '0',
                                                          ) ??
                                                          0.0,
                                                      mobileNumber:
                                                          vehicle['mobileNumber'] ??
                                                          '',
                                                      vendorId:
                                                          vehicle['vendorId'] ??
                                                          widget.vendorid,
                                                      bookType:
                                                          vehicle['bookType'] ??
                                                          '',
                                                      sts: vehicle['sts'] ?? '',
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        ColorUtils.primarycolor(),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    minimumSize: const Size(
                                                      0,
                                                      0,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          const BorderRadius.all(
                                                            Radius.circular(5),
                                                          ),
                                                      side: BorderSide(
                                                        color:
                                                            ColorUtils.primarycolor(),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.print,
                                                        color: Colors.black,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        'Print',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (_selectedTabIndex == 0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      showModalBottomSheet(
                                                        context: context,
                                                        isScrollControlled:
                                                            true,
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        builder: (context) {
                                                          return DraggableScrollableSheet(
                                                            expand: false,
                                                            builder: (
                                                              context,
                                                              scrollController,
                                                            ) {
                                                              return Container(
                                                                decoration: const BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  borderRadius:
                                                                      BorderRadius.vertical(
                                                                        top: Radius.circular(
                                                                          20,
                                                                        ),
                                                                      ),
                                                                ),
                                                                child: subexit(
                                                                  userid:
                                                                      vehicle['userid'] ??
                                                                      vehicle['userId'] ??
                                                                      '',
                                                                  otp:
                                                                      vehicle['otp'] ??
                                                                      '',
                                                                  vehicletype:
                                                                      vehicle['vehicleType'] ??
                                                                      '',
                                                                  bookingid:
                                                                      vehicle['_id']
                                                                          ?.toString() ??
                                                                      vehicle['id']
                                                                          ?.toString() ??
                                                                      '',
                                                                  invoiceid:
                                                                      vehicle['invoiceid']
                                                                          ?.toString() ??
                                                                      vehicle['invoiceId']
                                                                          ?.toString() ??
                                                                      '',
                                                                  parkingdate:
                                                                      vehicle['parkedDate'] ??
                                                                      vehicle['parkingDate'] ??
                                                                      '',
                                                                  vehiclenumber:
                                                                      vehicle['vehicleNumber'] ??
                                                                      '',
                                                                  username:
                                                                      vehicle['personName'] ??
                                                                      '',
                                                                  phoneno:
                                                                      vehicle['mobileNumber'] ??
                                                                      '',
                                                                  parkingtime:
                                                                      vehicle['parkedTime'] ??
                                                                      vehicle['parkingTime'] ??
                                                                      '',
                                                                  bookingtypetemporary:
                                                                      vehicle['status'] ??
                                                                      '',
                                                                  sts:
                                                                      vehicle['sts'] ??
                                                                      '',
                                                                  cartype:
                                                                      vehicle['carType'] ??
                                                                      '',
                                                                  vendorid:
                                                                      vehicle['vendorId'] ??
                                                                      widget
                                                                          .vendorid,
                                                                  parkeddate:
                                                                      vehicle['parkedDate'] ??
                                                                      '',
                                                                  parkedtime:
                                                                      vehicle['parkedTime'] ??
                                                                      '',
                                                                  status:
                                                                      vehicle['status'] ??
                                                                      '',
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      foregroundColor:
                                                          Colors.red,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      minimumSize: const Size(
                                                        0,
                                                        0,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                5,
                                                              ),
                                                            ),
                                                        side: BorderSide(
                                                          color:
                                                              ColorUtils.primarycolor(),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.qr_code_scanner,
                                                          color: Colors.black,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          'Exit',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                ColorUtils.primarycolor(),
                                                          ),
                                                        ),
                                                      ],
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
                              const SizedBox(height: 0),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                      left: 12.0,
                                      right: 15.0,
                                      top: 6.0,
                                      bottom: 6.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          vehicle['status']
                                                      .toString()
                                                      .toLowerCase() ==
                                                  'cancelled'
                                              ? Colors.red
                                              : ColorUtils.primarycolor(),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(20.0),
                                        bottomRight: Radius.circular(20.0),
                                      ),
                                    ),
                                    child: Icon(
                                      _getVehicleIcon(vehicle['vehicleType']),
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(height: 10),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'Parking Schedule: ',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    ' ${vehicle['parkingDate'] ?? 'N/A'}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    vehicle['parkingTime'] ??
                                                        'N/A',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_selectedTabIndex == 1 &&
                                            (vehicle['exitvehicledate'] ?? '')
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Exit: ',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${vehicle['exitvehicledate']} ${vehicle['exitvehicletime'] ?? ''}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!isSubscriptionSts(
                                              vehicle['sts']?.toString(),
                                            ) &&
                                            !isSubscriptionSts(
                                              vehicle['subsctiptiontype']
                                                  ?.toString(),
                                            ))
                                          Row(
                                            children: [
                                              Text(
                                                'Payable Time: ',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                formattedPayableDuration,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (isSubscriptionSts(
                                              vehicle['sts']?.toString(),
                                            ) ||
                                            isSubscriptionSts(
                                              vehicle['subsctiptiontype']
                                                  ?.toString(),
                                            ))
                                          Row(
                                            children: [
                                              Text(
                                                'Remaining: ',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                remainingDaysMessage,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Container(height: 10),
                                            if (vehicle['status']
                                                    .toString()
                                                    .toLowerCase() ==
                                                'parked')
                                              Container(
                                                alignment: Alignment.topCenter,
                                              ),
                                            const Spacer(),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}
