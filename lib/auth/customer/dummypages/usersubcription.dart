import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/vendor/subscription/vendorsubscriptonbooking.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/utils/sts_utils.dart';
import '../parking/parkindetails.dart';
import '../parking/userpayment.dart';

class BlockSpot extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;
  const BlockSpot({super.key, required this.userId, this.onRefresh});

  @override
  State<BlockSpot> createState() => _BlockSpotState();
}

class _BlockSpotState extends State<BlockSpot> {
  int selectedTabIndex = 0;
  late Future<List<VehicleBooking>> _bookingsFuture;
  final Map<String, double> statusHeights = {
    'Cancelled': 80,
    'PENDING': 85,
    'COMPLETED': 115,
    'Default': 90,
  };
  double payableAmount = 0.0;
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double totalAmountWithTaxes = 0.0;
  String remainingDaysMessage = ''; // Declare the variable here
  double totalPayableAmount = 0.0;
  @override
  void initState() {
    super.initState();
    _loadData();
    fetchGstData();
  }

  void _loadData() {
    print('🔄 _loadData called, setting state...');
    setState(() {
      print('🔄 Setting new bookings future...');
      _bookingsFuture = fetchBookingsAndCharges();
      print('🔄 New bookings future set: $_bookingsFuture');
    });
    print('🔄 _loadData completed');
  }

