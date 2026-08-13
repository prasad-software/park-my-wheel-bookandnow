import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/parkindetails.dart';
import 'package:mywheels/auth/customer/parking/reschecule.dart';
import 'package:mywheels/auth/customer/parking/userpayment.dart';
import 'package:mywheels/auth/customer/scanpark.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:mywheels/config/authconfig.dart';

import 'package:mywheels/auth/customer/bottom.dart';
import 'package:mywheels/auth/customer/customerdash.dart';
import 'package:mywheels/auth/customer/customerprofile.dart';
import 'package:mywheels/auth/customer/drawer/customdrawer.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/model/user.dart';
import 'package:mywheels/pageloader.dart';
import '../addcarviewcar/mycars.dart';
import 'bookparking.dart';

class ParkingPage extends StatefulWidget {
  final String userId;
  const ParkingPage({super.key, required this.userId});

  @override
  _ParkingPageState createState() => _ParkingPageState();
}

class _ParkingPageState extends State<ParkingPage> with RouteAware, SingleTickerProviderStateMixin {
  int _selecteIndex = 3; // Track the selected tab index
  final Duration _totalPayableDuration = Duration.zero; //
  DateTime selectedDateTime =
  DateTime.now(); // Initialize with the current date and time
  late final Timer _payableTimer;
  late Future<List<VehicleBooking>> vehicleData;
  ValueNotifier<List<VehicleBooking>> bookingDataNotifier =
  ValueNotifier([]); // Update type to VehicleBooking

