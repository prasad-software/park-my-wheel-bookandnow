import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/pageloader.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:mywheels/utils/sts_utils.dart';
import 'vendorcreatebooking.dart';


import '../../config/authconfig.dart';
import '../../config/colorcode.dart';


class Exitpage extends StatefulWidget {
  final String vendorid;
  final String bookingid;
  final String vehicletype;
  final String vehiclenumber;
  final String username;
  final String phoneno;
  final String parkingtime;
  final String bookingtypetemporary;
  final String sts;
  final String cartype;
  final String parkingdate;
  final String bookType;
  final String otp;
  final String userid;
  final int currentTabIndex;
  final bool goToBookingOnExit;
  final VoidCallback? onExitSuccess;
  const Exitpage({super.key,
    required this.bookingid,
    required this.otp,
    required this.vehicletype,
    required this.vehiclenumber,
    required this.username,
    required this.phoneno,
    required this.parkingtime,
    required this.bookingtypetemporary,
    required this.sts,
    required this.cartype,
    required this.vendorid,
    required this.parkingdate,
    required this.bookType,
    required this.userid,
    required this.currentTabIndex,
    this.goToBookingOnExit = false,
    this.onExitSuccess,
  });


  @override
  _ExitpageState createState() => _ExitpageState();
}

class _ExitpageState extends State<Exitpage> {
  int selectedTabIndex = 0;
  DateTime selectedDateTime = DateTime.now();  // Initialize with the current date and time
  Timer? _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  List<Exitcharge> parkingCharges = [];  // Store the fetched parking charges
  Map<String, dynamic>? bookingChargesData;  // Store charges from booking API

  double payableAmount = 0.0;
  bool isLoading = true;
  String fullDayChargeType = 'Full Day';
  bool isOtpEntered = false;
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double roundedAmount = 0.0;
  double decimalDifference = 0.0;
  double totalAmountWithTaxes = 0.0;
  double payableAmountFromBackend = 0.0;