  void _refreshData() {
    print('🔄 Refreshing BlockSpot data...');
    print('🔄 Current bookings future: $_bookingsFuture');
    _loadData();
    print('🔄 After _loadData call, bookings future: $_bookingsFuture');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh when page becomes visible
    print('🔄 didChangeDependencies called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 PostFrameCallback executing refresh...');
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(BlockSpot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when widget updates (e.g., when coming back from other pages)
    print('🔄 didUpdateWidget called');
    print('🔄 Old userId: ${oldWidget.userId}, New userId: ${widget.userId}');
    if (oldWidget.userId != widget.userId) {
      print('🔄 UserId changed, refreshing data...');
      _refreshData();
    } else {
      print('🔄 UserId same, no refresh needed');
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
  // Helper function to round up to nearest rupee
  double roundUpToNearestRupee(double amount) {
    return amount.ceilToDouble();
  }


  void _navigateToPayment(VehicleBooking vehicle, double roundedBaseAmount,
      double roundedGst, double roundedHandlingFee, double finalTotal) {
    
    // Calculate new subscription end date (add 1 month to current end date)
    String newEndDate = _calculateNewEndDate(vehicle.subscriptionenddate);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPayment(
          venodorname: vehicle.vendorname,
          vendorid: vehicle.vendorId,
          userid: widget.userId,
          mobilenumber: vehicle.mobileNumber,
          vehicleid: vehicle.id,
          amout: roundedBaseAmount.toStringAsFixed(2),
          payableduration: _formatDuration(vehicle.payableduration),
          handlingfee: roundedHandlingFee.toStringAsFixed(2),
          gstfee: roundedGst.toStringAsFixed(2),
          totalamount: finalTotal.toStringAsFixed(2),
          // Add renewal parameters
          bookingid: vehicle.id,
          months: 1, // Default to 1 month renewal
          newEndDate: newEndDate,
        ),
      ),
    ).then((result) {
      // Refresh data when returning from payment page
      print('🔄 Returning from payment page, refreshing data...');
      print('🔄 Navigation result: $result');
      if (result == true) {
        print('🔄 Payment was successful, refreshing data...');
        _refreshData();
      } else {
        print('🔄 Payment was cancelled or failed, still refreshing data...');
        _refreshData();
      }
    }).catchError((error) {
      print('🔄 Navigation error: $error');
      print('🔄 Still refreshing data despite error...');
      _refreshData();
    });
  }

  String _calculateNewEndDate(String currentEndDate) {
    print('📅 Original subscription end date: $currentEndDate');
    
    try {
      // Parse current end date
      String endDateStr = currentEndDate.split(' ')[0];
      print('📅 Extracted date string: $endDateStr');
      
      DateTime baseDate;
      
      // Try different date formats
      try {
        baseDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
        print('📅 Parsed with dd-MM-yyyy: $baseDate');
      } catch (e1) {
        print('📅 Failed dd-MM-yyyy parsing: $e1');
        try {
          baseDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
          print('📅 Parsed with yyyy-MM-dd: $baseDate');
        } catch (e2) {
          print('📅 Failed yyyy-MM-dd parsing: $e2');
          try {
            baseDate = DateTime.parse(endDateStr);
            print('📅 Parsed as ISO date: $baseDate');
          } catch (e3) {
            print('📅 All parsing failed, using current date as base');
            baseDate = DateTime.now();
          }
        }
      }
      
      print('📅 Base date: $baseDate');
      print('📅 Base year: ${baseDate.year}, month: ${baseDate.month}, day: ${baseDate.day}');
      
      // Validate the year is reasonable
      if (baseDate.year < 2020 || baseDate.year > 2030) {
        print('❌ Invalid year detected: ${baseDate.year}, using current date as base');
        baseDate = DateTime.now();
      }
      
      // Add 1 month
      int newMonth = baseDate.month + 1;
      int newYear = baseDate.year;
      
      // Handle year overflow
      if (newMonth > 12) {
        newMonth -= 12;
        newYear += 1;
      }
      
      print('📅 New year: $newYear, new month: $newMonth');
      
      // Clamp the day to the last valid day of the new month if needed
      int lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
      int adjustedDay = baseDate.day > lastDayOfMonth ? lastDayOfMonth : baseDate.day;
      
      print('📅 Adjusted day: $adjustedDay (last day of month: $lastDayOfMonth)');
      
      DateTime newEndDate = DateTime(newYear, newMonth, adjustedDay);
      
      // Final validation - ensure the calculated date is reasonable
      if (newEndDate.year < 2020 || newEndDate.year > 2030) {
        print('❌ Calculated date has invalid year: ${newEndDate.year}, using fallback');
        DateTime fallbackDate = DateTime.now().add(const Duration(days: 30));
        String fallbackFormatted = DateFormat('dd-MM-yyyy').format(fallbackDate);
        print('📅 Using fallback date: $fallbackFormatted');
        return fallbackFormatted;
      }
      
      String formattedDate = DateFormat('dd-MM-yyyy').format(newEndDate);
      
      print('📅 Final calculated date: $newEndDate');
      print('📅 Formatted date: $formattedDate');
      
      return formattedDate;
    } catch (e) {
      print('❌ Error calculating new end date: $e');
      // Fallback: add 1 month to current date
      DateTime fallbackDate = DateTime.now().add(const Duration(days: 30));
      String fallbackFormatted = DateFormat('dd-MM-yyyy').format(fallbackDate);
      print('📅 Using fallback date: $fallbackFormatted');
      return fallbackFormatted;
    }
  }
  Future<List<VehicleBooking>> fetchBookings() async {
    final String url = "${ApiConfig.baseUrl}vendor/fetchmonthlybook/${widget.userId}";
    print("Fetching bookings from URL: $url");

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      print('HTTP Status Code: ${response.statusCode}');
      print('Raw Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('error')) {
          print('Error from API: ${responseData['error']}');
          return [];
        }

        if (responseData['bookings'] is List) {
          List<dynamic> data = responseData['bookings'];

          print('Total bookings received: ${data.length}');

          if (data.isNotEmpty) {
            // Print details for each booking
            for (var bookingJson in data) {
              print('--- Booking Debug ---');
              print('Vehicle Number: ${bookingJson["vehicleNumber"]}');
              print('Parked Date: ${bookingJson["parkedDate"]}');
              print('Subscription End Date: ${bookingJson["subsctiptionenddate"]}');
              print('Status: ${bookingJson["status"]}');
            }

            return data.map((json) => VehicleBooking.fromJson(json)).toList();
          } else {
            print('No bookings found.');
            return [];
          }
        } else {
          print('Response does not contain a list of bookings: $responseData');
          return [];
        }
      } else {
        print('Failed to load booking data: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load booking data');
      }
    } catch (error) {
      print('Error fetching bookings: $error');
      throw Exception('Error fetching bookings: $error');
    }
  }


  Future<void> fetchChargesData(String vendorId, VehicleBooking booking) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          calculatePayableAmount(data['vendor']['charges'], booking);
        }
      }
    } catch (e) {
      print('Error fetching charges data: $e');
    }
  }

  void calculatePayableAmount(List<dynamic> charges, VehicleBooking booking) {
    double amount = 0.0;
    final vehicleCharges = charges
        .where((charge) => charge['category'] == booking.vehicleType)
        .toList();

    if (vehicleCharges.isNotEmpty) {
      var monthlyCharge = vehicleCharges
          .firstWhere((charge) => charge['type'] == 'Monthly', orElse: () => {});

      if (monthlyCharge.isNotEmpty) {
        amount += double.tryParse(monthlyCharge['amount'].toString()) ?? 0.0;
      }
    }

    setState(() {
      booking.payableAmount = amount;
    });
  }

  Future<List<VehicleBooking>> fetchBookingsAndCharges() async {
    try {
      List<VehicleBooking> bookings = await fetchBookings();
      await Future.wait(
          bookings.map((booking) => fetchChargesData(booking.vendorId, booking))
      );
      return bookings;
    } catch (e) {
      print('Error in fetchBookingsAndCharges: $e');
      rethrow;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }




  String _calculateRemainingDaysMessage(
      String parkedDate, String? subscriptionEndDate, String status, String vehicleNumber) {
    try {
      // Strict helper: parse date in dd-MM-yyyy or yyyy-MM-dd
      DateTime _parseDate(String dateStr) {
        dateStr = dateStr.trim();
        // Normalize date separator to '-'
        final normalized = dateStr.replaceAll('/', '-');
        if (normalized.contains('-')) {
          final parts = normalized.split('-');
          if (parts.length >= 3) {
            if (parts[0].length == 4) {
              // yyyy-MM-dd
              return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            } else {
              // dd-MM-yyyy
              return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          }
        }
        throw FormatException('Unable to parse date: $dateStr');
      }

      // Parse subscription start date (parked date)
      final DateTime subscriptionStartDate = _parseDate(parkedDate);

      // Parse subscription end date or fallback 30 days
      DateTime subscriptionEndDateParsed;
      if (subscriptionEndDate != null && subscriptionEndDate.isNotEmpty) {
        final String endDateStr = subscriptionEndDate.trim().split(' ')[0];
        subscriptionEndDateParsed = _parseDate(endDateStr);
      } else {
        subscriptionEndDateParsed = subscriptionStartDate.add(const Duration(days: 30));
      }

      // Date-only comparison
      final DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime startOnly = DateTime(subscriptionStartDate.year, subscriptionStartDate.month, subscriptionStartDate.day);
      final DateTime endOnly = DateTime(subscriptionEndDateParsed.year, subscriptionEndDateParsed.month, subscriptionEndDateParsed.day);

      String remainingDaysMessage;

      if (todayOnly.isAfter(endOnly)) {
        // Subscription expired
        remainingDaysMessage = "Expired";
      } else if (todayOnly.isBefore(startOnly)) {
        // Not started yet: show full subscription period (end - start)
        final int remainingDays = endOnly.difference(startOnly).inDays;
        remainingDaysMessage = remainingDays == 1 ? "1 day left" : "$remainingDays days left";
      } else {
        // Started (today >= parked date): show remaining days (end - today - 1)
        // Subtract 1 because parked date is day 0, so remaining = end - today - 1
        final int remainingDays = endOnly.difference(todayOnly).inDays;
        if (remainingDays <= 0) {
          remainingDaysMessage = "Expired";
        } else {
          // Subtract 1 to get correct remaining days
          int adjustedDays = remainingDays - 1;
          if (adjustedDays <= 0) {
            remainingDaysMessage = "Subscription ends today!";
          } else {
            remainingDaysMessage = "$adjustedDays days left";
          }
        }
      }

      // Debug info
      print('Debug Info for Vehicle: $vehicleNumber');
      print('Today: $todayOnly');
      print('Start Date: $startOnly');
      print('End Date: $endOnly');
      print('Message: $remainingDaysMessage');

      return remainingDaysMessage;
    } catch (e) {
      print('Error calculating remaining days for Vehicle: $vehicleNumber - $e');
      return 'N/A';
    }
  }




  @override
  Widget build(BuildContext context) {
    DateTime? subscriptionStartDate;
    DateTime? subscriptionEndDate;

    return Scaffold(
 appBar:
      AppBar(
        // backgroundColor:ColorUtils.primarycolor(),
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      title: Text(
        'Monthly Parking Subscription',
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 16,

        ),
      ),


    ),

      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
          // Wait for the data to load
          await _bookingsFuture;
        },
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: FutureBuilder<List<VehicleBooking>>(
            future: _bookingsFuture,
            builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child:  LoadingGif()
                  );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No Booking Found"));
            }

            final subscriptionBookings = snapshot.data!
                .where((booking) => isSubscriptionSts(booking.sts))
                .toList();

            if (subscriptionBookings.isEmpty) {
              return const Center(child: Text("No Subscription Bookings Found"));
            }

            return ListView.builder(
              itemCount: subscriptionBookings.length,
              itemBuilder: (context, index) {
                final vehicle = subscriptionBookings[index];

                final containerHeight = statusHeights[vehicle.status] ?? statusHeights['Default'];
                final parkingDate = vehicle.parkingDate;
                final parkingTime = vehicle.parkingTime;
                final bookedDate = vehicle.bookingDate;
                final bookedTime = vehicle.bookingTime;
                final parkeddate = vehicle.parkeddate;
                final parkedtime = vehicle.parkedtime;
                final combinedDateTimeString = '$parkingDate $parkingTime';
                final bookingcombine = '$bookedDate $bookedTime';
                final remainingDaysMessage = _calculateRemainingDaysMessage(
                  vehicle.parkeddate,
                  vehicle.subscriptionenddate, // Pass subscriptionenddate
                  vehicle.status,
                  vehicle.vehicleNumber
                );
                // final remainingDaysMessage = _calculateRemainingDaysMessage(parkeddate, parkedtime,vehicle.subscriptionenddate);
                DateTime? combinebook;
                try {
                  combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
                } catch (e) {
                  print('Error parsing booking date: $e');
                  combinebook = null;
                }

                String bookcom = combinebook != null
                    ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
                    : 'N/A';

                DateTime? combinedDateTime;
                try {
                  combinedDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(combinedDateTimeString);
                } catch (e) {
                  print('Error parsing parking date: $e');
                  combinedDateTime = null;
                }

                String formattedDateTime = combinedDateTime != null
                    ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
                    : 'N/A';

                final now = DateTime.now();
                DateTime? bookedDateTime;
                try {
                  bookedDateTime = DateFormat('yyyy-MM-dd hh:mm a').parse(combinedDateTimeString);
                } catch (e) {
                  print('Error parsing booked date: $e');
                  bookedDateTime = null;
                }

                DateTime? parkingEndDate;
                try {
                  parkingEndDate = DateFormat('dd-MM-yyyy hh:mm a').parse('$parkeddate $parkedtime')
                      .add(const Duration(days: 30));
                } catch (e) {
                  print('Error parsing parking end date: $e');
                  parkingEndDate = null;
                }

                final remainingDays = parkingEndDate != null
                    ? parkingEndDate.difference(now).inDays
                    : 0;
                return SizedBox(
                  height: 125,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 30,
                        right: 0,
                        child: Container(
                          height: containerHeight,
                          decoration: BoxDecoration(
                            color: vehicle.status == 'Cancelled'
                                ? Colors.red
                                : ColorUtils.primarycolor(),
                            borderRadius: const BorderRadius.only(
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
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Text(
                              bookcom,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => uvParkingDetails(
                                spaceid:vehicle.spaceid,
                                parkeddate: vehicle.parkeddate,
                                parkedtime: vehicle.parkedtime,
                                subscriptionenddate:vehicle.subscriptionenddate,
                                exitdate:vehicle.exitvehicledate,
                                exittime:vehicle.exitvehicletime,
                                invoiceid: vehicle.invoiceid,
                                userid: widget.userId,
                                sts: vehicle.sts,
                                bookingtype: vehicle.bookingtype,
                                otp: vehicle.otp,
                                vehiclenumber: vehicle.vehicleNumber,
                                vendorname: vehicle.vendorname,
                                vendorid: vehicle.vendorId,
                                parkingdate: vehicle.parkingDate,
                                parkingtime: vehicle.parkingTime,
                                bookedid: vehicle.id,
                                bookeddate: formattedDateTime,
                                schedule: bookcom,
                                status: vehicle.status,
                                vehicletype: vehicle.vehicleType, nav: 'monthly',
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                                        left: 14, top: 2, right: 0.0, bottom: 0.0),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: vehicle.status == 'Cancelled'
                                              ? Colors.red
                                              : ColorUtils.primarycolor(),
                                          width: 0.5,
                                        ),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(5.0),
                                        topRight: Radius.circular(5.0),
                                      ),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          vehicle.vehicleNumber,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: vehicle.status == 'Cancelled'
                                                ? Colors.red
                                                : ColorUtils.primarycolor(),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (vehicle.status == "PARKED")
                                          Text(
                                            remainingDaysMessage,
                                            style: GoogleFonts.poppins(
                                                color: ColorUtils.primarycolor()),
                                          ),
                                        if (vehicle.status == "Cancelled")
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12.0),
                                            child: Text(
                                              " ${vehicle.cancelledStatus}",
                                              style: GoogleFonts.poppins(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (vehicle.status != 'PARKED')
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12.0),
                                            child: Text(
                                              " ${vehicle.status}",
                                              style: GoogleFonts.poppins(
                                                color: vehicle.status == 'Cancelled'
                                                    ? Colors.red
                                                    : ColorUtils.primarycolor(),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

SizedBox(width: 5,),
                                        // Show renew button only for monthly subscriptions; hide for weekly/15-day passes
                                        if (vehicle.status.toUpperCase() == "PARKED" && (vehicle.spaceid == null || vehicle.spaceid!.isEmpty) && !isWeeklyOr15DayPassSts(vehicle.sts))
                                          SizedBox(
                                            height: 30,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  final result = await showModalBottomSheet<bool>(
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
                                                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                                            ),
                                                            child: RenewParkingSheet(
                                                              daysleft:remainingDaysMessage,
                                                              navi:"user",
                                                              onRefresh: _refreshData, // Pass the refresh method
                                                              userid: vehicle.userId,
                                                              otp: vehicle.otp,
                                                              vehicletype: vehicle.vehicleType,
                                                              bookingid: vehicle.id,
                                                              parkingdate: vehicle.parkingDate,
                                                              vehiclenumber: vehicle.vehicleNumber,
                                                              username: vehicle.username,
                                                              phoneno: vehicle.mobileNumber,
                                                              parkingtime: vehicle.parkingTime,
                                                              bookingtypetemporary: vehicle.status,
                                                              sts: vehicle.sts,
                                                              cartype: vehicle.carType,
                                                              vendorid: vehicle.vendorId,
                                                              parkeddate: vehicle.parkeddate,
                                                              parkedtime: vehicle.parkedtime,
                                                              status: vehicle.status, totalamount: '', gstfee: '', handlingfee: '', amout: '', payableduration: '', venodorname: '', subscriptionEndDate: vehicle.subscriptionenddate,
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  );
                                                  if (result == true && widget.onRefresh != null) {
                                                   widget.onRefresh!();
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.red,
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 5),
                                                  minimumSize: const Size(0, 0),
                                                  shape:  RoundedRectangleBorder(
                                                    borderRadius:
                                                    BorderRadius.all(Radius.circular(5)),
                                                    side: BorderSide(
                                                      color: ColorUtils.primarycolor(),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                     Icon(
                                                      Icons.autorenew,
                                                      color: ColorUtils.primarycolor(),
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Renew',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: ColorUtils.primarycolor(),
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
                                  const SizedBox(height: 0),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.only(
                                            left: 12.0, right: 15.0, top: 6.0, bottom: 6.0),
                                        decoration: BoxDecoration(
                                          color: vehicle.status == 'Cancelled'
                                              ? Colors.red
                                              : ColorUtils.primarycolor(),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(20.0),
                                            bottomRight: Radius.circular(20.0),
                                          ),
                                        ),
                                        child: Icon(
                                          vehicle.vehicleType == "Car"
                                              ? Icons.drive_eta
                                              : Icons.directions_bike,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const SizedBox(height: 10),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(
                                                    'Parking Schedule: ',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(
                                                    formattedDateTime,
                                                    style: GoogleFonts.poppins(fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'Remaining: ',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    remainingDaysMessage,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: ColorUtils.primarycolor(),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                Container(height: 5),
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
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
        ),
    );
  }
}