  ValueNotifier<Map<String, bool>> loadingPayableNotifier = ValueNotifier({});
  User? _user;
  bool _isLoading = true; // Add this variable to track loading state
  Timer? _timer;
  bool _isSlotListingExpanded = false;
  List<dynamic> charges = [];
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations = [];
  double payableAmount = 0.0;
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double totalAmountWithTaxes = 0.0;
  double totalPayableAmount = 0.0; // To hold the total payable amount
  late List<Widget> _pages;
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
    // Get the decimal part of the amount
    double decimal = amount - amount.floor();
    // If decimal is 0.5 or more, round up, otherwise round down
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }
  double calculateTotalWithTaxes(double payableAmount) {
    // Use original values (no per-component rounding)
    double parkingCharge = payableAmount;
    double handlingFeeAmount = handlingFee;

    // GST base = parking + handling
    double gstBase = parkingCharge + handlingFeeAmount;
    double gstAmount = (gstBase * gstPercentage) / 100;

    // Exact total
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;

    // Round only the final payable amount
    double roundedTotal = roundUpToNearestRupee(exactTotal);
    totalAmountWithTaxes = roundedTotal;
    return roundedTotal;
  }
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  void _TabChange(int index) {
    _navigatePage(index);
  }

  final Map<String, double> statusHeights = {
    'Cancelled': 85,
    'PENDING': 85,
    'PARKED': 85,

    'Default': 85,
  };
  void _showExitConfirmation(VehicleBooking vehicle) async {
    // Fetch GST and handling fee data only if it's a customer booking
    if (vehicle.userId.isNotEmpty) {
      try {
        final gstData = await fetchGstData();
        setState(() {
          gstPercentage = double.tryParse(gstData['gst'].toString()) ?? 0.0;
          handlingFee = double.tryParse(gstData['handlingfee'].toString()) ?? 0.0;
        });
      } catch (error) {
        print('Error fetching GST data: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load GST and handling fee data')),
        );
        return; // Exit if GST data fetching fails
      }
    } else {
      // For vendor bookings, set GST and handling fee to 0
      setState(() {
        gstPercentage = 0.0;
        handlingFee = 0.0;
      });
    }

    // Show the bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.04,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            "Vehicle No: ${vehicle.vehicleNumber}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ColorUtils.primarycolor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.cancel_outlined, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  // Circular Progress Indicator with Gradient and Ticks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First widget (the Stack with CircularProgressIndicator)
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.01),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.35,
                                height: MediaQuery.of(context).size.width * 0.35,
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
                                size: Size(
                                  MediaQuery.of(context).size.width * 0.35,
                                  MediaQuery.of(context).size.width * 0.35,
                                ),
                                painter: RadialTicksPainter(),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/car.svg',
                                    width: MediaQuery.of(context).size.width * 0.08,
                                    height: MediaQuery.of(context).size.width * 0.08,
                                  ),
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.002),
                                  Text(
                                    'PAYABLE TIME',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.002),
                                  ValueListenableBuilder<List<VehicleBooking>>(
                                    valueListenable: bookingDataNotifier,
                                    builder: (context, bookingData, child) {
                                      final booking = bookingData.firstWhere(
                                        (booking) => booking.id == vehicle.id,
                                        orElse: () => vehicle,
                                      );

                                      return Text(
                                        formatDuration(booking.payableduration),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Second widget (the details container)
                      Flexible(
                        flex: 1,
                        child: Container(
                          child: Padding(
                            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.01),
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
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      vehicle.id.length > 8 ? vehicle.id.substring(vehicle.id.length - 8) : vehicle.id,
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.001),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "In Time: ",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      "${vehicle.parkingDate} ${vehicle.parkingTime}",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.001),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Name: ",
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      vehicle.username.isEmpty ? vehicle.personName : vehicle.username,
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
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
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      vehicle.mobileNumber,
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
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
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      '${vehicle.sts} (${vehicle.bookingtype})',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
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
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                    Text(
                                      vehicle.userId.isEmpty ? 'Vendor' : 'Customer',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10 * MediaQuery.of(context).textScaleFactor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.001),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 5),
                  // Parking Charges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Parking Charges:",
                        style: GoogleFonts.poppins(
                          fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                          color: Colors.black,
                        ),
                      ),
                      ValueListenableBuilder<List<VehicleBooking>>(
                        valueListenable: bookingDataNotifier,
                        builder: (context, bookingData, child) {
                          final booking = bookingData.firstWhere(
                            (booking) => booking.id == vehicle.id,
                            orElse: () => vehicle,
                          );

                          double payableAmount = booking.payableAmount;
                          return Text(
                            "₹${payableAmount.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                              color: Colors.black,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (vehicle.userId.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Handling Fee:",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          "₹${handlingFee.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "GST ($gstPercentage%):",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                            color: Colors.black,
                          ),
                        ),
                        ValueListenableBuilder<List<VehicleBooking>>(
                          valueListenable: bookingDataNotifier,
                          builder: (context, bookingData, child) {
                            final booking = bookingData.firstWhere(
                              (booking) => booking.id == vehicle.id,
                              orElse: () => vehicle,
                            );

                            double payableAmount = booking.payableAmount;
                            double gstBase = payableAmount + handlingFee;
                            double gstAmount = (gstBase * gstPercentage) / 100;
                            return Text(
                              "₹${gstAmount.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                                color: Colors.black,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                  ],
                  // Total Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Payable Amount:",
                        style: GoogleFonts.poppins(
                          fontSize: 14 * MediaQuery.of(context).textScaleFactor,
                          color: ColorUtils.primarycolor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ValueListenableBuilder<List<VehicleBooking>>(
                        valueListenable: bookingDataNotifier,
                        builder: (context, bookingData, child) {
                          final booking = bookingData.firstWhere(
                            (booking) => booking.id == vehicle.id,
                            orElse: () => vehicle,
                          );

                          double payableAmount = booking.payableAmount;
                          double total = calculateTotalWithTaxes(payableAmount);
                          return Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 14 * MediaQuery.of(context).textScaleFactor,
                              color: ColorUtils.primarycolor(),
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  // Exit Vehicle Button
                  Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.04,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPayment(vehicle);
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
                              size: MediaQuery.of(context).size.width * 0.05,
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                            Text(
                              'Exit Vehicle',
                              style: GoogleFonts.poppins(
                                fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPayment(VehicleBooking vehicle) {
    // Calculate amounts without per-component rounding; round only final total
    double parkingCharge = vehicle.payableAmount;
    double handlingFeeAmount = handlingFee;
    double gstBase = parkingCharge + handlingFeeAmount;
    double gstAmount = (gstBase * gstPercentage) / 100;
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
    double finalTotal = roundUpToNearestRupee(exactTotal);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPayment(
          venodorname: vehicle.vendorname,
          vendorid: vehicle.vendorId,
          userid: widget.userId,
          mobilenumber: vehicle.mobileNumber,
          vehicleid: vehicle.id,
          amout: parkingCharge.toStringAsFixed(2), // Parking charge (unrounded)
          payableduration: _formatDuration(vehicle.payableduration),
          handlingfee: handlingFeeAmount.toStringAsFixed(2), // Handling fee (unrounded)
          gstfee: gstAmount.toStringAsFixed(2), // GST (unrounded)
          totalamount: finalTotal.toStringAsFixed(2), // Final total (rounded)
        ),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    vehicleData = fetchBookings();
    _pages = [
      customdashScreen(userId: widget.userId),
      CarPage(userId: widget.userId),
      scanpark(userId: widget.userId),
      ParkingPage(userId: widget.userId),
      CProfilePage(userId: widget.userId),
    ];
    _fetchUserData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Same as CarPage
    );
    // Fetch initial bookings and set up timer
    vehicleData.then((data) {
      bookingDataNotifier.value = data;
      fetchPayableAmountsForParkedBookings();
      _startTimer();
      // Initialize animations after data is fetched
      if (data.isNotEmpty) {
        _initializeItemAnimations(data.length);
      }
    }).catchError((error) {
      print('Error fetching booking data: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _startTimer() {
    // Cancel any existing timer to prevent duplicates
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Changed to 30 seconds for more frequent updates
      if (mounted) {
        // Update payable times and fetch payable amounts
        fetchPayableAmountsForParkedBookings();
        updatePayableTimes();


        checkNoShowStatus();
        checkExpiringBookings();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _fetchData();
  }
  void _initializeItemAnimations(int count) {
    _itemAnimations = count > 0
        ? List.generate(count, (index) {
      double start = index * 0.1; // 100ms delay per item
      double end = (index * 0.1) + 0.6; // 600ms animation per item
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    })
        : [];
    if (count > 0) {
      _animationController.forward();
    } else {
      _animationController.reset(); // Reset animation controller if no items
    }
  }
  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose(); // Dispose of animation controller
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the current route has been popped off and the top route is this one
    _fetchData();
    _startTimer();
    super.didPopNext();
  }


  @override
  void didPush() {
    // Called when this route has been pushed
    _fetchData();
    _startTimer();
    super.didPush();
  }
  bool _isFetching = false;

  Future<void> _fetchData() async {
    if (_isFetching) return;

    try {
      _isFetching = true;
      List<VehicleBooking> bookings = await fetchBookings();
      bookingDataNotifier.value = bookings;
      await fetchPayableAmountsForParkedBookings();
      updatePayableTimes();
    } catch (error) {
      print('Error fetching booking data: $error');
    } finally {
      _isFetching = false;
    }
  }
  void _cancelpending(String vehicleNumber, String location, String bookingId,
      VehicleBooking vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Add this for better control
      useSafeArea: true, // Enable safe area
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea( // Add SafeArea wrapper
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure you want to cancel this booking?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text('Vehicle Number: $vehicleNumber'),
                Text('Location: $location'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    SizedBox(
                      width: 70,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          updatependingcancel(bookingId, 'Cancelled')
                              .then((success) {
                            if (success) {
                              if (mounted) {
                                Navigator.pop(context);
                                fetchBookingsAndCharges();
                              }
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    // Reschedule Button
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => reschedule(

                                vehicleId: vehicle.id,
                                vendorname: vehicle.vendorname,
                                vehicle: vehicle.vehicleNumber,
                                parkingdate: vehicle.parkingDate,
                                parkingtime: vehicle.parkingTime,
                                userId: widget.userId, Vendorid: vehicle.vendorId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Reschedule',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
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
  void _showCancelConfirmation(String vehicleNumber, String location,
      String bookingId, VehicleBooking vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Add this for better control
      useSafeArea: true, // Enable safe area
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20.0)), // Rounded corners
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure you want to cancel this booking?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text('Vehicle Number: $vehicleNumber'),
                Text('Location: $location'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel Button
                    SizedBox(
                      width: 70, // Set a fixed width for the button
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          updateapprovecancel(bookingId, 'Cancelled')
                              .then((success) {
                            if (success) {
                              Navigator.pop(context); // Close the modal
                              fetchBookingsAndCharges(); // Refresh the bookings
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red, // Red for cancel action
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4), // Reduced padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white), // Reduced font size
                        ),
                      ),
                    ),
                    // Reschedule Button
                    SizedBox(
                      width: 100, // Set a fixed width for the button
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => reschedule(
                                  Vendorid:vehicle.vendorId,
                                vehicleId: vehicle.id,
                                vendorname: vehicle.vendorname,
                                vehicle: vehicle.vehicleNumber,
                                parkingdate: vehicle.parkingDate,
                                parkingtime: vehicle.parkingTime,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils
                              .primarycolor(), // Green for reschedule action
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8), // Reduced padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          'Reschedule',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white), // Reduced font size
                        ),
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

  Future<void> showBookingSlotNotification(
      String vehicleNumber,
      String mallName,
      String id,
      String parkingDate,
      String parkingTime,
      String vendorid,
      String bookingdate,
      String bookingtime,
      String vehicletype,
      String status,
      ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'booking_slot_channel', // Channel ID
      'Booking Slot Notifications', // Channel name
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('bell'), // Add your custom sound
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    Map<String, dynamic> payload = {
      'type': 'booking_slot',
      'id': id,
      'vehicleNumber': vehicleNumber,
      'vendorName': mallName,
      'parkingDate': parkingDate,
      'parkingTime': parkingTime,
      'vendorId': vendorid,
      'bookingDate': bookingdate,
      'bookingTime': bookingtime,
      'vehicleType': vehicletype,
      'status': status, // Replace with actual status
    };
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Booking Slot Alert',
      'Your booking slot for vehicle $vehicleNumber at $mallName will open soon. Booking ID: $id. Please park or reschedule.',

      platformChannelSpecifics,
      payload: jsonEncode(payload), // Optional payload
    );
    await storeNotification(
        widget.userId,
        'Booking Slot Alert',
        'Your booking slot for vehicle $vehicleNumber at $mallName will open soon. Booking ID: $id. Please park or reschedule.',
        payload);
  }

  Future<void> showParkingSlotStartedNotification(String vehicleNumber,
      String mallName, String id, Map<String, dynamic> payload) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'parking_slot_started_channel', // Channel ID
      'Parking Slot Started Notifications', // Channel name
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('bell'),
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      1, // Notification ID
      'Parking Slot Started',
      'Your parking slot for vehicle $vehicleNumber at $mallName has started now. Booking ID: $id.',

      platformChannelSpecifics,
      payload: jsonEncode(payload), // Optional payload
    );
    await storeNotification(
        widget.userId,
        'Parking Slot Started',
        'Your parking slot for vehicle $vehicleNumber at $mallName has started now. Booking ID: $id.',
        payload);
  }

  void checkExpiringBookings() {
    final now = DateTime.now();
    for (var vehicle in bookingDataNotifier.value) {
      if (vehicle.status == 'Approved') {
        // Parse the booking date and time
        DateTime? bookedDateTime;
        try {
          bookedDateTime = parseParkingDateTime(
              "${vehicle.parkingDate} ${vehicle.parkingTime}");
        } catch (e) {
          print('Error parsing booking date and time: $e');
          continue; // Skip this vehicle if parsing fails
        }

        // Check if 1 minute has passed since the booking
        if (now.difference(bookedDateTime).inMinutes == 1) {
          // Changed to exactly 1 minute
          // Send notification for expiring booking
          showBookingSlotNotification(
              vehicle.vehicleNumber,
              vehicle.vendorname,
              vehicle.id,
              vehicle.parkingDate,
              vehicle.parkingTime,
              vehicle.vendorId,
              vehicle.bookingDate,
              vehicle.bookingTime,
              vehicle.vehicleType,
              vehicle.status);
        }

        // Check if the parking slot has started
        if (now.isAfter(bookedDateTime) &&
            now.isBefore(bookedDateTime.add(const Duration(minutes: 1)))) {
          // Send notification that the parking slot has started
          showParkingSlotStartedNotification(
              vehicle.vehicleNumber, vehicle.vendorname, vehicle.id, {});
        }
      }
    }
  }

  Future<void> storeNotification(String userId, String title, String body,
      Map<String, dynamic> payload) async {
    try {
      final notificationData = {
        'userId': userId,
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp':
        FieldValue.serverTimestamp(), // Automatically set the timestamp
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      print("Notification stored successfully.");
    } catch (e) {
      print("Error storing notification: $e");
    }
  }

  void _navigatePage(int index) {
    setState(() {
      _selecteIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }

  Future<void> fetchBookingsAndCharges() async {
    try {
      List<VehicleBooking> bookings = await fetchBookings();
      bookingDataNotifier.value = bookings;
      await fetchPayableAmountsForParkedBookings();
      updatePayableTimes();
      // Re-initialize animations when bookings change
      if (bookings.isNotEmpty) {
        _animationController.reset();
        _initializeItemAnimations(bookings.length);
      }
    } catch (error) {
      print('Error fetching booking data: $error');
    }
  }
  Future<void> fetchPayableAmountsForParkedBookings() async {
    for (var booking in bookingDataNotifier.value) {
      if (booking.status == 'PARKED') {
        await fetchPayableAmount(booking.id);
      }
    }
  }
  Future<void> fetchPayableAmount(String bookingId) async {
    final String url = "${ApiConfig.baseUrl}vendor/fet/$bookingId";
    // Find the current booking to check if amount is already loaded
    final currentBookingIndex = bookingDataNotifier.value.indexWhere((b) => b.id == bookingId);
    // Only show loading indicator if amount hasn't been loaded yet (is 0.0)
    // This prevents the exit button from hiding on every periodic refresh
    final bool shouldShowLoading = currentBookingIndex == -1 || 
        bookingDataNotifier.value[currentBookingIndex].payableAmount == 0.0;
    if (shouldShowLoading) {
      loadingPayableNotifier.value = {...loadingPayableNotifier.value, bookingId: true};
      loadingPayableNotifier.notifyListeners();
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final double payableAmount = double.tryParse(data['payableAmount'].toString()) ?? 0.0;
          // Extract spaceid and spacearea from API response
          final String? spaceid = data['spaceid']?.toString();
          final String? spacearea = data['spacearea']?.toString();
          
          // Update the booking data
          final updatedBookings = List<VehicleBooking>.from(bookingDataNotifier.value);
          final index = updatedBookings.indexWhere((b) => b.id == bookingId);
          if (index != -1) {
            updatedBookings[index] = VehicleBooking(
              invoiceid: updatedBookings[index].invoiceid,
              invoice: updatedBookings[index].invoice,
              subscriptionenddate: updatedBookings[index].subscriptionenddate,
              bookingtype: updatedBookings[index].bookingtype,
              // Copy all existing fields
              username: updatedBookings[index].username,
              id: updatedBookings[index].id,
              userId: updatedBookings[index].userId,
              vendorId: updatedBookings[index].vendorId,
              amount: updatedBookings[index].amount,
              hour: updatedBookings[index].hour,
              vehicleType: updatedBookings[index].vehicleType,
              personName: updatedBookings[index].personName,
              mobileNumber: updatedBookings[index].mobileNumber,
              carType: updatedBookings[index].carType,
              vehicleNumber: updatedBookings[index].vehicleNumber,
              bookingDate: updatedBookings[index].bookingDate,
              parkeddate: updatedBookings[index].parkeddate,
              parkedtime: updatedBookings[index].parkedtime,
              subscriptionType: updatedBookings[index].subscriptionType,
              bookingTime: updatedBookings[index].bookingTime,
              status: updatedBookings[index].status,
              sts: updatedBookings[index].sts,
              otp: updatedBookings[index].otp,
              vendorname: updatedBookings[index].vendorname,
              cancelledStatus: updatedBookings[index].cancelledStatus,
              approvedDate: updatedBookings[index].approvedDate,
              approvedTime: updatedBookings[index].approvedTime,
              cancelledDate: updatedBookings[index].cancelledDate,
              cancelledTime: updatedBookings[index].cancelledTime,
              exitvehicledate: updatedBookings[index].exitvehicledate,
              exitvehicletime: updatedBookings[index].exitvehicletime,
              parkingDate: updatedBookings[index].parkingDate,
              parkingTime: updatedBookings[index].parkingTime,
              payableduration: updatedBookings[index].payableduration,
              payableAmount: payableAmount, // Update payableAmount
              spaceid: spaceid, // Update spaceid from API response
              spacearea: spacearea, // Update spacearea from API response
            );
            bookingDataNotifier.value = updatedBookings; // Trigger UI update
          }
        } else {
          print('Failed to fetch payable amount for booking $bookingId: ${data['message']}');
        }
      } else {
        print('Failed to load payable amount for booking $bookingId: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching payable amount for booking $bookingId: $error');
    } finally {
      // Always stop the loading indicator after fetch completes (only if it was set)
      if (shouldShowLoading) {
        loadingPayableNotifier.value = {...loadingPayableNotifier.value, bookingId: false};
        loadingPayableNotifier.notifyListeners();
      }
    }
  }
  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData = bookingDataNotifier.value.map((booking) {
      if (booking.status == 'PARKED') {
        try {
          final parkingTime = parseParkingDateTime(
            "${booking.parkeddate} ${booking.parkedtime}",
          );
          final elapsed = now.difference(parkingTime);
          booking.payableduration = elapsed.isNegative ? Duration.zero : elapsed;
        } catch (e) {
          print('Error parsing parked date/time for booking ${booking.id}: $e');
          booking.payableduration = Duration.zero;
        }
      }
      return booking;
    }).toList();
    bookingDataNotifier.value = updatedData; // Trigger UI update
  }
// Charge model


  DateTime parseParkingDateTime(String dateTimeString) {
    // Example input: "27-01-2025 04:35 PM"
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':');

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    int second = 0; // Default to 0 if seconds are not provided

    // Handle AM/PM
    if (parts[2] == 'PM' && hour != 12) {
      hour += 12; // Convert to 24-hour format
    } else if (parts[2] == 'AM' && hour == 12) {
      hour = 0; // Midnight case
    }

    return DateTime(year, month, day, hour, minute, second);
  }

  Duration getTotalParkedTime(String parkingDateTimeString) {
    DateTime parkingDateTime = parseParkingDateTime(parkingDateTimeString);
    DateTime now =
    DateTime.now(); // You can replace this with server time if available

    Duration difference = now.difference(parkingDateTime);

    if (difference.isNegative) {
      return Duration
          .zero; // Return zero duration if the parking time has not started yet
    }

    return difference; // Return the duration
  }

  String formatDuration(Duration duration) {
    final hours =
    duration.inHours.toString().padLeft(2, '0'); // Ensure two digits
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }

  void checkNoShowStatus() {
    final now = DateTime.now();
    for (var vehicle in bookingDataNotifier.value) {
      if (vehicle.status == 'Approved') {
        // Parse the booking date and time
        DateTime? bookedDateTime;
        try {
          bookedDateTime = parseParkingDateTime(
              "${vehicle.parkingDate} ${vehicle.parkingTime}");
        } catch (e) {
          print('Error parsing booking date and time: $e');
          continue; // Skip this vehicle if parsing fails
        }

        // Check if 10 minutes have passed since the booking
        if (now.difference(bookedDateTime).inMinutes >= 10) {
          // Update the status to "No Show"
          updateBookingStatus(vehicle.id, 'No Show').then((_) {
            // After updating the status, refresh the booking data
            fetchBookingsAndCharges(); // Fetch updated data
          });
        }
      }
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    final url =
    Uri.parse('${ApiConfig.baseUrl}vendor/usercancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParkingPage(
                userId: widget.userId), // Replace with actual user ID
          ),
        );
        // Show booking status update notification
        final vehicleNumber = responseBody['data']
        ['vehicleNumber']; // Adjust this based on your API response
        final mallname = responseBody['data']['vendorName'];
        final String parkingDate =
        responseBody['data']['parkingDate']; // Example: "2025-03-07"
        final String parkingTime =
        responseBody['data']['parkingTime']; // Example: "14:30:00"

        final vendorid = responseBody['data']['vendorId'];
        final bookingdate = responseBody['data']['bookingDate'];
        final bookingtime = responseBody['data']['bookingTime'];
        final vehicletype = responseBody['data']['vehicleType'];
        final status = responseBody['data']['status'];
        final id = responseBody['data']['_id'];
        await showCancellationNotification(
          vehicleNumber,
          mallname,
          id,
          {
            "id": id,
            'vehicleNumber': vehicleNumber,
            'vendorname': mallname,
            'vendorId': vendorid,
            'bookingDate': bookingdate,
            'bookingTime': bookingtime,
            'vehicleType': vehicletype,
            'status': status,
            'parkingDate': parkingDate,
            'parkingTime': parkingTime,
          },
        );
      } else {
        print(
            'Failed to update booking: ${response.statusCode} ${response.body}');
        // Attempt to decode JSON response
        try {
          final errorResponse = jsonDecode(response.body);
          throw Exception(
              errorResponse['message'] ?? 'Failed to update booking status');
        } catch (e) {
          throw Exception('Failed to update booking status: ${response.body}');
        }
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }

  Future<List<VehicleBooking>> fetchBookings() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    final String url = "${ApiConfig.baseUrl}vendor/subget/${widget.userId}";
    print("Fetching bookings from URL: $url");

    try {
      final response = await http.get(Uri.parse(url));

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('error')) {
          print('Error from API: ${responseData['error']}');
          return [];
        }

        if (responseData['bookings'] is List) {
          List<dynamic> data = responseData['bookings'];
          if (data.isNotEmpty) {
            List<VehicleBooking> bookings =
            data.map((json) => VehicleBooking.fromJson(json)).toList();
            print("Fetched ${bookings.length} bookings");
            return bookings;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching bookings: $error')),
      );
      return []; // Return empty list to prevent UI crash
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
  Future<bool> updatependingcancel(String bookingId, String newStatus) async {
    final url =
    Uri.parse('${ApiConfig.baseUrl}vendor/usercancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParkingPage(
                userId: widget.userId), // Replace with actual user ID
          ),
        );
        // Show cancellation notification
        final vehicleNumber = responseBody['data']
        ['vehicleNumber']; // Adjust this based on your API response
        final mallname = responseBody['data']['vendorName'];
        final String parkingDate =
        responseBody['data']['parkingDate']; // Example: "2025-03-07"
        final String parkingTime =
        responseBody['data']['parkingTime']; // Example: "14:30:00"

        final vendorid = responseBody['data']['vendorId'];
        final bookingdate = responseBody['data']['bookingDate'];
        final bookingtime = responseBody['data']['bookingTime'];
        final vehicletype = responseBody['data']['vehicleType'];
        final status = responseBody['data']['status'];
        final id = responseBody['data']['_id'];
        await showCancellationNotification(
          vehicleNumber,
          mallname,
          id,
          {
            "id": id,
            'vehicleNumber': vehicleNumber,
            'vendorname': mallname,
            'vendorId': vendorid,
            'bookingDate': bookingdate,
            'bookingTime': bookingtime,
            'vehicleType': vehicletype,
            'status': status,
            'parkingDate': parkingDate,
            'parkingTime': parkingTime,
          },
        );

        return true; // Return true on success
      } else {
        print(
            'Failed to update booking: ${response.statusCode} ${response.body}');
        return false; // Return false on failure
      }
    } catch (error) {
      print('Error updating booking status: $error');
      return false; // Return false on error
    }
  }

  Future<bool> updateapprovecancel(String bookingId, String newStatus) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/approvedcancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');

        // Show cancellation notification
        final vehicleNumber = responseBody['data']
        ['vehicleNumber']; // Adjust this based on your API response
        final mallname = responseBody['data']['vendorName'];
        final String parkingDate =
        responseBody['data']['parkingDate']; // Example: "2025-03-07"
        final String parkingTime =
        responseBody['data']['parkingTime']; // Example: "14:30:00"

        final vendorid = responseBody['data']['vendorId'];
        final bookingdate = responseBody['data']['bookingDate'];
        final bookingtime = responseBody['data']['bookingTime'];
        final vehicletype = responseBody['data']['vehicleType'];
        final status = responseBody['data']['status'];
        final id = responseBody['data']['_id'];
        await showCancellationNotification(
          vehicleNumber,
          mallname,
          id,
          {
            'vehicleNumber': vehicleNumber,
            'vendorname': mallname,
            'vendorId': vendorid,
            'bookingDate': bookingdate,
            "id": id,
            'bookingTime': bookingtime,
            'vehicleType': vehicletype,
            'status': status,
            'parkingDate': parkingDate,
            'parkingTime': parkingTime,
          },
        );

        return true; // Return true on success
      } else {
        print(
            'Failed to update booking: ${response.statusCode} ${response.body}');
        return false; // Return false on failure
      }
    } catch (error) {
      print('Error updating booking status: $error');
      return false; // Return false on error
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(
                data['data']); // Initialize user with fetched data
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
    }
  }

  // Calculate the payable amount based on parking duration
  Future<void> showCancellationNotification(String vehicleNumber,
      String mallName, String id, Map<String, dynamic> payload) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'cancellation_channel', // Channel ID
      'Cancellation Notifications', // Channel name
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('bell'),
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      3, // Notification ID
      'Slot Cancelled',
      'Your parking slot for vehicle $vehicleNumber at $mallName has been cancelled. Booking ID: $id.',
      platformChannelSpecifics,
      payload: jsonEncode(payload), // Optional payload
    );
    await storeNotification(
        widget.userId,
        'Slot Cancelled',
        'Your parking slot for vehicle $vehicleNumber at $mallName has been cancelled. Booking ID: $id.',
        payload); // Add the missing payload argument
  }



  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 50,
        iconTheme:
        const IconThemeData(color: Colors.black), // Set icon color to white
        title: Text('My Parking',
            style: GoogleFonts.poppins(color: Colors.black,fontSize: 18)),
        // backgroundColor: ColorUtils.primarycolor(), // Custom app bar color
        actions: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              // backgroundColor: ColorUtils.primarycolor(), // Button background
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(
              Icons.add_circle,
              color: Colors.black,
              size: 24,
            ),
            label: const Text(
              'Book Now',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChooseParkingPage(
                    userId: widget.userId,
                    selectedOption: 'Instant',
                  ),
                ),
              );
            },
          ),

          const SizedBox(
            width: 0,
          ),
        ],
      ),
      drawer: CustomDrawer(
        userid: widget.userId,
        imageUrl: _user?.imageUrl ?? '',
        username: _user?.username ?? '',
        mobileNumber: _user?.mobileNumber ?? '',
        onLogout: () {
          // Handle logout logic here
        },
        isSlotListingExpanded: _isSlotListingExpanded,
        onSlotListingToggle: () {
          setState(() {
            _isSlotListingExpanded = !_isSlotListingExpanded;
          });
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : Padding(
        padding: const EdgeInsets.only(top: 5.0, right: 5, left: 5),
        child:RefreshIndicator(
          onRefresh: fetchBookingsAndCharges,
          child: ValueListenableBuilder<List<VehicleBooking>>(
            valueListenable: bookingDataNotifier,
            builder: (context, bookingList, child) {
              if (bookingList.isEmpty) {
                return const Center(child: Text("No Booking Found"));
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6.0, vertical: 4.0),
                child: ListView.separated(
                  itemCount: bookingList.length,
                  separatorBuilder: (context, index) {
                    final vehicle = bookingList[index];
                    return vehicle.status == 'PARKED' ? const SizedBox(height: 10) : const SizedBox.shrink();
                  },
                  itemBuilder: (context, index) {
                    final animation = index < _itemAnimations.length
                        ? _itemAnimations[index]
                        : const AlwaysStoppedAnimation<double>(1.0);

                    final vehicle = bookingList[index];
                    final formattedPayableDuration =
                    vehicle.payableduration != null
                        ? _formatDuration(vehicle.payableduration)
                        : 'N/A';
                    double? containerHeight =
                        statusHeights[vehicle.status] ??
                            statusHeights['Default'];
                    final String parkingDate =
                        vehicle.parkingDate; // e.g., '19-02-2025'
                    final String parkingTime =
                        vehicle.parkingTime; // e.g., '10:20 PM'
                    final String bookedDate =
                        vehicle.bookingDate; // e.g., '19-02-2025'
                    final String bookedTime =
                        vehicle.bookingTime; // e.g., '10:20 PM'

                    final String combinedDateTimeString =
                        '$parkingDate $parkingTime';
                    final String bookingcombine = '$bookedDate $bookedTime';
                    DateTime? combinebook;
                    try {
                      combinebook = DateFormat('dd-MM-yyyy hh:mm a')
                          .parse(bookingcombine);
                    } catch (e) {
                      print('Error parsing combined date and time: $e');
                      combinebook = null;
                    }
                    String bookcom = combinebook != null
                        ? DateFormat('d MMM, yyyy, hh:mm a')
                        .format(combinebook)
                        : 'N/A';

                    DateTime? combinedDateTime;
                    try {
                      combinedDateTime = DateFormat('dd-MM-yyyy hh:mm a')
                          .parse(combinedDateTimeString);
                    } catch (e) {
                      print('Error parsing combined date and time: $e');
                      combinedDateTime = null;
                    }
                    String formattedDateTime = combinedDateTime != null
                        ? DateFormat('d MMM, yyyy, hh:mm a')
                        .format(combinedDateTime)
                        : 'N/A';

                    final now = DateTime.now();
                    DateTime? bookedDateTime;
                    try {
                      bookedDateTime = DateFormat('yyyy-MM-dd hh:mm a')
                          .parse(combinedDateTimeString);
                    } catch (e) {
                      print('Error parsing booking date and time: $e');
                      bookedDateTime = null;
                    }

                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - animation.value) * 100), // Same slide-up effect
                          child: Opacity(
                            opacity: animation.value,
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 135,
                        child: Stack(
                          children: [

                            Positioned(

                              left: 0, // Align to the left edge
                              right: 0, //
                              top: vehicle.status == 'PARKED'
                                  ? 48
                                  : vehicle.status == 'COMPLETED'
                                  ? 40
                                  : vehicle.status == 'Cancelled'
                                  ? 28
                                  : vehicle.status == 'PENDING'
                                  ? 37
                                  : 35,


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
                                    // Moved inside BoxDecoration
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.bottomCenter, // Center the text
                                child: Padding(
                                  padding: const EdgeInsets.only(top:
                                      5.0,bottom: 5.0), // Added padding for better spacing
                                  child: Text(
                                    'Booked on $bookcom',
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
                                    builder: (context) => uParkingDetails(
                                        parkeddate: vehicle.parkeddate,
                                        parkedtime: vehicle.parkedtime,
subscriptionenddate:vehicle.subscriptionenddate,
exitdate:vehicle.exitvehicledate,
    exittime:vehicle.exitvehicletime,
invoiceid:vehicle.invoiceid,
                                        invoice:vehicle.invoice,
                                      mobilenumber:vehicle.mobileNumber,
                                      nav:"daily",
                                      userid:vehicle.userId,
                                        sts:vehicle.sts,
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
                                        vehicletype: vehicle.vehicleType),
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
                                      // border: Border.all(color: Colors.black, width: 0.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                          Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.only(
                                              left: 14,
                                              top: 2,
                                              right: 0.0,
                                              bottom: 0.0),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: vehicle.status ==
                                                    'Cancelled'
                                                    ? Colors.red
                                                    : ColorUtils
                                                    .primarycolor(), // Your primary color
                                                width: 0.5, // Border width
                                              ),
                                            ),
                                            borderRadius:
                                            const BorderRadius.only(
                                              topLeft: Radius.circular(5.0),
                                              topRight: Radius.circular(5.0),
                                            ),
                                            color:
                                            vehicle.status == 'Cancelled'
                                                ? Colors.white
                                                : Colors.white,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                            children: [
                                              // Vehicle Number
                                              Text(
                                                vehicle.vehicleNumber,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: vehicle.status ==
                                                      'Cancelled'
                                                      ? Colors.red
                                                      : ColorUtils
                                                      .primarycolor(),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                      
                                              // Spacer to push the status and buttons to the right
                                              const Spacer(),
                      
                                              // Conditional rendering of status text and buttons
                                              if (vehicle.status == "PARKED")
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "$formattedPayableDuration  ",
                                                      style: GoogleFonts.poppins(
                                                          color: ColorUtils
                                                              .primarycolor()),
                                                    ),
                                                    // Show "Parked" text only when spaceid is present
                                                    if (vehicle.spaceid != null && vehicle.spaceid!.isNotEmpty)
                                                      Text(
                                                        "Parked",
                                                        style: GoogleFonts.poppins(
                                                          color: ColorUtils.primarycolor(),
                                                          fontWeight: FontWeight.bold,
                                                            fontSize: 20,
                                                        ),
                                                      ),
                                                    SizedBox(width: 5,)
                                                  ],
                                                ),

                                              if (vehicle.status ==
                                                  "Cancelled")
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 12.0),
                                                  child: Text(
                                                    " ${vehicle.cancelledStatus}",
                                                    style: GoogleFonts.poppins(
                                                        color: vehicle
                                                            .status ==
                                                            'Cancelled'
                                                            ? Colors.red
                                                            : ColorUtils
                                                            .primarycolor(),
                                                        fontWeight:
                                                        FontWeight.bold),
                                                  ),
                                                ),
                                              if ((vehicle.cancelledStatus?.isEmpty ?? true) &&
                                                  vehicle.status == 'Cancelled')
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 12.0),
                                                  child: Text(
                                                    " ${vehicle.status}",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                      
                      
                      
                      
                                              if (vehicle.status == "PENDING")
                                                SizedBox(
                                                  height:
                                                  30, // Fixed height for the container
                                                  child: Center(
                                                    // Center the IconButton within the container
                                                    child: IconButton(
                                                      onPressed: () async {
                                                        // await updateapprovecancel(vehicle.id, 'Cancelled');
                                                        // // Fetch updated bookings after cancellation
                                                        // await fetchBookingsAndCharges(); // Fetch updated data
                                                        // setState(() {});
                                                        // _showCancelConfirmation(vehicle);
                                                        _cancelpending(
                                                            vehicle
                                                                .vehicleNumber,
                                                            vehicle
                                                                .vendorname,
                                                            vehicle.id,
                                                            vehicle);
                                                      },
                                                      icon: const Icon(Icons
                                                          .cancel_outlined),
                                                      iconSize:
                                                      19, // Icon size
                                                      color: Colors.black,
                                                      padding: EdgeInsets
                                                          .zero, // Remove padding to reduce space
                                                    ),
                                                  ),
                                                ),
                                              if (vehicle.status == "PARKED")
                                                ValueListenableBuilder<Map<String, bool>>(
                                                  valueListenable: loadingPayableNotifier,
                                                  builder: (context, loadingPayable, child) {
                                                    final isLoadingPayable = loadingPayable[vehicle.id] ?? false;

                                                    if (isLoadingPayable || vehicle.payableAmount == 0.0) {
                                                      return SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor()),
                                                        ),
                                                      );
                                                    } else {
                                                      // Hide exit button if spaceid is present
                                                      if (vehicle.spaceid != null && vehicle.spaceid!.isNotEmpty) {
                                                        return const SizedBox.shrink(); // Hide the button
                                                      }
                                                      
                                                      return SizedBox(
                                                        height: 30,
                                                        child: Padding(
                                                          padding: const EdgeInsets.only(right: 10.0),
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              _showExitConfirmation(vehicle); // Show confirmation bottom sheet
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.white, // Transparent background
                                                              foregroundColor: Colors.red, // Text & Icon color
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                              minimumSize: const Size(0, 0),
                                                              shape: const RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.all(Radius.circular(5)),
                                                                side: BorderSide(
                                                                  color: Colors.red, // Border color
                                                                  width: 0.5,
                                                                ),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(
                                                                  Icons.qr_code_scanner,
                                                                  color: Colors.red, // Icon color
                                                                  size: 16,
                                                                ),
                                                                const SizedBox(width: 10),
                                                                Text(
                                                                  'Exit',
                                                                  style: GoogleFonts.poppins(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.red, // Text color
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                      
                                              if (vehicle.status ==
                                                  "Approved" &&
                                                  bookedDateTime != null &&
                                                  now.isAfter(bookedDateTime))
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      height: 25,
                                                      child: ElevatedButton(
                                                        onPressed: () {
                                                          // Navigator.push(
                                                          //   context,
                                                          //   MaterialPageRoute(
                                                          //       builder: (context) =>
                                                          //           enterpage(
                                                          //               userId: widget
                                                          //                   .userId)),
                                                          // );
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor: Colors
                                                              .white, // Transparent background
                                                          foregroundColor: ColorUtils
                                                              .primarycolor(), // Text & Icon color
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 14,
                                                              vertical: 4),
                                                          minimumSize:
                                                          const Size(0, 0),
                                                          shape:
                                                          const RoundedRectangleBorder(
                                                            borderRadius:
                                                            BorderRadius
                                                                .all(Radius
                                                                .circular(
                                                                5)),
                                                            side: BorderSide(
                                                              color: Colors
                                                                  .black, // Border color
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                          MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .qr_code_scanner,
                                                              color: Colors
                                                                  .black, // Icon color
                                                              size: 16,
                                                            ),
                                                            const SizedBox(
                                                                width: 5),
                                                            Text(
                                                              'Park',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 12,
                                                                // fontWeight: FontWeight.bold,
                                                                color: Colors
                                                                    .black, // Text color
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: 35,
                                                      child: IconButton(
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (context) =>
                                                                  reschedule(
                                                                    Vendorid: vehicle.vendorId,
                                                                    vehicleId:
                                                                    vehicle
                                                                        .id,
                                                                    vendorname:
                                                                    vehicle
                                                                        .vendorname,
                                                                    vehicle: vehicle
                                                                        .vehicleNumber,
                                                                    parkingdate:
                                                                    vehicle
                                                                        .parkingDate,
                                                                    parkingtime:
                                                                    vehicle
                                                                        .parkingTime,
                                                                    userId: widget
                                                                        .userId,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                        icon: const Icon(Icons
                                                            .calendar_month_outlined),
                                                        iconSize: 19,
                                                        color: Colors.black,
                                                        // Remove padding to reduce space
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height:
                                                      30, // Fixed height for the container
                                                      child: Center(
                                                        // Center the IconButton within the container
                                                        child: IconButton(
                                                          onPressed:
                                                              () async {
                                                            // await updateapprovecancel(vehicle.id, 'Cancelled');
                                                            // // Fetch updated bookings after cancellation
                                                            // await fetchBookingsAndCharges(); // Fetch updated data
                                                            // setState(() {});
                                                            // _showCancelConfirmation(vehicle);
                                                            _showCancelConfirmation(
                                                                vehicle
                                                                    .vehicleNumber,
                                                                vehicle
                                                                    .vendorname,
                                                                vehicle.id,
                                                                vehicle);
                                                          },
                                                          icon: const Icon(Icons
                                                              .cancel_outlined),
                                                          iconSize:
                                                          19, // Icon size
                                                          color: Colors.black,
                                                          padding: EdgeInsets
                                                              .zero, // Remove padding to reduce space
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 0),
                                        Row(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.only(
                                                  left: 12.0,
                                                  right: 15.0,
                                                  top: 6.0,
                                                  bottom:
                                                  6.0), // Optional: Adds space inside the container
                                              decoration: BoxDecoration(
                                                color: vehicle.status ==
                                                    'Cancelled'
                                                    ? Colors.red
                                                    : ColorUtils
                                                    .primarycolor(),
                                                borderRadius:
                                                const BorderRadius.only(
                                                  topRight:
                                                  Radius.circular(20.0),
                                                  bottomRight:
                                                  Radius.circular(20.0),
                                                ),
                                              ),
                                              child: Icon(
                                                vehicle.vehicleType == "Car"
                                                    ? Icons.drive_eta // Car icon
                                                    : vehicle.vehicleType == "Bike"
                                                    ? Icons.directions_bike // Bike icon
                                                    : Icons.directions_transit, // Others icon (e.g., boat as placeholder)
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
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(
                                                            top: 8.0),
                                                        child: Text(
                                                          'Parking Schedule: ',
                                                          style: GoogleFonts
                                                              .poppins(
                                                              fontSize:
                                                              14,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                        const EdgeInsets
                                                            .only(
                                                            top: 8.0),
                                                        child: Text(
                                                          formattedDateTime,
                                                          // combinedDateTimeString,
                      
                                                          style: GoogleFonts
                                                              .poppins(
                                                              fontSize:
                                                              12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Location:',
                                                        style: GoogleFonts
                                                            .poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold),
                                                      ),
                                                      Text(
                                                        vehicle.vendorname.length > 25
                                                            ? '${vehicle.vendorname.substring(0, 25)}...'
                                                            : vehicle.vendorname,
                                                        style: GoogleFonts.poppins(fontSize: 12),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),

                                                    ],
                                                  ),
                                                  if (vehicle.status ==
                                                      "Cancelled")
                                                    // sss
                                                  Row(
                                                    children: [

                                                      Text(
                                                        '',
                                                        style: GoogleFonts
                                                            .poppins(
                                                            fontSize: 5),
                                                      ),
                                                    ],
                                                  ),
                                                  if (vehicle.status == "PENDING")
                                                    Text(
                                                      '',
                                                      style: GoogleFonts
                                                          .poppins(
                                                          fontSize: 5),
                                                    ),// if (vehicle.status ==
                                                  //     "Cancelled")

                                                    if (vehicle.status ==
                                                        "COMPLETED")
                                                      Row(
                                                        children: [
                                                          Text(
                                                            'Total Paid Amount:',
                                                            style: GoogleFonts
                                                                .poppins(
                                                                fontSize:
                                                                14,
                                                                fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                          ),
                                                          Text(
                                                              " ${vehicle.amount}",
                                                              style: GoogleFonts
                                                                  .poppins(fontSize: 14,
                                                                  color: Colors
                                                                      .black)),
                                                        ],
                                                      ),
                                                  Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .start,
                                                    children: [
                                                      Container(
                                                        height: 5,
                                                      ),
                                                      if (vehicle.status ==
                                                          "PARKED")
                                                        Column(
                                                          children: [
                                                            Container(
                                                              // height: 50,
                                                              alignment: Alignment
                                                                  .topCenter,
                                                              child: vehicle
                                                                  .payableAmount >
                                                                  0.0 // Check if payable amount is greater than 0
                                                                  ? Text(
                                                                'Payable: ₹${roundUpToNearestRupee(vehicle.payableAmount).toStringAsFixed(2)}', // Use vehicle's payable amount
                                                                style: GoogleFonts.poppins(
                                                                    fontSize:
                                                                    14,
                                                                    fontWeight:
                                                                    FontWeight.bold),
                                                              )
                                                                  :  SizedBox(
                                                                                  width: 20,
                                                                                  height: 10,
                                                                                  child: CircularProgressIndicator(
                                                                                  strokeWidth: 2,
                                                                                  valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor()),
                                                                                  ),),
                                                            ),
                                                            Container(
                                                              height: 5,
                                                            ),
                                                          ],
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        ),
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        selectedIndex: _selecteIndex,
        onTabChange: _TabChange,
      ),
    );
  }
}

class VehicleBooking {
  final String id;
  final String userId;
  final String vendorId;
  final String username;
  final String amount;
  final String hour;
  final String vehicleType;
  final String personName;
  final String mobileNumber;
  final String carType;
  final String vehicleNumber;
  final String bookingDate;
  final String parkingDate;
  final String parkingTime;
  final String subscriptionType;
  final String bookingTime;
  final String status;
  final String sts;
  final String    parkeddate;
  final String parkedtime;
  final String vendorname;
  final String? cancelledStatus;
  final String exitvehicledate;
  final String invoiceid;
  final String exitvehicletime;
  final String otp;
  final String? approvedDate;
  final String? approvedTime;
  final String? cancelledDate;
  final String? cancelledTime;
  final String bookingtype;
  final String subscriptionenddate;
  final String invoice;
  
  // Add spaceid field
  String? spaceid;
  String? spacearea;

  Duration payableduration;
  double payableAmount;

  VehicleBooking({
    this.payableAmount = 0.0,
    required this.vendorname,
    this.payableduration = Duration.zero,
    required this.id,
    required this.username,
    required this.userId,
    required this.invoiceid,
    required this.vendorId,
    required this.bookingtype,
    required this.amount,
    required this.hour,
    required this.otp,
    required this.exitvehicledate,
    required this.exitvehicletime,
    required this.vehicleType,
    required this.parkingDate,
    required this.parkingTime,
    required this.personName,
    required this.mobileNumber,
    required this.carType,
    required this.vehicleNumber,
    required this.bookingDate,
    required this.parkeddate,
    required this.invoice,
    required this.parkedtime,
    required this.subscriptionType,
    required this.bookingTime,
    required this.status,
    required this.sts,
    required this.subscriptionenddate,
    this.cancelledStatus,
    this.approvedDate,
    this.approvedTime,
    this.cancelledDate,
    this.cancelledTime,
    this.spaceid,  // Add spaceid parameter
    this.spacearea,  // Add spacearea parameter
  });

  // Factory constructor to create a Booking instance from JSON
  factory VehicleBooking.fromJson(Map<String, dynamic> json) {
    return VehicleBooking(
      invoiceid:json['invoiceid']??"",
      invoice: json['invoice']??"",
      username: json['personName']??"",
      bookingtype: json['bookType']??"",
      otp:json['otp']??"",
      payableduration: Duration.zero,
      id: json['_id'] ?? '', // Provide a default value
      userId: json['userid'] ?? '', // Provide a default value
      vendorId: json['vendorId'] ?? '', // Provide a default value
      amount: json['totalamout'] ?? '',
      subscriptionenddate: (json['subsctiptionenddate'] ?? json['subsctiptionenddate'] ?? '').toString(),
      hour: json['hour'] ?? '',
      vehicleType: json['vehicleType'] ?? '', // Provide a default value
      personName: json['personName'] ?? '', // Provide a default value
      mobileNumber: json['mobileNumber'] ?? '', // Provide a default value
      carType: json['carType'] ?? '', // Provide a default value
      vehicleNumber: json['vehicleNumber'] ?? '', // Provide a default value
      bookingDate: json['bookingDate'] ?? '', // Provide a default value
      parkingDate: json['parkingDate'] ?? '', // Provide a default value
      parkingTime: json['parkingTime'] ?? '', // Provide a default value
      subscriptionType:
      json['subsctiptiontype'] ?? '', // Provide a default value
      bookingTime: json['bookingTime'] ?? '', // Provide a default value
      status: json['status'] ?? '', // Provide a default value
      sts: json['sts'] ?? '', // Provide a default value
      cancelledStatus: json['cancelledStatus'],
      approvedDate: json['approvedDate'] ?? '',
      approvedTime: json['approvedTime'] ?? '',
      cancelledDate: json['cancelledDate'] ?? '',
      cancelledTime: json['cancelledTime'] ?? '',
      parkeddate: json['parkedDate'] ?? '', // Provide a default value
      parkedtime: json['parkedTime'] ?? '', // Provide a default value
      exitvehicledate: json['exitvehicledate'] ?? '',
      exitvehicletime: json['exitvehicletime'] ?? '',
      vendorname: json['vendorName'] ?? '', // Provide a default value
      spaceid: json['spaceid']?.toString(), // Parse spaceid from API response
      spacearea: json['spacearea']?.toString(), // Parse spacearea from API response
    );
  }
  // Custom date parsing method
  static DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]), // Year
        int.parse(parts[1]), // Month
        int.parse(parts[0]), // Day
      );
    }
    throw FormatException('Invalid date format: $dateStr');
  }
}

class Charge {
  final String type;
  final String amount;
  final String category;

  Charge({required this.type, required this.amount, required this.category});

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      type: json['type'],
      amount: json['amount'],
      category: json['category'],
    );
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
      final angle = (2 * math.pi / totalTicks) * i - math.pi / 2; // Start at top
      final isLargeTick = i % 5 == 0;

      // Determine the color based on the angle
      if (angle >= -math.pi / 2 && angle <= math.pi / 2) {
        tickPaint.color = ColorUtils.primarycolor();
      } else {
        tickPaint.color = Colors.black; // Other half (left side)
      }

      final tickStart = Offset(
        center.dx + (radius - (isLargeTick ? largeTickLength : tickLength)) * math.cos(angle),
        center.dy + (radius - (isLargeTick ? largeTickLength : tickLength)) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