  String _paymentMode = 'Online';
  String? _vendorUpiId;
  String? _vendorName;

  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    _loadExitData();
  }

  Future<void> _loadExitData() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fast-exit-data/${widget.bookingid}'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] != true) throw Exception('API error');

        final rawCharges = (data['vehicleCharges'] as List?) ?? [];
        final charges = rawCharges.map<Exitcharge>((c) => Exitcharge(
          type: c['type']?.toString() ?? '',
          amount: double.tryParse(c['amount']?.toString() ?? '') ?? 0.0,
          fullDayCharge: '',
        )).toList();

        final hasFull = rawCharges.any((c) =>
            (c['type'] ?? '').toString().toLowerCase().contains('full day'));
        final fdType = hasFull ? 'Full Day' : 'FullDay';

        final bd = Bookingdata(
          id: widget.bookingid,
          parkeddate: data['parkedDate'] ?? widget.parkingdate,
          parkedtime: data['parkedTime'] ?? widget.parkingtime,
          invoiceid: data['invoiceid'] ?? '',
          sts: data['sts'] ?? widget.sts,
          bookType: data['bookType'] ?? widget.bookType,
          bookingtype: data['bookType'] ?? widget.bookType,
          amount: data['amount'] ?? '0',
          Amount: data['amount'] ?? '0',
          totalamout: '',
          status: 'PARKED',
          payableDuration: Duration.zero,
          vehicletype: widget.vehicletype,
          vehicleNumber: widget.vehiclenumber,
          username: widget.username,
          mobilenumber: widget.phoneno,
          Cartype: widget.cartype,
          Vendorid: widget.vendorid,
          parkingTime: widget.parkingtime,
          parkingDate: widget.parkingdate,
          bookingDate: '',
          bookingTime: '',
          Hour: '',
          Approvedate: '',
          Approvedtime: '',
          otp: widget.otp,
          userid: widget.userid,
          vendorname: '',
          subscriptiontype: '',
          subscriptionenddate: '',
          invoice: '',
          exitvehicledate: '',
          exitvehicletime: '',
          isValet: data['isValet'] ?? false,
          valetCharge: data['valetCharge']?.toString() ?? "0",
        );

        setState(() {
          gstPercentage = (data['gstPercentage'] as num?)?.toDouble() ?? 0.0;
          handlingFee = (data['handlingFee'] as num?)?.toDouble() ?? 0.0;
          parkingCharges = charges;
          fullDayChargeType = fdType;
          bookingDataNotifier.value = [bd];
          _vendorName = data['vendorName']?.toString();
          _vendorUpiId = data['upiId']?.toString();
          isLoading = false;
        });

        if (_payableTimer == null || !_payableTimer!.isActive) {
          _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) updatePayableTimes();
          });
        }
        updatePayableTimes();
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _payableTimer?.cancel();
    super.dispose();
  }

  void _initializeTimerAndData() {
    if (_payableTimer == null || !_payableTimer!.isActive) {
      _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) updatePayableTimes();
      });
    }

    fetchExitCalculation(widget.bookingid).then((data) {
      if (!mounted) return;

      // Build parking charges from the filtered vehicleCharges the server returned
      final rawCharges = (data['vehicleCharges'] as List?) ?? [];
      final charges = rawCharges.map<Exitcharge>((c) => Exitcharge(
        type: c['type']?.toString() ?? '',
        amount: double.tryParse(c['amount']?.toString() ?? '') ?? 0.0,
        fullDayCharge: '',
      )).toList();

      final hasFull = rawCharges.any((c) =>
          (c['type'] ?? '').toString().toLowerCase().contains('full day'));
      final fdType = hasFull ? 'Full Day' : 'FullDay';

      // Build a minimal Bookingdata so the existing timer/display logic works unchanged
      final bd = Bookingdata(
        id: widget.bookingid,
        parkeddate: data['parkedDate'],
        parkedtime: data['parkedTime'],
        invoiceid: data['invoiceid'],
        sts: data['sts'],
        bookType: data['bookType'],
        bookingtype: data['bookType'],
        amount: data['amount'],
        Amount: data['amount'],
        totalamout: '',
        status: 'PARKED',
        payableDuration: Duration.zero,
        vehicletype: widget.vehicletype,
        vehicleNumber: widget.vehiclenumber,
        username: widget.username,
        mobilenumber: widget.phoneno,
        Cartype: widget.cartype,
        Vendorid: widget.vendorid,
        parkingTime: widget.parkingtime,
        parkingDate: widget.parkingdate,
        bookingDate: '',
        bookingTime: '',
        Hour: '',
        Approvedate: '',
        Approvedtime: '',
        otp: widget.otp,
        userid: widget.userid,
        vendorname: '',
        subscriptiontype: '',
        subscriptionenddate: '',
        invoice: '',
        exitvehicledate: '',
        exitvehicletime: '',
        isValet: data['isValet'] ?? false,
        valetCharge: data['valetCharge']?.toString() ?? "0",
      );

      setState(() {
        gstPercentage = data['gstPercentage'];
        handlingFee = data['handlingFee'];
        parkingCharges = charges;
        fullDayChargeType = fdType;
        bookingDataNotifier.value = [bd];
        isLoading = false;
      });
      updatePayableTimes();
    }).catchError((_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  Future<Map<String, dynamic>> fetchExitCalculation(String bookingId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}vendor/calculate-exit/$bookingId'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return {
          'gstPercentage': (data['gstPercentage'] as num?)?.toDouble() ?? 0.0,
          'handlingFee': (data['handlingFee'] as num?)?.toDouble() ?? 0.0,
          'parkedDate': data['parkedDate']?.toString() ?? widget.parkingdate,
          'parkedTime': data['parkedTime']?.toString() ?? widget.parkingtime,
          'invoiceid': data['invoiceid']?.toString() ?? '',
          'sts': data['sts']?.toString() ?? widget.sts,
          'bookType': data['bookType']?.toString() ?? widget.bookType,
          'amount': data['amount']?.toString() ?? '0',
          'vehicleCharges': (data['vehicleCharges'] as List?) ?? [],
          'isValet': data['isValet'] ?? false,
          'valetCharge': data['valetCharge']?.toString() ?? "0",
        };
      }
    }
    throw Exception('Failed to fetch exit calculation');
  }
  // Modify this function to calculate payable amount based on parking charges
  Future<List<Exitcharge>> fetchParkingCharges(String vendorId, String vehicleType) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/charges/$vendorId/$vehicleType');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chargesData = data['transformedData'] ?? [];
        fullDayChargeType = data['fullDayCharge'] ?? 'FullDay';
        return chargesData.map<Exitcharge>((item) => Exitcharge.fromJson(item)).toList();
      } else {
        throw Exception('Failed to fetch parking charges');
      }
    } catch (e) {
      return [];
    }
  }

  double calculatePayableAmount(
    Duration duration,
    String bookingType,
    String parkedDate,
    String parkedTime, {
    String? sts,
    String? bookingBaseAmount,
  }) {
    if (payableAmountFromBackend > 0) {
      return payableAmountFromBackend;
    }

    if (isFixedHourPassSts(sts)) {
      return double.tryParse((bookingBaseAmount ?? '').trim()) ?? 0.0;
    }

    String bookingTypeLower = bookingType.toLowerCase();

    if (bookingTypeLower == 'hourly') {
      return calculateHourly(parkingCharges.map((e) => e.toJson()).toList(), duration);
    } else if (bookingTypeLower == '24 hours' || bookingTypeLower == 'weekly' || 
               bookingTypeLower == '12 hours' || bookingTypeLower == '48 hours' || 
               bookingTypeLower == '72 hours') {
      
      // Determine period hours
      int periodHours = 24;
      if (bookingTypeLower == 'weekly') periodHours = 24 * 7;
      else if (bookingTypeLower == '12 hours') periodHours = 12;
      else if (bookingTypeLower == '48 hours') periodHours = 48;
      else if (bookingTypeLower == '72 hours') periodHours = 72;

      // Find relevant charge
      var charge = parkingCharges.firstWhere(
        (c) => c.type.toLowerCase() == bookingTypeLower,
        orElse: () => Exitcharge(type: '', amount: 0.0, fullDayCharge: ''),
      );

      if (charge.amount > 0) {
        int periods = (duration.inHours / periodHours).ceil();
        if (periods < 1) periods = 1;
        return charge.amount * periods;
      }
      
      // Fallback for full day if named differently
      if (bookingTypeLower == '24 hours') {
         double fullDayChargeAmount = calculateFullDay(
          parkingCharges.map((e) => e.toJson()).toList(),
          duration,
          parkedDate,
          parkedTime,
          bookingTypeLower,
        );
        return fullDayChargeAmount;
      }

      return 0.0;
    } else {
      return 0.0;
    }
  }

// Calculate the full day charge based on booking type
  double calculateFullDay(List<Map<String, dynamic>> charges, Duration duration, String parkedDate, String parkedTime, String bookingType) {
    String chargeTypeToFind = fullDayChargeType.toLowerCase() == 'FullDay' ? '24 Hours' : 'Full Day';
    print('Looking for charge type: $chargeTypeToFind');

    // Find the charge matching the type
    var fullDayChargeData = charges.firstWhere(
          (c) => c['type'].toString().toLowerCase() == chargeTypeToFind.toLowerCase(),
      orElse: () {
        print('No charge found for type "$chargeTypeToFind". Available charges: $charges');
        return {'amount': 0.0, 'type': chargeTypeToFind};
      },
    );

    double fullDayAmount = double.tryParse(fullDayChargeData['amount'].toString()) ?? 0.0;
    print('Full day charge amount: $fullDayAmount');

    if (fullDayAmount == 0.0) {
      print('Warning: Full day charge amount is 0.0. Check API data for type "$chargeTypeToFind".');
    }

    DateTime parkingStart = parseParkingDateTime("$parkedDate $parkedTime");
    DateTime currentTime = DateTime.now();

    int numberOfPeriods = 1;

    if (fullDayChargeType.toLowerCase() == 'full day') {
      DateTime startDate = DateTime(parkingStart.year, parkingStart.month, parkingStart.day);
      DateTime endDate = DateTime(currentTime.year, currentTime.month, currentTime.day);
      numberOfPeriods = endDate.difference(startDate).inDays;
      numberOfPeriods = currentTime.isAfter(parkingStart) ? max(1, numberOfPeriods) : 1;
    } else {
      Duration timeElapsed = currentTime.difference(parkingStart);
      if (timeElapsed.inSeconds <= 0) {
        numberOfPeriods = 1;
      } else {
        double totalHours = timeElapsed.inSeconds / 3600.0;
        numberOfPeriods = max(1, (totalHours / 24).ceil());
        print("Precise calculation: $totalHours hours = $numberOfPeriods periods");
      }
    }

    double finalAmount = fullDayAmount * numberOfPeriods;
    print("Calculated full day amount: $finalAmount ($fullDayAmount * $numberOfPeriods)");
    return finalAmount;
  }
  double calculateHourly(List<Map<String, dynamic>> charges, Duration duration) {
    int totalHours = duration.inHours;
    if (duration.inMinutes % 60 > 0) totalHours += 1; // Round up to the next hour if there are any minutes
    double totalAmount = 0.0;

    print("Total Hours for Calculation: $totalHours");

    // List of possible initial charge types
    final initialChargeTypes = [
      '0 to 1 hour',
      '0 to 2 hours',
      '0 to 3 hours',
      '0 to 4 hours'
    ];

    // Find the smallest initial charge available
    Map<String, dynamic>? initialCharge;
    int minInitialHours = 5; // Higher than max initial hours (4)
    for (var charge in charges) {
      String chargeType = charge['type'].toString();
      if (initialChargeTypes.contains(chargeType)) {
        // Extract the second number (e.g., '1' from '0 to 1 hour')
        int hours = int.parse(RegExp(r'0 to (\d+)').firstMatch(chargeType)!.group(1)!);
        if (hours < minInitialHours) {
          minInitialHours = hours;
          initialCharge = charge;
        }
      }
    }

    // If no initial charge is found, default to 0.0
    initialCharge ??= {'amount': 0.0, 'type': '0 to 1 hour'};
    print("Selected Initial Charge: ${initialCharge['type']} - Amount: ${initialCharge['amount']}");

    // Parse initial hours correctly
    int initialHours = int.parse(RegExp(r'0 to (\d+)').firstMatch(initialCharge['type'])!.group(1)!);
    print("Initial Hours: $initialHours");

    // If total hours are within the initial period, return only the initial charge
    if (totalHours <= initialHours) {
      totalAmount = double.tryParse(initialCharge['amount'].toString()) ?? 0.0;
      print("Duration within initial period, Total Amount Payable (Hourly): $totalAmount");
      return totalAmount;
    }

    // Add initial charge amount
    totalAmount += double.tryParse(initialCharge['amount'].toString()) ?? 0.0;
    int remainingHours = totalHours - initialHours;

    print("Remaining Hours: $remainingHours");

    // Handle additional hours
    if (remainingHours > 0) {
      // List of possible additional charge types
      final additionalChargeTypes = [
        'Additional 1 hour',
        'Additional 2 hours',
        'Additional 3 hours',
        'Additional 4 hours'
      ];

      // Find the additional charge type
      var additionalCharge = charges.firstWhere(
            (charge) => additionalChargeTypes.contains(charge['type']),
        orElse: () => {'amount': 0.0, 'type': 'Additional 1 hour'},
      );

      print("Selected Additional Charge: ${additionalCharge['type']} - Amount: ${additionalCharge['amount']}");

      int blockHours = int.parse(RegExp(r'Additional (\d+)').firstMatch(additionalCharge['type'])!.group(1)!);
      int blocks = (remainingHours / blockHours).ceil(); // Round up to the next block
      double additionalAmount = blocks * (double.tryParse(additionalCharge['amount'].toString()) ?? 0.0);

      totalAmount += additionalAmount;
      print("Additional Blocks: $blocks, Additional Amount: $additionalAmount");
    }

    print("Total Amount Payable (Hourly): $totalAmount");
    return totalAmount;
  }
  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData = bookingDataNotifier.value.map((booking) {
      if (booking.status == 'PARKED' && booking.id == widget.bookingid) {
        final parkingTime = parseParkingDateTime(
          "${booking.parkeddate} ${booking.parkedtime}",
        );
        final elapsed = now.difference(parkingTime);
        booking.payableDuration = elapsed;

        calculatePayableAmount(
          elapsed,
          booking.bookType,
          booking.parkeddate,
          booking.parkedtime,
          sts: booking.sts,
          bookingBaseAmount: booking.amount,
        );
      }
      return booking;
    }).toList();

    setState(() {
      bookingDataNotifier.value = updatedData;
    });
  }

  Future<List<Bookingdata>> fetchBookingData() async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      final List<dynamic>? data = jsonResponse['bookings'];

      if (data == null || data.isEmpty) {
        throw 'No bookings available';
      }

      return data.map((item) => Bookingdata.fromJson(item)).toList();
    } else {
      throw response.body;
    }
  }
  Future<Map<String, dynamic>> fetchGstData() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0]; // Return the first GST entry
      }
      return {'gst': '0', 'handlingfee': '0'};
    } else {
      throw Exception('Failed to load GST fees');
    }
  }

  Future<void> fetchPayableAmount(String bookingId) async {
    final String url = "${ApiConfig.baseUrl}vendor/fet/$bookingId";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final double fetchedAmount = double.tryParse(data['payableAmount'].toString()) ?? 0.0;
          if (mounted) {
            setState(() {
              payableAmountFromBackend = fetchedAmount;
            });
          }
        }
      }
    } catch (_) {}
  }

  // Fetch charges data and calculated amount from new charge calculation API
  Future<void> fetchChargeCalculation(String bookingId) async {
    final String url = "${ApiConfig.baseUrl}vendor/charge-calculation/$bookingId";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // Extract calculated payable amount from backend
          final double calculatedAmount = double.tryParse(data['payableAmount'].toString()) ?? 0.0;
          
          // Extract charges data from API response
          Map<String, dynamic>? charges = data['charges'] != null 
              ? Map<String, dynamic>.from(data['charges']) 
              : null;
          
          if (mounted) {
            setState(() {
              // Use calculated amount from backend (this takes priority)
              payableAmountFromBackend = calculatedAmount;
              bookingChargesData = charges;
            });
            
            // Convert booking charges to Exitcharge format (for fallback/display purposes)
            if (charges != null) {
              parkingCharges = _convertBookingChargesToExitcharge(charges, widget.vehicletype);
            }
            
            print('✅ Calculated amount from backend: $calculatedAmount');
            print('✅ Charges data fetched from charge-calculation API: $charges');
          }
        } else {
          print('Failed to fetch charge calculation: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        print('Failed to load charge calculation: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching charge calculation: $error');
    }
  }

  // Convert booking charges to Exitcharge format
  List<Exitcharge> _convertBookingChargesToExitcharge(Map<String, dynamic> charges, String vehicleType) {
    List<Exitcharge> exitcharges = [];
    String vehicleTypeLower = vehicleType.toLowerCase();
    
    if (vehicleTypeLower == 'car') {
      // Hourly charges
      if (charges['cartemp'] != null && charges['cartemp'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '0 to 1 hour',
          amount: double.tryParse(charges['cartemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
        
        // Additional hour charge
        exitcharges.add(Exitcharge(
          type: 'Additional 1 hour',
          amount: double.tryParse(charges['cartemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
      }
      
      // Full day charge
      if (charges['carfullday'] != null && charges['carfullday'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '24 Hours',
          amount: double.tryParse(charges['carfullday'].toString()) ?? 0.0,
          fullDayCharge: 'FullDay',
        ));
        fullDayChargeType = 'FullDay';
      }
    } else if (vehicleTypeLower == 'bike') {
      if (charges['biketemp'] != null && charges['biketemp'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '0 to 1 hour',
          amount: double.tryParse(charges['biketemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
        
        exitcharges.add(Exitcharge(
          type: 'Additional 1 hour',
          amount: double.tryParse(charges['biketemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
      }
      
      if (charges['bikefullday'] != null && charges['bikefullday'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '24 Hours',
          amount: double.tryParse(charges['bikefullday'].toString()) ?? 0.0,
          fullDayCharge: 'FullDay',
        ));
        fullDayChargeType = 'FullDay';
      }
    } else { // Others
      if (charges['otherstemp'] != null && charges['otherstemp'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '0 to 1 hour',
          amount: double.tryParse(charges['otherstemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
        
        exitcharges.add(Exitcharge(
          type: 'Additional 1 hour',
          amount: double.tryParse(charges['otherstemp'].toString()) ?? 0.0,
          fullDayCharge: '',
        ));
      }
      
      if (charges['othersfullday'] != null && charges['othersfullday'].toString().isNotEmpty) {
        exitcharges.add(Exitcharge(
          type: '24 Hours',
          amount: double.tryParse(charges['othersfullday'].toString()) ?? 0.0,
          fullDayCharge: 'FullDay',
        ));
        fullDayChargeType = 'FullDay';
      }
    }
    
    print('Converted charges to Exitcharge: $exitcharges');
    return exitcharges;
  }

  double roundUpToNearestRupee(double amount) {
    // Get the decimal part of the amount
    double decimal = amount - amount.floor();
    // If decimal is 0.5 or more, round up, otherwise round down
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }


  double calculateTotalWithTaxes(double payableAmount) {
    print('┌─────────────────────────────── CALCULATION START ───────────────────────────────┐');
    print('Raw Parking Charge (no rounding)          : ₹$payableAmount');

    // Don't round parking charge - keep original value
    double parkingCharge = payableAmount;
    print('Parking Charge (unrounded)                : ₹$parkingCharge');

    // Don't round handling fee - keep original value
    double handlingFeeAmount = handlingFee;
    print('Handling Fee (unrounded)                  : ₹$handlingFeeAmount');

    // GST base (using unrounded values)
    double gstBase = parkingCharge + handlingFeeAmount;
    print('GST Base (Parking + Handling)             : ₹$gstBase');

    // GST calculation
    double gstAmount = (gstBase * gstPercentage) / 100;
    print('Exact GST ($gstPercentage%)                   : ₹${gstAmount.toStringAsFixed(4)}');

    // Calculate exact total without rounding
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
    print('Exact Total (before rounding)             : ₹${exactTotal.toStringAsFixed(4)}');

    // Round only the final total amount
    double totalAmount = roundUpToNearestRupee(exactTotal);
    print('Final Total Amount (rounded)              : ₹${totalAmount.toStringAsFixed(2)}');
    print('Difference caused by rounding total       : ₹${(totalAmount - exactTotal).toStringAsFixed(4)}');
    print('└───────────────────────────────────────────────────────────────────────────────┘');

    // Store values (as you already do)
    roundedAmount = totalAmount;
    decimalDifference = totalAmount - exactTotal;

    return totalAmount;
  }
  Future<void> updateExitData(String bookingId, Duration totalDuration, String formattedDuration, double payableAmount) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId');

    try {
      // Don't round parking charge - use original value
      double parkingCharge = payableAmount;
      
      Map<String, dynamic> requestBody = {
        'amount': parkingCharge,
        'hour': formattedDuration,
        'paymentMode': _paymentMode,
      };

      if (widget.userid.isNotEmpty) {
        // Calculate GST and handling fee without rounding individual components
        double handlingFeeAmount = handlingFee;
        double gstBase = parkingCharge + handlingFeeAmount;
        double gstAmount = (gstBase * gstPercentage) / 100;
        
        // Calculate exact total
        double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
        
        // Round only the final total amount
        double finalTotal = roundUpToNearestRupee(exactTotal);
        
        requestBody['gstamout'] = gstAmount;
        requestBody['handlingfee'] = handlingFeeAmount;
        requestBody['totalamout'] = finalTotal;
      }
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Booking updated successfully');

        final nav = Navigator.of(context);
        nav.pop(); // Pop the bottom sheet
        if (widget.onExitSuccess != null) {
          widget.onExitSuccess!();
        } else if (widget.goToBookingOnExit) {
          nav.push(
            MaterialPageRoute(
              builder: (context) => vendorChooseParkingPage(
                vendorid: widget.vendorid,
              ),
            ),
          );
        } else {
          nav.push(
            MaterialPageRoute(
              builder: (context) => vendordashScreen(
                vendorid: widget.vendorid,
                initialTabIndex: widget.currentTabIndex,
              ),
            ),
          );
        }


      } else {
        throw Exception('Failed to update booking: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error updating booking: $e');
    }
  }
  String? _buildUpiQrUri(double amountVal) {
    final upiId = (_vendorUpiId ?? '').trim();
    if (upiId.isEmpty) return null;
    if (amountVal <= 0) return null;

    final name = Uri.encodeComponent((_vendorName ?? '').trim());
    final tn = Uri.encodeComponent('ParkMyWheels Parking');
    final amount = amountVal.toStringAsFixed(2);
    return 'upi://pay?pa=$upiId&pn=$name&am=$amount&cu=INR&tn=$tn';
  }

  Widget _buildInlineUpiQr(double amountVal) {
    final uri = _buildUpiQrUri(amountVal);
    if (uri == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.primarycolor(), width: 1),
          ),
          child: Column(
            children: [
              Text(
                'Scan to Pay via UPI',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.primarycolor(),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 120,
                height: 120,
                child: PrettyQrView.data(
                  data: uri,
                  errorCorrectLevel: QrErrorCorrectLevel.H,
                  decoration: PrettyQrDecoration(
                    shape: PrettyQrSmoothSymbol(
                      color: ColorUtils.primarycolor(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'UPI ID: $_vendorUpiId',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  DateTime parseParkingDateTime(String dateTimeString) {
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':');
    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    String ampm = parts.length > 2 ? parts[2] : 'AM';

    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;

    return DateTime(year, month, day, hour, minute);
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    // return isLoading
    //     ? const LoadingGif()
    //     : Scaffold(
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: ColorUtils.secondarycolor(),
      //   titleSpacing: 0,
      //   title: Text(
      //     "Exit",
      //     style: GoogleFonts.poppins(),
      //   ),
      // ),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(

            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), // Top-left corner radius
              topRight: Radius.circular(30), // Top-right corner radius
            ),
          ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              // vertical: screenHeight * 0.01,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
const SizedBox(height: 10,),

                Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [


                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          "Vehicle No: ${widget.vehiclenumber}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ColorUtils.primarycolor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            print('Close button pressed'); // Debug print
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8), // Add padding for a larger tap area
                            child: const Icon(Icons.cancel_outlined, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
// // Text("data"),

//                 const Divider(),
                const Divider(),
                // Circular Progress Indicator with Gradient and Ticks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // This will space children equally
                  crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
                  children: [
                    // First widget (the Stack with CircularProgressIndicator)
                    Flexible(
                      flex: 0, // Equal flex
                      child: Container(

                        padding: EdgeInsets.all(screenWidth * 0.01),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: screenWidth * 0.35, // Slightly reduced size
                              height: screenWidth * 0.35,
                              child: CircularProgressIndicator(
                                value: 0.5,
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation(
                                  ColorUtils.primarycolor(),
                                ),
                                backgroundColor: Colors.black,
                              ),
                            ),
                            CustomPaint(
                              size: Size(screenWidth * 0.35, screenWidth * 0.35),
                              painter: RadialTicksPainter(),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/car.svg',
                                  width: screenWidth * 0.08, // Slightly reduced size
                                  height: screenWidth * 0.08,
                                ),
                                SizedBox(height: screenHeight * 0.002),
                                Text(
                                  'PAYABLE TIME',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 10 * textScaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.002),
                                ValueListenableBuilder<List<Bookingdata>>(
                                  valueListenable: bookingDataNotifier,
                                  builder: (context, bookingData, child) {
                                    final booking = bookingData.firstWhere(
                                          (booking) => booking.id == widget.bookingid,
                                      orElse: () => Bookingdata(
                                        bookingtype:"",
                                        vendorname: "",
                                        username: '',
                                        mobilenumber: '',
                                        id: widget.bookingid,
                                        vehicleNumber: '',
                                        bookingDate: '',
                                        bookingTime: '',
                                        status: '',
                                        vehicletype: '',
                                        Cartype: '',
                                        Amount: '',
                                        Hour: '',
                                        Vendorid: '',
                                        sts: '',
                                        payableDuration: Duration.zero,
                                        subscriptiontype: '',
                                        parkingTime: '',
                                        parkingDate: '',
                                        Approvedate: '',
                                        Approvedtime: '',
                                        parkeddate: '',
                                        parkedtime: '', bookType: '', otp: '', userid: '', subscriptionenddate: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                                      ),
                                    );

                                    if (booking.id == widget.bookingid) {
                                      return Text(
                                        formatDuration(booking.payableDuration),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontSize: 10 * textScaleFactor,
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        "No bookings available",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                          fontSize: 10 * textScaleFactor,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                // Text(
                                //   'Time left',
                                //   style: GoogleFonts.poppins(
                                //     color: Colors.grey,
                                //     fontSize: 10 * textScaleFactor,
                                //   ),
                                // ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
const SizedBox(width: 10,),
                    // Second widget (the details container)
                    Flexible(
                      flex: 1, // Equal flex
                      child: Container(
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.01),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Booking ID:",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  ValueListenableBuilder<List<Bookingdata>>(
                                    valueListenable: bookingDataNotifier,
                                    builder: (context, bookingData, child) {
                                      final booking = bookingData.firstWhere(
                                            (booking) => booking.id == widget.bookingid,
                                        orElse: () => Bookingdata(
                                          bookingtype: "",
                                          vendorname: "",
                                          username: '',
                                          mobilenumber: '',
                                          id: '',
                                          vehicleNumber: '',
                                          bookingDate: '',
                                          bookingTime: '',
                                          status: '',
                                          vehicletype: '',
                                          Cartype: '',
                                          Amount: '',
                                          Hour: '',
                                          Vendorid: '',
                                          sts: '',
                                          payableDuration: Duration.zero,
                                          subscriptiontype: '',
                                          parkingTime: '',
                                          parkingDate: '',
                                          Approvedate: '',
                                          Approvedtime: '',
                                          parkeddate: '',
                                          parkedtime: '',
                                          bookType: '',
                                          otp: '',
                                          userid: '', subscriptionenddate: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                                        ),
                                      );

                                      if (booking.id.isEmpty) {
                                        return Text(
                                          "Calculating...",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12 * textScaleFactor,
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }

                                      double payableAmount = calculatePayableAmount(
                                        booking.payableDuration,
                                        booking.bookType,
                                        booking.parkeddate,
                                        booking.parkedtime,
                                        sts: booking.sts,
                                        bookingBaseAmount: booking.amount,
                                      );

                                      return Text(
                                        ' ${UniversalPrintHelper.formatReceiptBookingId(booking.invoiceid)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10 * textScaleFactor,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),
                              SizedBox(height: screenHeight * 0.001),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "In Time: ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  Text(
                                    "${widget.parkingdate ?? ''} ${widget.parkingtime ?? ''}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              SizedBox(height: screenHeight * 0.001),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Name: ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  Text(
                                    " ${widget.username ?? ''}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Mobile Number: ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  Text(
                                    " ${widget.phoneno}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Booking Type: ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  Text(
                                    '${widget.sts ?? ''} (${widget.bookType ?? ''})',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),

                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Booked by: ",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  Text(
                                    " ${widget.userid.isEmpty ? 'Vendor' : 'Customer'}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenHeight * 0.001),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),





                // const Divider(),
                const Divider(),
const SizedBox(height: 5,),
                // const Divider(),
                // Replace the GST, Handling Fee, and Total Amount sections with this
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Parking Charges:",
                      style: GoogleFonts.poppins(
                        fontSize: 12 * textScaleFactor,
                        color: Colors.black,
                      ),
                    ),
                    ValueListenableBuilder<List<Bookingdata>>(
                      valueListenable: bookingDataNotifier,
                      builder: (context, bookingData, child) {
                        final booking = bookingData.firstWhere(
                              (booking) => booking.id == widget.bookingid,
                          orElse: () => Bookingdata(
                            bookingtype: "",
                            vendorname: "",
                            username: '',
                            mobilenumber: '',
                            id: '',
                            vehicleNumber: '',
                            bookingDate: '',
                            bookingTime: '',
                            status: '',
                            vehicletype: '',
                            Cartype: '',
                            Amount: '',
                            Hour: '',
                            Vendorid: '',
                            sts: '',
                            payableDuration: Duration.zero,
                            subscriptiontype: '',
                            parkingTime: '',
                            parkingDate: '',
                            Approvedate: '',
                            Approvedtime: '',
                            parkeddate: '',
                            parkedtime: '',
                            bookType: '',
                            otp: '',
                            userid: '', subscriptionenddate: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                          ),
                        );

                        if (booking.id.isEmpty) {
                          return Text(
                            "Calculating...",
                            style: GoogleFonts.poppins(
                              fontSize: 12 * textScaleFactor,
                              color: Colors.black,
                              // fontWeight: FontWeight.bold,
                            ),
                          );
                        }

                        double payableAmount = calculatePayableAmount(
                          booking.payableDuration,
                          booking.bookType,
                          booking.parkeddate,
                          booking.parkedtime,
                          sts: booking.sts,
                          bookingBaseAmount: booking.amount,
                        );

                        if (booking.isValet && booking.vehicletype.toLowerCase() == 'car') {
                          double valetAmt = double.tryParse(booking.valetCharge) ?? 0.0;
                          payableAmount += valetAmt;
                        }

                        return Text(
                          "₹${payableAmount.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * textScaleFactor,
                            color: Colors.black,
                            // fontWeight: FontWeight.bold,/
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4,),

                // const Divider(),
              if (widget.userid.isNotEmpty) ...[

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Handling Fee:",
                      style: GoogleFonts.poppins(
                        fontSize: 12 * textScaleFactor,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "₹${handlingFee.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 12 * textScaleFactor,
                        color: Colors.black,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "GST ($gstPercentage%):",
                      style: GoogleFonts.poppins(
                        fontSize: 12 * textScaleFactor,
                        color: Colors.black,
                      ),
                    ),
                    ValueListenableBuilder<List<Bookingdata>>(
                      valueListenable: bookingDataNotifier,
                      builder: (context, bookingData, child) {
                        final booking = bookingData.firstWhere(
                              (booking) => booking.id == widget.bookingid,
                          orElse: () => Bookingdata(
                            bookingtype:"",
                            vendorname: "",
                            username: '',
                            mobilenumber: '',
                            id: '',
                            vehicleNumber: '',
                            bookingDate: '',
                            bookingTime: '',
                            status: '',
                            vehicletype: '',
                            Cartype: '',
                            Amount: '',
                            Hour: '',
                            Vendorid: '',
                            sts: '',
                            payableDuration: Duration.zero,
                            subscriptiontype: '',
                            parkingTime: '',
                            parkingDate: '',
                            Approvedate: '',
                            Approvedtime: '',
                            parkeddate: '',
                            parkedtime: '', bookType: '', otp: '', userid: '', subscriptionenddate: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                            // Your default booking data
                          ),
                        );

                        if (booking.id.isEmpty) return const Text("Calculating...");

                        double payableAmount = calculatePayableAmount(
                          booking.payableDuration,
                          booking.bookType,
                          booking.parkeddate,
                          booking.parkedtime,
                          sts: booking.sts,
                          bookingBaseAmount: booking.amount,
                        );
                        // Don't round parking charge or handling fee
                        double parkingCharge = payableAmount;
                        double handlingFeeAmount = handlingFee;
                        // GST Base = Parking + Handling
                        // GST Amount = (GST Base * GST%) / 100
                        double gstAmount = ((parkingCharge + handlingFeeAmount) * gstPercentage) / 100;

                        return Text(
                          "₹${gstAmount.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * textScaleFactor,
                            color: Colors.black,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 5,),

                // Total Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Payable Amount:",
                      style: GoogleFonts.poppins(
                        fontSize: 14 * textScaleFactor,
                        color: ColorUtils.primarycolor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ValueListenableBuilder<List<Bookingdata>>(
                      valueListenable: bookingDataNotifier,
                      builder: (context, bookingData, child) {
                        final booking = bookingData.firstWhere(
                              (booking) => booking.id == widget.bookingid,
                          orElse: () => Bookingdata(
                            subscriptionenddate: "",
                            bookingtype:"",
                            vendorname: "",
                            username: '',
                            mobilenumber: '',
                            id: '',
                            vehicleNumber: '',
                            bookingDate: '',
                            bookingTime: '',
                            status: '',
                            vehicletype: '',
                            Cartype: '',
                            Amount: '',
                            Hour: '',
                            Vendorid: '',
                            sts: '',
                            payableDuration: Duration.zero,
                            subscriptiontype: '',
                            parkingTime: '',
                            parkingDate: '',
                            Approvedate: '',
                            Approvedtime: '',
                            parkeddate: '',
                            parkedtime: '', bookType: '', otp: '', userid: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                            // Your default booking data
                          ),
                        );

                        if (booking.id.isEmpty) return const Text("Calculating...");

                        double payableAmount = calculatePayableAmount(
                          booking.payableDuration,
                          booking.bookType,
                          booking.parkeddate,
                          booking.parkedtime,
                          sts: booking.sts,
                          bookingBaseAmount: booking.amount,
                        );
                        double total = calculateTotalWithTaxes(payableAmount);
                        if (booking.isValet && booking.vehicletype.toLowerCase() == 'car') {
                          total += double.tryParse(booking.valetCharge) ?? 0.0;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₹${total.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                fontSize: 14 * textScaleFactor,
                                color: ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),


                ],
                if (widget.userid.isEmpty) ...[
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      "Payment Mode:",
                      style: GoogleFonts.poppins(
                        fontSize: 12 * textScaleFactor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _paymentMode = 'Online'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'Online',
                                  groupValue: _paymentMode,
                                  onChanged: (v) => setState(() => _paymentMode = v!),
                                  activeColor: ColorUtils.primarycolor(),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  "Online",
                                  style: GoogleFonts.poppins(fontSize: 12 * textScaleFactor),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _paymentMode = 'Cash'),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'Cash',
                                  groupValue: _paymentMode,
                                  onChanged: (v) => setState(() => _paymentMode = v!),
                                  activeColor: ColorUtils.primarycolor(),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  "Cash",
                                  style: GoogleFonts.poppins(fontSize: 12 * textScaleFactor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (_paymentMode == 'Online')
                  ValueListenableBuilder<List<Bookingdata>>(
                    valueListenable: bookingDataNotifier,
                    builder: (context, bookingData, child) {
                      final booking = bookingData.firstWhere(
                            (booking) => booking.id == widget.bookingid,
                        orElse: () => Bookingdata(
                            subscriptionenddate: "",
                            bookingtype:"",
                            vendorname: "",
                            username: '',
                            mobilenumber: '',
                            id: '',
                            vehicleNumber: '',
                            bookingDate: '',
                            bookingTime: '',
                            status: '',
                            vehicletype: '',
                            Cartype: '',
                            Amount: '',
                            Hour: '',
                            Vendorid: '',
                            sts: '',
                            payableDuration: Duration.zero,
                            subscriptiontype: '',
                            parkingTime: '',
                            parkingDate: '',
                            Approvedate: '',
                            Approvedtime: '',
                            parkeddate: '',
                            parkedtime: '', bookType: '', otp: '', userid: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                        ),
                      );

                      if (booking.id.isEmpty) return const SizedBox.shrink();

                      double payableAmount = calculatePayableAmount(
                        booking.payableDuration,
                        booking.bookType,
                        booking.parkeddate,
                        booking.parkedtime,
                        sts: booking.sts,
                        bookingBaseAmount: booking.amount,
                      );
                      double finalTotalForQr = widget.userid.isNotEmpty 
                          ? calculateTotalWithTaxes(payableAmount) 
                          : payableAmount;
                      if (booking.isValet && booking.vehicletype.toLowerCase() == 'car') {
                        finalTotalForQr += double.tryParse(booking.valetCharge) ?? 0.0;
                      }
                      
                      return _buildInlineUpiQr(finalTotalForQr);
                    },
                  ),
                ],
                SizedBox(height: screenHeight * 0.02),
// In your build method, replace the Exit button section with:

        if (!isLoading) ...[
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    height: screenHeight * 0.04,
                    // width: screenWidth * 0.2,
                    child: ElevatedButton(
                      onPressed: () {
                        final booking = bookingDataNotifier.value.firstWhere(
                              (booking) => booking.id == widget.bookingid,
                          orElse: () => Bookingdata(
                            subscriptionenddate: " ",
                            bookingtype: "",
                            vendorname: "",
                            username: '',
                            mobilenumber: '',
                            id: '',
                            vehicleNumber: '',
                            bookingDate: '',
                            bookingTime: '',
                            status: '',
                            vehicletype: '',
                            Cartype: '',
                            Amount: '',
                            Hour: '',
                            Vendorid: '',
                            sts: '',
                            payableDuration: Duration.zero,
                            subscriptiontype: '',
                            parkingTime: '',
                            parkingDate: '',
                            Approvedate: '',
                            Approvedtime: '',
                            parkeddate: '',
                            parkedtime: '',
                            bookType: '',
                            otp: '',
                            userid: '', invoice: '', totalamout: '', amount: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                          ),
                        );

                        if (booking.id.isNotEmpty) {
                          double payableAmount = calculatePayableAmount(
                            booking.payableDuration,
                            booking.bookType,
                            booking.parkeddate,
                            booking.parkedtime,
                            sts: booking.sts,
                            bookingBaseAmount: booking.amount,
                          );
                          int hours = booking.payableDuration.inHours;
                          int minutes = booking.payableDuration.inMinutes % 60;
                          int seconds = booking.payableDuration.inSeconds % 60;

                          String formattedDuration =
                              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                          updateExitData(
                            booking.id,
                            booking.payableDuration,
                            formattedDuration,
                            payableAmount,
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primarycolor(),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.exit_to_app,
                            color: Colors.white,
                            size: screenWidth * 0.05,
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            'Exit Vehicle',
                            style: GoogleFonts.poppins(
                              fontSize: 12 * textScaleFactor,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
],
                SizedBox(height: screenHeight * 0.05),
          ]),
        ),
      ),
      ),
    ));
  }
  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0'); // Ensure two digits
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }
}














class RadialTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint tickPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    const int totalTicks = 130;
    const double tickLength = 10;
    const double largeTickLength = 10;

    for (int i = 0; i < totalTicks; i++) {
      final angle = (2 * pi / totalTicks) * i - pi / 2; // Start at top
      final isLargeTick = i % 5 == 0;

      // Determine the color based on the angle
      if (angle >= -pi / 2 && angle <= pi / 2) {
        tickPaint.color = ColorUtils.primarycolor();
      } else {
        tickPaint.color = Colors.black; // Other half (left side)
      }

      final tickStart = Offset(
        center.dx + (radius - (isLargeTick ? largeTickLength : tickLength)) * cos(angle),
        center.dy + (radius - (isLargeTick ? largeTickLength : tickLength)) * sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



class Exitcharge {
  final double amount;
  final String type;
  final String fullDayCharge;

  Exitcharge({
    required this.amount,
    required this.type,
    required this.fullDayCharge,
  });

  factory Exitcharge.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    if (json['amount'] is String) {
      parsedAmount = double.tryParse(json['amount']) ?? 0.0;
    } else if (json['amount'] is num) {
      parsedAmount = json['amount'].toDouble();
    }
    return Exitcharge(
      fullDayCharge: json['fullDayCharge'] ?? '',
      amount: parsedAmount,
      type: json['type'] ?? '',
    );
  }
  // Add the toJson method
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type,
      'fullDayCharge': fullDayCharge,
    };
  }
}