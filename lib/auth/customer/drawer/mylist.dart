import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mywheels/auth/customer/addspace.dart';
import 'package:mywheels/auth/customer/dummypages/drawermyspace.dart';
import 'package:mywheels/auth/customer/parking/parkindetails.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/vendor/subscription/vendorsubscriptonbooking.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:http/http.dart' as http; // Ensure http package is imported
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/utils/sts_utils.dart';
import 'package:pinput/pinput.dart';
import '../../../config/authconfig.dart';
import '../myspacesub.dart';

class mybusiness extends StatefulWidget {
  final String vendorId;
  const mybusiness({super.key, required this.vendorId}); // ✅ Fixed comma placement


  @override
  _listbookingState createState() => _listbookingState();
}


class _listbookingState extends State<mybusiness> {
  Vendor? _vendor;
  bool _isLoading = true;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _fetchVendorData();
  }

  List<Vendor> _vendors = []; // ✅ Store all vendors instead of one

  Future<void> _fetchVendorData() async {
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final String url =
          '${ApiConfig.baseUrl}vendor/fetchspace/${widget.vendorId}';
      print('Fetching vendor data from URL: $url');

      final response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Response data: $data');

        if (data['data'] == null || (data['data'] as List).isEmpty) {
          throw Exception('No vendor data found');
        }

        setState(() {
          _vendors =
              (data['data'] as List) // ✅ Convert List<dynamic> to List<Vendor>
                  .map((vendor) => Vendor.fromJson(vendor))
                  .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load vendor data');
      }
    } catch (error) {
      print('Error fetching vendor data: $error');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> checkSubscriptionAndNavigate(
      BuildContext context, String vendorId, String vendorName) async {
    // final url = 'http://localhost:4000/vendor/fetchsubscriptionleft/$vendorId';
    final url = '${ApiConfig.baseUrl}vendor/fetchsubscriptionleft/$vendorId';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['subscriptionleft'].toString() == '0') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MySpacePlan(vendorid: vendorId, userid: widget.vendorId,)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => fulldetails(
                id: vendorId,
                vendorname: vendorName,
                vendorId: vendorId,
                userid:widget.vendorId
              ),
            ),
          );
        }
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching subscription: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return  Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        title: Text(
          'My Business',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => addmyspace(vendorid: widget.vendorId),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif()
            : _vendors.isEmpty
          ? const Center(
        child: Text(
          "No space details found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _vendors.length, // ✅ Loop through all vendors
        itemBuilder: (context, index) {
          final vendor = _vendors[index];

          return GestureDetector(
            onTap: () {
              checkSubscriptionAndNavigate(context, vendor.id, vendor.vendorName);
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => fulldetails(
//                     id:vendor.id,
// vendorname:vendor.vendorName,
//                     vendorId: vendor.id,
//                   ),
//                 ),
//               );
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: ColorUtils.primarycolor(), width: 0.5),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Text(widget.vendorId),
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: vendor.image.isNotEmpty
                            ? NetworkImage(vendor.image)
                            : null,
                        child: vendor.image.isEmpty
                            ? const Icon(Icons.store,
                            size: 30, color: Colors.black54)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  vendor.vendorName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const Spacer(),
                       Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: vendor.status == 'approved'
                                ? Colors.green[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(5),
                          ),
                         child: Text(
                           (vendor.status ?? 'Pending')[0].toUpperCase() + (vendor.status ?? 'Pending').substring(1),
                           style: GoogleFonts.poppins(
                             fontSize: 12,
                             color: vendor.status == 'approved'
                                 ? Colors.black
                                 : Colors.red,
                             fontWeight: FontWeight.bold,
                           ),
                         ),

                       ),

                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Address:',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vendor.address,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[800]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
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
      ),),
    );
  }
}
class Vendor {
  final String id;
  final String vendorName;
  final String vendorid;
  final String latitude;
  final String longitude;
  final String address;
  final String landMark;
  final String image;
  final String status;
  final String spaceid;

  double? distance;


  Vendor({
    required this.id,
    required this.vendorName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.landMark,
    required this.image,
    required this.spaceid,
    required this.vendorid,
    required this.status,

    this.distance,
  });
  Vendor copyWith({
    String? id,
    String? spaceid,
    String? vendorName,
    String? address,
    String? landMark,
    String? image,
    String? vendorid,
    String? latitude,
    String? longitude,
    String? status,

  }) {
    return Vendor(
      status:status??this.status,
      spaceid: spaceid ?? this.spaceid,
      id: id ?? this.id,
      vendorid: vendorid ?? this.vendorid,
      vendorName: vendorName ?? this.vendorName,
      address: address ?? this.address,
      landMark: landMark ?? this.landMark,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,

    );
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      status: json['status'] as String,
      vendorid: json['vendorId'],
      spaceid: json['spaceid'],
      id: json['_id'],
      vendorName: json['vendorName'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      landMark: json['landMark'],
      image: json['image'],

    );
  }
}
class fulldetails extends StatefulWidget {
  final String vendorId;
  final String id;
  final String vendorname;
  final String userid;
  const fulldetails({super.key, required this.vendorId,required this.vendorname,required this.id, required this.userid,});

  @override
  _MyListState createState() => _MyListState();
}
class _MyListState extends State<fulldetails> with TickerProviderStateMixin {
  File? _selectedImage;
  final bool _isLoading = false;
  int selectedTabIndex = 0;
  int selectedSegment = 0; // Default selected segment
  late List<Widget> _pages;
  final DateTime _selectedDate = DateTime.now();
  late final TabController _controller;
  late final TabController _chargesController;
  DateTime selectedDateTime = DateTime.now();
  int selectedtSegment = 0;
  late final Timer _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    _controller = TabController(vsync: this, length: 2);

    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
      });
      if (selectedTabIndex == 0) {
        refreshBookingData();
      }
    });

    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });

    refreshBookingData();
  }

  void refreshBookingData() {
    setState(() {
      isLoading = true;
    });
    fetchBookingData().then((data) {
      if (mounted) {
        setState(() {
          bookingDataNotifier.value = data;
          isLoading = false;
        });
        updatePayableTimes();
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        print('Error fetching booking data: $error');
      }
    });
  }
  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0'); // Ensure two digits
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }
  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData = bookingDataNotifier.value.map((booking) {
      if (booking.status == 'PARKED' || booking.status == 'Booked') {
        final parkingTime = parseParkingDateTime(
          "${booking.parkeddate} ${booking.parkedtime}",
        );
        final elapsed = now.difference(parkingTime);

        // Debugging: Print elapsed time
        // print('Elapsed Time for ${booking.vehicleNumber}: $elapsed');

        // Ensure we update the payableDuration with correct values
        booking.payableDuration = elapsed;
      }
      return booking;
    }).toList();
    // Navigator.pop(context);
    // Trigger a rebuild of the widget with the updated data
    bookingDataNotifier.value = updatedData;
  }

  DateTime parseParkingDateTime(String dateTimeString) {
    // Example input: "06-12-2024 11:04 AM"
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':'); // Change from '.' to ':'

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Handle AM/PM
    if (parts[2] == 'PM' && hour != 12) {
      hour += 12; // Convert to 24-hour format
    } else if (parts[2] == 'AM' && hour == 12) {
      hour = 0; // Midnight case
    }

    return DateTime(year, month, day, hour, minute);
  }
  Duration getTotalParkedTime(String parkingDateTimeString) {
    DateTime parkingDateTime = parseParkingDateTime(parkingDateTimeString);
    DateTime now = DateTime.now(); // You can replace this with server time if available

    Duration difference = now.difference(parkingDateTime);

    if (difference.isNegative) {
      return Duration.zero; // Return zero duration if the parking time has not started yet
    }

    return difference; // Return the duration
  }
  @override
  void dispose() {
    _payableTimer.cancel();
    _controller.dispose();
    bookingDataNotifier.dispose();
    super.dispose();
  }




  Future<void> updateAllowParking(String bookingId, String newStatus, String parkedDate, String parkedTime) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/allowparking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus, 'parkedDate': parkedDate, 'parkedTime': parkedTime}),
      );

      if (response.statusCode == 200) {

        final responseBody = jsonDecode(response.body);
        refreshBookingData();
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        _handleErrorResponse(response);
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }

  Future<List<Bookingdata>> fetchBookingData() async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (!jsonResponse.containsKey('bookings')) {
          throw Exception('Key "bookings" not found in response');
        }

        final List<dynamic>? data = jsonResponse['bookings'];
        if (data == null || data.isEmpty) {
          throw Exception('No bookings found');
        }

        return data.map((item) => Bookingdata.fromJson(item)).toList();
      } catch (e) {
        throw Exception('Failed to parse JSON: $e');
      }
    } else {
      throw Exception(response.body);
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus, String approvedDate, String approvedTime) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/approvebooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus, 'approvedDate': approvedDate, 'approvedTime': approvedTime}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        refreshBookingData();
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        _handleErrorResponse(response);
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }

  Future<void> updateCancel(String bookingId, String newStatus) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/cancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        refreshBookingData();
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        _handleErrorResponse(response);
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }
  Future<void> updatecancel(String bookingId, String newStatus) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/cancelbooking/$bookingId');

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
      } else {
        print('Failed to update booking: ${response.statusCode} ${response.body}');
        // Attempt to decode JSON response
        try {
          final errorResponse = jsonDecode(response.body);
          throw Exception(errorResponse['message'] ?? 'Failed to update booking status');
        } catch (e) {
          throw Exception('Failed to update booking status: ${response.body}');
        }
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }

  Future<void> updateApproveCancel(String bookingId, String newStatus) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/approvedcancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        _handleErrorResponse(response);
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }
  Future<void> refreshBookingList() async {
    try {
      // Fetch the updated list of bookings
      final updatedBookings = await fetchBookingData();
      // Update your UI or state management solution with the new list
      // For example, if you're using a state management solution like Provider or Bloc, notify listeners or update the state here
      print('Booking list refreshed with ${updatedBookings.length} bookings.');
    } catch (e) {
      print('Error refreshing booking list: $e');
    }
  }

  Future<void> _showOtpModal(BuildContext context, Bookingdata vehicle) async {
    // If vehicle.userid != true, allow parking directly without OTP
    if (vehicle.userid.isEmpty) {
      DateTime now = DateTime.now();
      String parkedDate = DateFormat('dd-MM-yyyy').format(now);
      String parkedTime = DateFormat('hh:mm a').format(now);

      try {
        await updateAllowParking(vehicle.id, 'PARKED', parkedDate, parkedTime);
        if (context.mounted) {
          await refreshBookingList(); // Refresh the booking list
          setState(() {}); // Trigger a rebuild
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Parking allowed successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: ColorUtils.primarycolor(),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to allow parking: ${e.toString()}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    // ----- OTP Modal Flow -----
    final TextEditingController otpController = TextEditingController();
    bool isOtpEntered = false;
    bool isLoading = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final textScaleFactor = MediaQuery.of(context).textScaleFactor;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter OTP to Allow Parking',
                        style: GoogleFonts.poppins(
                          fontSize: 16 * textScaleFactor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Pinput(
                        length: 3,
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setModalState(() {
                            isOtpEntered = value.length == 3;
                            errorMessage = null;
                          });
                        },
                        onCompleted: (value) {
                          setModalState(() {
                            isOtpEntered = true;
                            errorMessage = null;
                          });
                        },
                        defaultPinTheme: PinTheme(
                          width: 50,
                          height: 50,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 50,
                          height: 50,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.primarycolor(),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColorUtils.primarycolor(), width: 2),
                          ),
                        ),
                        submittedPinTheme: PinTheme(
                          width: 50,
                          height: 50,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ColorUtils.primarycolor(), width: 2),
                          ),
                        ),
                        errorPinTheme: PinTheme(
                          width: 50,
                          height: 50,
                          textStyle: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                        ),
                        forceErrorState: errorMessage != null, // show red border when error
                      ),

                      // Show error text if OTP is wrong
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: isLoading
                            ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.cyan),
                        )
                            : ElevatedButton(
                          onPressed: isOtpEntered
                              ? () async {
                            setModalState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            bool isOtpValid = otpController.text == vehicle.otp.substring(0, 3);

                            if (isOtpValid) {
                              DateTime now = DateTime.now();
                              String parkedDate = DateFormat('dd-MM-yyyy').format(now);
                              String parkedTime = DateFormat('hh:mm a').format(now);

                              try {
                                await updateAllowParking(
                                    vehicle.id, 'PARKED', parkedDate, parkedTime);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  await refreshBookingList();
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Parking allowed successfully',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: ColorUtils.primarycolor(),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isLoading = false;
                                  errorMessage = 'Failed to allow parking: ${e.toString()}';
                                });
                              }
                            } else {
                              setModalState(() {
                                isLoading = false;
                                errorMessage = 'Invalid OTP. Please try again.';
                              });
                            }
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOtpEntered
                                ? ColorUtils.primarycolor()
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isOtpEntered ? 3 : 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Allow Parking',
                                style: GoogleFonts.poppins(
                                  fontSize: 14 * textScaleFactor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_outline, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    otpController.dispose();
  }

// Client-side OTP verification (replace with API if needed)
  void _handleErrorResponse(http.Response response) {
    print('Failed to update booking: ${response.statusCode} ${response.body}');
    try {
      final errorResponse = jsonDecode(response.body);
      throw Exception(errorResponse['message'] ?? 'Failed to update booking status');
    } catch (e) {
      throw Exception('Failed to update booking status: ${response.body}');
    }
  }
  Future<void> updateapprovecancel(String bookingId, String newStatus) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/approvedcancelbooking/$bookingId');

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
      } else {
        print('Failed to update booking: ${response.statusCode} ${response.body}');
        // Attempt to decode JSON response
        try {
          final errorResponse = jsonDecode(response.body);
          throw Exception(errorResponse['message'] ?? 'Failed to update booking status');
        } catch (e) {
          throw Exception('Failed to update booking status: ${response.body}');
        }
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }
  Widget buildCategoryColumn(String category, String count) {
    return Column(
      children: [
        Text(
          category,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          child: Text(
            count,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(widget.vendorname, style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MySpacePlan(
userid:widget.userid,
                    vendorid: widget.vendorId,
                     ),
                ),
              );
            },
            icon: const Icon(Icons.subscriptions),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VendorDetailsPage(

                      vendorId: widget.vendorId,
                      id: widget.id),
                ),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Text(widget.vendorId),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: CustomSlidingSegmentedControl<int>(
              initialValue: selectedTabIndex,
              isStretch: true,
              children: {
                0: Text('Pending', style: GoogleFonts.poppins(fontSize: 14)),
                1: Text('Approved', style: GoogleFonts.poppins(fontSize: 14)),
              },
              onValueChanged: (value) {
                setState(() {
                  selectedTabIndex = value;
                });
              },
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              thumbDecoration: BoxDecoration(color: ColorUtils.secondarycolor(), borderRadius: BorderRadius.circular(6)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInToLinear,
            ),
          ),
          Flexible(
            child: IndexedStack(
              index: selectedTabIndex,
              children: [
                _buildPendingTab(),
                _buildApprovedTab(),
              ],
            ),
          ),
        ],
      ),),
    );
  }

  Widget _buildApprovedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: SizedBox(
                height: 30,
                child: CustomSlidingSegmentedControl<int>(
                  initialValue: selectedSegment,
                  children: {
                    0: Text("Parked", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                    1: Text("Approved", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                    2: Text("Completed", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)), // Changed key to 2
                  },
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  thumbDecoration: BoxDecoration(
                    color: ColorUtils.primarycolor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  onValueChanged: (value) async {
                    setState(() {
                      selectedSegment = value;
                    });
                    // Refresh data when tab changes
                    await fetchBookingData().then((data) {
                      setState(() {
                        bookingDataNotifier.value = data;
                      });
                    });
                  },
                ),
              ),
            ),
          ),
        ),

        IndexedStack(
          index: selectedSegment,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ValueListenableBuilder<List<Bookingdata>>(
                valueListenable: bookingDataNotifier,
                builder: (context, bookingData, child) {
                  // Filter data for PARKED status
                  final filteredData = bookingData.where((booking) {
                    return booking.Vendorid == widget.vendorId &&
                        (booking.status == 'PARKED' || booking.status == 'Parked');
                  }).toList();

                  if (filteredData.isEmpty) {
                    return const Center(child: Text('No vehicles parked'));
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                    child: ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final vehicle = filteredData[index];
                        // Use subscription UI from vendorsubscriptonbooking.dart if booking is Subscription
                        if (isSubscriptionSts(vehicle.sts?.toString())) {
                          return myspacesubleft(
                            vehicle: vehicle,
                            onRefresh: refreshBookingData,
                          );
                        }
                        // Otherwise use regular UI
                        return userdashleft(
                          vehicle: vehicle,
                          onRefresh: refreshBookingData,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: FutureBuilder<List<Bookingdata>>(
                    future: fetchBookingData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(50.0),
                            child: Image.asset('assets/gifload.gif'),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No Approved Request Pending'),
                        );
                      }

                      // Show all approved bookings (all dates)
                      final filteredData = snapshot.data!.where((booking) {
                        return booking.Vendorid == widget.vendorId && booking.status == 'Approved';
                      }).toList();

                      if (filteredData.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Text('No Approved Request Pending'),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7, // Give ListView a height
                          child: ListView.builder(
                            itemCount: filteredData.length,
                            itemBuilder: (context, index) {
                              final vehicle = filteredData[index];

                              return SizedBox(
                                height: 120,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 30,
                                      right: 0,
                                      child: Container(
                                        height: 85,
                                        decoration: BoxDecoration(
                                          color: ColorUtils.primarycolor(),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(30),
                                            bottomRight: Radius.circular(30),
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
                                        alignment:
                                        Alignment.bottomCenter, // Center the text
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              5.0), // Added padding for better spacing
                                          child: Text(
                                            ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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







                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 5.0),
                                                      child: SizedBox(
                                                        height: 25,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets.only(
                                                              right: 8.0),
                                                          child: ElevatedButton(
                                                     onPressed: ()=>_showOtpModal(context,vehicle),

                                                            style: ElevatedButton
                                                                .styleFrom(
                                                              backgroundColor: Colors
                                                                  .white, // Transparent background
                                                              foregroundColor: Colors
                                                                  .red, // Text & Icon color
                                                              padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                  10,
                                                                  vertical: 5),
                                                              minimumSize:
                                                              const Size(0, 0),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                const BorderRadius
                                                                    .all(Radius
                                                                    .circular(
                                                                    5)),
                                                                side:
                                                                BorderSide(
                                                                  color: ColorUtils.primarycolor(), // Border color
                                                                  width: 0.5,
                                                                ),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                              MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .check_circle_outline,
                                                                  color: ColorUtils.primarycolor(), // Icon color
                                                                  size: 14,
                                                                ),
                                                                const SizedBox(width: 5),
                                                                Text(
                                                                  'Allow parking',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    fontSize: 10,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                    color:  ColorUtils.primarycolor(), // Text color
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 5.0),
                                                      child: SizedBox(
                                                        height: 25,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets.only(
                                                              right: 8.0),
                                                          child: ElevatedButton(
                                                            onPressed: () async {
                                                              await updateapprovecancel(vehicle.id, 'Cancelled');
                                                              setState(() {});
                                                            },
                                                            style: ElevatedButton
                                                                .styleFrom(
                                                              backgroundColor: Colors
                                                                  .white, // Transparent background
                                                              foregroundColor: Colors
                                                                  .red, // Text & Icon color
                                                              padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                  10,
                                                                  vertical: 5),
                                                              minimumSize:
                                                              const Size(0, 0),
                                                              shape: const RoundedRectangleBorder(
                                                                borderRadius:
                                                                BorderRadius
                                                                    .all(Radius
                                                                    .circular(
                                                                    5)),
                                                                side:
                                                                BorderSide(
                                                                  color:  Colors
                                                                      .red, // Border color
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
                                                                  color:  Colors
                                                                      .red, // Icon color
                                                                  size: 14,
                                                                ),
                                                                const SizedBox(width: 5),
                                                                Text(
                                                                  'Cancel',
                                                                  style: GoogleFonts
                                                                      .poppins(
                                                                    fontSize: 10,
                                                                    fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                    color:  Colors
                                                                        .red, // Text color
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
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
                                                      vehicle.vehicletype == "Car"
                                                          ? Icons.directions_car // Car icon
                                                          : vehicle.vehicletype == "Bike"
                                                          ? Icons.directions_bike // Bike icon
                                                          : Icons.directions_transit, // Default for Others
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 0),
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
                                                              padding: const EdgeInsets.only(top: 8.0),
                                                              child: Row(
                                                                children: [
                                                                  Text(
                                                                    'Parking Schedule: ',
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize: 12, // Reduced font size
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    ' ${vehicle.parkingDate}',
                                                                    style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                                  ),
                                                                  const SizedBox(width: 5),
                                                                  Text(
                                                                    vehicle.parkingTime,
                                                                    style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                                  ),
                                                                ],
                                                              ),
                                                            ),

                                                          ],
                                                        ),

                                                        Row(
                                                          children: [
                                                            Text(
                                                              vehicle.sts == 'Schedule' ? 'Prescheduled' : isVendorShortParkingSts(vehicle.sts?.toString()) ? 'Drive-in' : vehicle.sts,
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 12, // Reduced font size
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),


                                                          ],
                                                        ),


                                                        Row(
                                                          mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                          children: [
                                                            Container(
                                                              height: 10,
                                                            ),
                                                            if (vehicle.status ==
                                                                "PARKED")
                                                              Container(
                                                                // height: 50,
                                                                alignment: Alignment
                                                                    .topCenter,


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
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),


            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: FutureBuilder<List<Bookingdata>>(
                    future: fetchBookingData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(

                          children: [
                            const SizedBox(height: 50,),
                            Center(child: Lottie.asset(
                              'assets/carload.json', // Path to your Lottie JSON file
                              width: double.infinity, // Adjust the size
                              height: 200,
                              fit: BoxFit.contain,
                            ),),
                          ],
                        );
                      } else if (snapshot.hasError) {
                        return const Column(
                          children: [
                            SizedBox(height: 150),
                            Text('No vehicle Parked'),
                          ],
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Column(
                          children: [
                            SizedBox(height: 150),
                            Text('No vehicle Parked'),
                          ],
                        );
                      } else {

                        final filteredData = snapshot.data!.where((booking) {
                          // Check if exitvehicledate is null
                          if (booking.exitvehicledate == null) return false;

                          // Parse the exit vehicle date (keep for valid date format only)
                          List<String> exitParts = (booking.exitvehicledate ?? '').split('-');
                          if (exitParts.length != 3) return false; // Skip invalid dates

                          // Check if the vendor ID matches
                          bool isMatchingVendor = booking.Vendorid == widget.vendorId;

                          // Check the status - show all completed, not only today
                          bool isCompleted = booking.status.toUpperCase() == 'COMPLETED';

                          return isMatchingVendor && isCompleted;
                        }).toList();
                      // Debugging: print final filtered data
                        print('Filtered Data: $filteredData');


                        // If no filtered data, show message
                        if (filteredData.isEmpty) {
                          return const Column(
                            children: [
                              SizedBox(height: 150),
                              Text('No Car Parked'),
                            ],
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                          child: ListView.builder(
                            itemCount: filteredData.length,
                            itemBuilder: (context, index) {
                              final vehicle = filteredData[index];
                              // Use subscription UI from vendorsubscriptonbooking.dart if booking is Subscription
                              if (isSubscriptionSts(vehicle.sts?.toString())) {
                                return vendsubright(vehicle: vehicle);
                              }
                              // Otherwise use regular UI
                              return userdashright(vehicle: vehicle);
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),


      ],
    );
  }

  Widget _buildPendingTab() {
    // Similar to _buildApprovedTab, implement the pending tab logic here
    return  Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: SizedBox(
                height: 30,
                child: CustomSlidingSegmentedControl<int>(
                  initialValue: selectedtSegment,
                  children: {
                    0: Text("Today", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                    1: Text("All", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                    2: Text("Cancelled", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)), // Changed key to 2
                  },
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  thumbDecoration: BoxDecoration(
                    color: ColorUtils.primarycolor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  onValueChanged: (value) {
                    setState(() {
                      selectedtSegment = value;
                    });
                    refreshBookingData();
                  },
                ),
              ),
            ),
          ),
        ),
        Flexible(
    child: IndexedStack(
    index: selectedtSegment,
    children: [
      SizedBox(
        height: 500,
        child: Center(
          child: FutureBuilder<List<Bookingdata>>(
            future: fetchBookingData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Image.asset('assets/gifload.gif'),
                  ),
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text('No Parking Request Pending'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No Parking Request Pending'));
              } else {
                // Filter the data to include only "Pending" and "PENDING" statuses (all dates)
                final filteredData = snapshot.data!.where((booking) {
                  return booking.Vendorid == widget.vendorId &&
                      (booking.status == 'Pending' || booking.status == 'PENDING');
                }).toList();

                if (filteredData.isEmpty) {
                  return const Center(child: Text('No Parking Request Pending'));
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                  child: ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredData[index];

                      // Add space before the first item


                      // For other items, use the regular container without the extra padding
                      return  SizedBox(
                        height: 120,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 30,
                              right: 0,
                              child: Container(
                                height: 85,
                                decoration: BoxDecoration(
                                  color: ColorUtils.primarycolor(),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(30),
                                    bottomRight: Radius.circular(30),
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
                                alignment:
                                Alignment.bottomCenter, // Center the text
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      5.0), // Added padding for better spacing
                                  child: Text(
                                    ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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







                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 5.0),
                                              child: SizedBox(
                                                height: 25,
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 8.0),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      // Get current date and time
                                                      DateTime now = DateTime.now();
                                                      String approvedDate = DateFormat('dd-MM-yyyy').format(now);
                                                      String approvedTime = DateFormat('hh:mm a').format(now); // Formats as 10:30 AM

                                                      await updateBookingStatus(vehicle.id, 'Approved', approvedDate, approvedTime);
                                                      setState(() {}); // Refresh the UI
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: Colors
                                                          .white, // Transparent background
                                                      foregroundColor: Colors
                                                          .red, // Text & Icon color
                                                      padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          10,
                                                          vertical: 5),
                                                      minimumSize:
                                                      const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        const BorderRadius
                                                            .all(Radius
                                                            .circular(
                                                            5)),
                                                        side:
                                                        BorderSide(
                                                          color: ColorUtils.primarycolor(), // Border color
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                      MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .check_circle_outline,
                                                          color: ColorUtils.primarycolor(), // Icon color
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Approve',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color:  ColorUtils.primarycolor(), // Text color
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 5.0),
                                              child: SizedBox(
                                                height: 25,
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 8.0),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      await updatecancel(vehicle.id, 'Cancelled');
                                                      setState(() {}); // Refresh the UI.
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: Colors
                                                          .white, // Transparent background
                                                      foregroundColor: Colors
                                                          .red, // Text & Icon color
                                                      padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          10,
                                                          vertical: 5),
                                                      minimumSize:
                                                      const Size(0, 0),
                                                      shape: const RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius
                                                            .all(Radius
                                                            .circular(
                                                            5)),
                                                        side:
                                                        BorderSide(
                                                          color:  Colors
                                                              .red, // Border color
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
                                                          color:  Colors
                                                              .red, // Icon color
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Cancel',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color:  Colors
                                                                .red, // Text color
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
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
                                              vehicle.vehicletype == "Car"
                                                  ? Icons.directions_car // Car icon
                                                  : vehicle.vehicletype == "Bike"
                                                  ? Icons.directions_bike // Bike icon
                                                  : Icons.directions_transit, // Default for Others
                                              size: 20,
                                              color: Colors.white,
                                            ),

                                          ),
                                          const SizedBox(height: 0),
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
                                                      padding: const EdgeInsets.only(top: 8.0),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            'Parking Schedule: ',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12, // Reduced font size
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            ' ${vehicle.parkingDate}',
                                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            vehicle.parkingTime,
                                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  ],
                                                ),

                                                Row(
                                                  children: [
                                                    Text(
                                                      vehicle.sts == 'Schedule' ? 'Prescheduled' : isVendorShortParkingSts(vehicle.sts?.toString()) ? 'Drive-in' : vehicle.sts,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12, // Reduced font size
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),


                                                  ],
                                                ),


                                                Row(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .start,
                                                  children: [
                                                    Container(
                                                      height: 10,
                                                    ),
                                                    if (vehicle.status ==
                                                        "PARKED")
                                                      Container(
                                                        // height: 50,
                                                        alignment: Alignment
                                                            .topCenter,


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
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
      SizedBox(
        height: 500,
        child: Center(
          child: FutureBuilder<List<Bookingdata>>(
            future: fetchBookingData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Image.asset('assets/gifload.gif',),
                  ),
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text('No Parking Request Pending'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No Parking Request Pending'));
              } else {
                // Filter the data to include only "Pending" and "PENDING" statuses
                final filteredData = snapshot.data!
                    .where((booking) {
                  return booking.Vendorid == widget.vendorId &&
                      (booking.status == 'Pending' || booking.status == 'PENDING');
                })
                    .toList();

                if (filteredData.isEmpty) {
                  return const Center(child: Text('No Parking Request Pending'));
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                  child: ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredData[index];

                      // Add space before the first item


                      // For other items, use the regular container without the extra padding
                      return  SizedBox(
                        height: 120,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 30,
                              right: 0,
                              child: Container(
                                height: 85,
                                decoration: BoxDecoration(
                                  color: ColorUtils.primarycolor(),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(30),
                                    bottomRight: Radius.circular(30),
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
                                alignment:
                                Alignment.bottomCenter, // Center the text
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      5.0), // Added padding for better spacing
                                  child: Text(
                                    ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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







                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 5.0),
                                              child: SizedBox(
                                                height: 25,
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 8.0),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      // Get current date and time
                                                      DateTime now = DateTime.now();
                                                      String approvedDate = DateFormat('dd-MM-yyyy').format(now);
                                                      String approvedTime = DateFormat('hh:mm a').format(now); // Formats as 10:30 AM

                                                      await updateBookingStatus(vehicle.id, 'Approved', approvedDate, approvedTime);
                                                      setState(() {}); // Refresh the UI
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: Colors
                                                          .white, // Transparent background
                                                      foregroundColor: Colors
                                                          .red, // Text & Icon color
                                                      padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          10,
                                                          vertical: 5),
                                                      minimumSize:
                                                      const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        const BorderRadius
                                                            .all(Radius
                                                            .circular(
                                                            5)),
                                                        side:
                                                        BorderSide(
                                                          color: ColorUtils.primarycolor(), // Border color
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                      MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .check_circle_outline,
                                                          color: ColorUtils.primarycolor(), // Icon color
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Approve',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color:  ColorUtils.primarycolor(), // Text color
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 5.0),
                                              child: SizedBox(
                                                height: 25,
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      right: 8.0),
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      await updatecancel(vehicle.id, 'Cancelled');
                                                      setState(() {}); // Refresh the UI.
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: Colors
                                                          .white, // Transparent background
                                                      foregroundColor: Colors
                                                          .red, // Text & Icon color
                                                      padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          10,
                                                          vertical: 5),
                                                      minimumSize:
                                                      const Size(0, 0),
                                                      shape: const RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius
                                                            .all(Radius
                                                            .circular(
                                                            5)),
                                                        side:
                                                        BorderSide(
                                                          color:  Colors
                                                              .red, // Border color
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
                                                          color:  Colors
                                                              .red, // Icon color
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Cancel',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color:  Colors
                                                                .red, // Text color
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
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
                                              vehicle.vehicletype == "Car"
                                                  ? Icons.directions_car // Car icon
                                                  : vehicle.vehicletype == "Bike"
                                                  ? Icons.directions_bike // Bike icon
                                                  : Icons.directions_transit, // Default for Others
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 0),
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
                                                      padding: const EdgeInsets.only(top: 8.0),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            'Parking Schedule: ',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 12, // Reduced font size
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            ' ${vehicle.parkingDate}',
                                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            vehicle.parkingTime,
                                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  ],
                                                ),

                                                Row(
                                                  children: [
                                                    Text(
                                                      vehicle.sts == 'Schedule' ? 'Prescheduled' : isVendorShortParkingSts(vehicle.sts?.toString()) ? 'Drive-in' : vehicle.sts,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12, // Reduced font size
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),


                                                  ],
                                                ),


                                                Row(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .start,
                                                  children: [
                                                    Container(
                                                      height: 10,
                                                    ),
                                                    if (vehicle.status ==
                                                        "PARKED")
                                                      Container(
                                                        // height: 50,
                                                        alignment: Alignment
                                                            .topCenter,


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
                      );
                    },
                  ),
                );
              }
            },
          ),


        ),
      ),

      SizedBox(
        height: 500,
        child: Center(
          child: FutureBuilder<List<Bookingdata>>(
            future: fetchBookingData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50.0), // Adjust padding as needed
                    child: Image.asset('assets/gifload.gif'),
                  ),
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text('Nothing Cancelled'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nothing Cancelled'));
              } else {
                // Show all cancelled bookings (all dates)
                final filteredData = snapshot.data!
                    .where((booking) {
                  return booking.Vendorid == widget.vendorId &&
                      (booking.vehicletype == 'Car' || booking.vehicletype == 'Others' || booking.vehicletype == 'Bike') &&
                      booking.status == 'Cancelled';
                }).toList();

                // Filter the data based on the selected date


                // Show "No data available" if no data matches the filter
                if (filteredData.isEmpty) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [


                      Center(child: Text('Nothing Cancelled')),
                    ],
                  );
                }

                // If filtered data is not empty, display the list
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                  child: Column(
                    children: [

                      const SizedBox(height: 10), // Add spacing
                      // ListView for displaying the filtered bookings
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredData[index];
                            return SizedBox(
                              height: 120,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 30,
                                    right: 0,
                                    child: Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: vehicle.status == 'PARKED'
                                            ? Colors.red
                                            : Colors.red,
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(30),
                                          bottomRight: Radius.circular(30),
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
                                      alignment:
                                      Alignment.bottomCenter, // Center the text
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                            5.0), // Added padding for better spacing
                                        child: Text(
                                          ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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
                                                    vehicle.vehicletype == "Car"
                                                        ? Icons.directions_car // Car icon
                                                        : vehicle.vehicletype == "Bike"
                                                        ? Icons.directions_bike // Bike icon
                                                        : Icons.directions_transit, // Default for Others
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 0),
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
                                                            padding: const EdgeInsets.only(top: 8.0),
                                                            child: Row(
                                                              children: [


                                                                const SizedBox(width: 0),
                                                                Text(
                                                                  'Booked on: ${vehicle.bookingDate} ${vehicle.bookingTime}',
                                                                  style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                        ],
                                                      ),
                                                      Row(
                                                        children: [

                                                          Text(
                                                            vehicle.sts == 'Schedule' ? 'Prescheduled' : isVendorShortParkingSts(vehicle.sts?.toString()) ? 'Drive-in' : vehicle.sts,
                                                            style:  GoogleFonts.poppins(
                                                              fontSize: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),



                                                      Row(
                                                        mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .start,
                                                        children: [
                                                          Container(
                                                            height: 10,
                                                          ),

                                                          Container(
                                                            // height: 50,
                                                            alignment: Alignment
                                                                .topCenter,


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
                            );


                            //   Padding(
                            //   padding: const EdgeInsets.only(bottom: 5.0),
                            //   child: Container(
                            //     decoration: BoxDecoration(
                            //       // border: Border.all(
                            //       //   color: vehicle.status == 'Cancelled'
                            //       //       ? Colors.red
                            //       //       : ColorUtils.primarycolor(),
                            //       // ),
                            //       borderRadius: BorderRadius.circular(5),
                            //       color: ColorUtils.secondarycolor(),
                            //     ),
                            //     child: Column(
                            //       crossAxisAlignment: CrossAxisAlignment.start,
                            //       children: [
                            //         Container(
                            //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            //           decoration: BoxDecoration(
                            //             borderRadius: const BorderRadius.only(
                            //               topLeft: Radius.circular(5.0),
                            //               topRight: Radius.circular(5.0),
                            //             ),
                            //             color: vehicle.status == 'Cancelled'
                            //                 ? Colors.red
                            //                 : ColorUtils.primarycolor(),
                            //           ),
                            //           alignment: Alignment.topLeft,
                            //           child: Text(
                            //             vehicle.vehicleNumber,
                            //             style:  GoogleFonts.poppins(
                            //               fontWeight: FontWeight.bold,
                            //               fontSize: 20,
                            //               color: Colors.white,
                            //             ),
                            //           ),
                            //         ),
                            //         const SizedBox(height: 5),
                            //         Row(
                            //           crossAxisAlignment: CrossAxisAlignment.start,
                            //           children: [
                            //             const SizedBox(width: 15),
                            //             CircleAvatar(
                            //               radius: 25,
                            //               backgroundColor: vehicle.status == 'Cancelled'
                            //                   ? Colors.red
                            //                   : ColorUtils.primarycolor(),
                            //               child: Icon(
                            //                 vehicle.vehicletype == 'Car'
                            //                     ? Icons.directions_car_filled
                            //                     : vehicle.vehicletype == 'Bike'
                            //                     ? Icons.motorcycle
                            //                     : Icons.directions_transit, // Default for other types
                            //                 color: Colors.white,
                            //               ),
                            //             ),
                            //
                            //             const SizedBox(width: 10),
                            //             Expanded(
                            //               child: Column(
                            //                 crossAxisAlignment: CrossAxisAlignment.start,
                            //                 children: [
                            //                   const SizedBox(height: 2),
                            //                   Text(
                            //                     'Booked on: ${vehicle.bookingDate} ${vehicle.bookingTime}',
                            //                     style:  GoogleFonts.poppins(
                            //                       fontSize: 14,
                            //                       color: Colors.grey[600],
                            //                     ),
                            //                   ),
                            //                   Text(
                            //                     vehicle.sts == 'Schedule' ? 'Prescheduled' : isVendorShortParkingSts(vehicle.sts?.toString()) ? 'Drive-in' : vehicle.sts,
                            //                     style:  GoogleFonts.poppins(
                            //                       fontSize: 14,
                            //                       color: Colors.grey[600],
                            //                     ),
                            //                   ),
                            //                   const SizedBox(height: 5),
                            //                   Row(
                            //                     children: [
                            //
                            //                       const Spacer(),
                            //                       Container(
                            //                         height: 30,
                            //                         width: 100,
                            //                         decoration: BoxDecoration(
                            //                           color: vehicle.status == 'Cancelled'
                            //                               ? Colors.red
                            //                               : ColorUtils.primarycolor(),
                            //                           borderRadius: const BorderRadius.only(
                            //                             bottomRight: Radius.circular(5),
                            //                           ),
                            //                         ),
                            //                         child: Center(
                            //                           child: Text(
                            //                             vehicle.status,
                            //                             style:  GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                            //                           ),
                            //                         ),
                            //                       ),
                            //                     ],
                            //                   ),
                            //                 ],
                            //               ),
                            //             ),
                            //           ],
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            // );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
        ],),


        ),],
    ); // Placeholder for pending tab
  }


}

class userdashleft extends StatelessWidget {
  final Bookingdata vehicle;
  final VoidCallback? onRefresh; // Add callback parameter

  const userdashleft({super.key, required this.vehicle, this.onRefresh});

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // Calculate remaining days for subscription bookings (same logic as vendorsubleft)
  String _calculateRemainingDaysMessage(
      String parkedDate, String? subscriptionEndDate, String status, String vehicleNumber) {
    try {
      DateTime _parseDate(String dateStr) {
        dateStr = dateStr.trim();
        final normalized = dateStr.replaceAll('/', '-');
        if (normalized.contains('-')) {
          final parts = normalized.split('-');
          if (parts.length >= 3) {
            if (parts[0].length == 4) {
              return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            } else {
              return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          }
        }
        throw FormatException('Unable to parse date: $dateStr');
      }

      final DateTime subscriptionStartDate = _parseDate(parkedDate);

      DateTime subscriptionEndDateParsed;
      if (subscriptionEndDate != null && subscriptionEndDate.isNotEmpty) {
        final String endDateStr = subscriptionEndDate.trim().split(' ')[0];
        subscriptionEndDateParsed = _parseDate(endDateStr);
      } else {
        subscriptionEndDateParsed = subscriptionStartDate.add(const Duration(days: 30));
      }

      final DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final DateTime startOnly = DateTime(subscriptionStartDate.year, subscriptionStartDate.month, subscriptionStartDate.day);
      final DateTime endOnly = DateTime(subscriptionEndDateParsed.year, subscriptionEndDateParsed.month, subscriptionEndDateParsed.day);

      String remainingDaysMessage;

      if (todayOnly.isAfter(endOnly)) {
        remainingDaysMessage = "Expired";
      } else if (todayOnly.isBefore(startOnly)) {
        // Not started yet: show full subscription period (end - start)
        int remainingDays = endOnly.difference(startOnly).inDays;
        remainingDaysMessage = remainingDays == 1 ? "1 day left" : "$remainingDays days left";
      } else {
        // Started (today >= parked date): show remaining days (end - today - 1)
        // Subtract 1 because parked date is day 0, so remaining = end - today - 1
        int remainingDays = endOnly.difference(todayOnly).inDays;
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

      return remainingDaysMessage;
    } catch (e) {
      print('Error calculating remaining days for Vehicle: $vehicleNumber - $e');
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedPayableDuration = vehicle.payableDuration != null
        ? _formatDuration(vehicle.payableDuration)
        : 'N/A';
    final String parkingDate = vehicle.parkingDate;
    final String parkingTime = vehicle.parkingTime;
    final String bookedDate = vehicle.bookingDate;
    final String bookedTime = vehicle.bookingTime;

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom = combinebook != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
        : 'N/A';

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime = combinedDateTime != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
        : 'N/A';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate,
              parkedtime: vehicle.parkedtime,
              subscriptionenddate:vehicle.subscriptionenddate,
              exitdate:vehicle.exitvehicledate,
              exittime:vehicle.exitvehicletime,
              invoiceid: vehicle.invoiceid,
              totalamount: vehicle.totalamout,
              amount: vehicle.amount,
              username: vehicle.username,
                invoice: vehicle.invoice,
              mobilenumber: vehicle.mobilenumber,
              sts: vehicle.sts,
              bookingtype: vehicle.bookingtype,
              vehiclenumber: vehicle.vehicleNumber,
              vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid,
              parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime,
              bookedid: vehicle.id,
              bookeddate: formattedDateTime,
              schedule: bookcom,
              otp: vehicle.otp,
              status: vehicle.status,
              vehicletype: vehicle.vehicletype,
            ),
          ),
        );
      },
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              child: Container(
                height: 85,
                decoration: BoxDecoration(
                  color: vehicle.status == 'PARKED'
                      ? ColorUtils.primarycolor()
                      : ColorUtils.primarycolor(),
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
                    ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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
                          color: vehicle.status == 'Cancelled'
                              ? Colors.white
                              : Colors.white,
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
                            if (vehicle.status == "Cancelled")
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.cancelledStatus}",
                                  style: GoogleFonts.poppins(
                                      color: vehicle.status == 'Cancelled'
                                          ? Colors.red
                                          : ColorUtils.primarycolor(),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (vehicle.status.toUpperCase() == "PARKED")
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5.0),
                                child: SizedBox(
                                  height: 25,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
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
                                                        top: Radius.circular(20)),
                                                  ),
                                                  child: Exipage(
                                                    vendorname: vehicle.vendorname,
                                                    userid: "",
                                                    otp: vehicle.otp,
                                                    vehicletype: vehicle.vehicletype,
                                                    bookingid: vehicle.id,
                                                    parkingdate: vehicle.parkingDate,
                                                    vehiclenumber: vehicle.vehicleNumber,
                                                    username: vehicle.username,
                                                    phoneno: vehicle.mobilenumber,
                                                    parkingtime: vehicle.parkingTime,
                                                    bookingtypetemporary: vehicle.status,
                                                    sts: vehicle.sts,
                                                    cartype: vehicle.Cartype,
                                                    vendorid: vehicle.Vendorid,
                                                    bookType: vehicle.bookType,

                                                    onRefresh: onRefresh,// Pass the callback
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        minimumSize: const Size(0, 0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          const BorderRadius.all(Radius.circular(5)),
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
                                            Icons.qr_code_scanner,
                                            color: ColorUtils.primarycolor(),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Exit',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: ColorUtils.primarycolor(),
                                            ),
                                          ),
                                        ],
                                      ),
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
                              vehicle.vehicletype == "Car"
                                  ? Icons.directions_car
                                  : vehicle.vehicletype == "Bike"
                                  ? Icons.directions_bike
                                  : Icons.directions_transit,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 0),
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
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking Schedule: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(fontSize: 12),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // For subscription bookings, show "Remaining: X days left"
                                    // For regular bookings, show "Payable Time: duration"
                                    if (isSubscriptionSts(vehicle.sts?.toString()))
                                      ...[
                                        Text(
                                          'Remaining :',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          ' ${_calculateRemainingDaysMessage(vehicle.parkeddate, vehicle.subscriptionenddate, vehicle.status, vehicle.vehicleNumber)}',
                                          style: GoogleFonts.poppins(color: ColorUtils.primarycolor()),
                                        ),
                                      ]
                                    else
                                      ...[
                                        Text(
                                          'Payable Time:',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(" $formattedPayableDuration"),
                                      ],
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(height: 10),
                                    if (vehicle.status == "PARKED")
                                      Container(alignment: Alignment.topCenter),
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
  }
}

class Exipage extends StatefulWidget {
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
  final String vendorname;
  final VoidCallback? onRefresh;

  const Exipage({super.key,
    required this.bookingid,
    required this.otp,
    required this.vendorname,
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
    this.onRefresh,
  });

  @override
  _ExitpagesState createState() => _ExitpagesState();
}

class _ExitpagesState extends State<Exipage> {
  int selectedTabIndex = 0;
  DateTime selectedDateTime = DateTime.now();  // Initialize with the current date and time
  late final Timer _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  List<Exitcharge> parkingCharges = [];  // Store the fetched parking charges
  final TextEditingController _otpController = TextEditingController();
  double payableAmount = 0.0;
  bool isLoading = true;
  String fullDayChargeType = 'Full Day';
  bool isOtpEntered = false;
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double totalAmountWithTaxes = 0.0;
  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    fetchGstData().then((gstData) {
      if (mounted) {
        setState(() {
          gstPercentage = double.tryParse(gstData['gst'] ?? '0') ?? 0.0;
          handlingFee = double.tryParse(gstData['handlingfee'] ?? '0') ?? 0.0;
        });
      }
    }).then((_) {
      // Then fetch other data
      _initializeTimerAndData();
    });
    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });

    // Fetch Parking Charges and Bookings Data
    fetchParkingCharges(widget.vendorid,widget.vehicletype).then((charges) {
      if (mounted) {
        setState(() {
          parkingCharges = charges;
          isLoading = false;// Assign the charges to the list
        });
        print("Parking Charges Assigned: $parkingCharges"); // Debugging
      }
    });

    fetchBookingData().then((data) {
      if (mounted) {
        setState(() {
          bookingDataNotifier.value = data;
          isLoading = false;
        });
        updatePayableTimes(); // Call update once data is fetched
      }
    });
  }
  void _initializeTimerAndData() {
    // Only initialize timer if it hasn't been initialized yet
    if (!_payableTimer.isActive) {
      _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          updatePayableTimes();
        }
      });
    }

    fetchParkingCharges(widget.vendorid, widget.vehicletype).then((charges) {
      if (mounted) {
        setState(() {
          parkingCharges = charges;
          isLoading = false;
        });
      }
    });

    fetchBookingData().then((data) {
      if (mounted) {
        setState(() {
          bookingDataNotifier.value = data;
          isLoading = false;
        });
        updatePayableTimes();
      }
    });
  }
  // Modify this function to calculate payable amount based on parking charges
  Future<List<Exitcharge>> fetchParkingCharges(String vendorId, String vehicleType) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/charges/$vendorId/$vehicleType');
    print('Fetching parking charges from URL: $url'); // Print the URL being called
    try {
      final response = await http.get(url);
      print('Response status: ${response.statusCode}'); // Print the response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print the response data

        final chargesData = data['transformedData'] ?? [];
        fullDayChargeType = data['fullDayCharge'] ?? 'FullDay';
        print('Full day charge type: $fullDayChargeType'); // Print the full day charge type

        // Map the charges data to Exitcharge objects
        List<Exitcharge> charges = chargesData.map<Exitcharge>((item) => Exitcharge.fromJson(item)).toList();
        print('Fetched charges: $charges'); // Print the fetched charges
        return charges;
      } else {
        print('Failed to fetch parking charges, status code: ${response.statusCode}'); // Print error status
        throw Exception('Failed to fetch parking charges');
      }
    } catch (e) {
      print('Error fetching charges: $e'); // Print any errors that occur
      return [];
    }
  }

  double calculatePayableAmount(Duration duration, String bookingType, String parkedDate, String parkedTime) {
    print("Calculating payable amount for duration: ${duration.inHours} hours for booking type: $bookingType");

    String bookingTypeLower = bookingType.toLowerCase();

    if (bookingTypeLower == 'hourly') {
      return calculateHourly(parkingCharges.map((e) => e.toJson()).toList(), duration);
    } else if (bookingTypeLower == '24 hours' ) {
      double fullDayChargeAmount = calculateFullDay(
        parkingCharges.map((e) => e.toJson()).toList(),
        duration,
        parkedDate,
        parkedTime,
        bookingTypeLower, // Pass booking type to determine calculation logic
      );
      print("Using full day amount: $fullDayChargeAmount");
      return fullDayChargeAmount;
    } else {
      print("Unknown booking type, returning 0");
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
      if (booking.status == 'PARKED') {
        final parkingTime = parseParkingDateTime(
          "${booking.parkeddate} ${booking.parkedtime}",
        );
        final elapsed = now.difference(parkingTime);

        // Update the payable duration
        booking.payableDuration = elapsed;

        // Calculate the payable amount using updated calculation
        double payableAmount = calculatePayableAmount(
          elapsed,
          booking.bookType,
          booking.parkeddate,
          booking.parkedtime,
        );

        print("Booking ID: ${booking.id}, Elapsed Time: $elapsed, Payable Amount: $payableAmount");
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
// Helper function to round up to nearest rupee
  double roundUpToNearestRupee(double amount) {
    return amount.ceilToDouble();
  }
  double calculateTotalWithTaxes(double payableAmount) {
    // Use original values for amount and handling fee
    double parkingCharge = payableAmount;
    double handlingFeeAmount = handlingFee;

    // GST base = amount + handling fee
    double gstBase = parkingCharge + handlingFeeAmount;
    double gstAmount = (gstBase * gstPercentage) / 100;

    // Exact total before rounding
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;

    // Round off only the final payable amount
    double roundedTotal = roundUpToNearestRupee(exactTotal);

    totalAmountWithTaxes = roundedTotal;
    return roundedTotal;
  }

  Future<void> updateExitData(String bookingId, Duration totalDuration, String formattedDuration, double totalAmount) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId');
    try {
      // Use original payable amount as parking charge
      double parkingCharge = totalAmount;

      // Construct the base request body
      Map<String, dynamic> requestBody = {
        'amount': parkingCharge,
        'hour': formattedDuration,
      };

      // Conditionally add GST and handling fee (no rounding on individual components)
      if (widget.userid.isNotEmpty) {
        double handlingFeeAmount = handlingFee;
        double gstBase = parkingCharge + handlingFeeAmount;
        double gstAmount = (gstBase * gstPercentage) / 100;

        // Exact total and rounded payable total
        double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
        double finalTotal = roundUpToNearestRupee(exactTotal);

        requestBody['gstamout'] = gstAmount;
        requestBody['handlingfee'] = handlingFeeAmount;
        requestBody['totalamout'] = finalTotal;
        requestBody['paymentMode'] = 'Online';
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        // Fetch fresh booking data
        final freshData = await fetchBookingData();
        if (mounted) {
          setState(() {
            bookingDataNotifier.value = freshData;
          });
        }
        // Notify parent widget to refresh
        widget.onRefresh?.call();
        // Close the bottom sheet
        Navigator.pop(context);
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exit successful!')),
        );
      } else {
        throw Exception('Failed to update booking: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating exit data: $e')),
      );
    }
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
  void dispose() {
    _payableTimer.cancel();
    // _controller.dispose();
    bookingDataNotifier.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return isLoading
        ? const LoadingGif()
        : Scaffold(
      // appBar: AppBar(
      //   backgroundColor: ColorUtils.secondarycolor(),
      //   titleSpacing: 0,
      //   title: Text(
      //     "Exit",
      //     style: GoogleFonts.poppins(),
      //   ),
      // ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.02,
            ),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Text(widget.otp),
// Text(widget.bookType,),
                  // Circular Progress Indicator with Gradient and Ticks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // This will space children equally
                    crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
                    children: [
                      // First widget (the Stack with CircularProgressIndicator)
                      Flexible(
                        flex: 1, // Equal flex
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.02),
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
                                          subscriptionenddate: "",
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
                                          parkedtime: '', bookType: '', otp: '', userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
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
                                  Text(
                                    'Time left',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Second widget (the details container)
                      Flexible(
                        flex: 1, // Equal flex
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.01),
                          child: Container(
                            child: Padding(
                              padding: EdgeInsets.all(screenWidth * 0.01),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Parked IN: ${widget.parkingdate ?? ''} ${widget.parkingtime ?? ''}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 9 * textScaleFactor,
                                    ),
                                  ),
                                  const Divider(),
                                  SizedBox(height: screenHeight * 0.001),
                                  Text(
                                    "Name: ${widget.username ?? ''}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  const Divider(),
                                  Text(
                                    "Booking Type: ${widget.sts ?? ''}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  const Divider(),
                                  Text(
                                    "Booked by: ${widget.userid.isEmpty ? 'Vendor' : 'Customer'}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 10 * textScaleFactor,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.001),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    "Vehicle No: ${widget.vehiclenumber}",
                    style: GoogleFonts.poppins(
                      fontSize: 14 * textScaleFactor,
                      color: ColorUtils.primarycolor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),


                  // Container(
                  //   // margin: EdgeInsets.only(left: screenWidth * 0.01),
                  //   color: Colors.white,
                  //   child: ListTile(
                  //     title: ValueListenableBuilder<List<Bookingdata>>(
                  //       valueListenable: bookingDataNotifier,
                  //       builder: (context, bookingData, child) {
                  //         final booking = bookingData.firstWhere(
                  //               (booking) => booking.id == widget.bookingid,
                  //           orElse: () => Bookingdata(
                  //             bookingtype: "",
                  //             vendorname: "",
                  //             username: '',
                  //             mobilenumber: '',
                  //             id: '',
                  //             vehicleNumber: '',
                  //             bookingDate: '',
                  //             bookingTime: '',
                  //             status: '',
                  //             vehicletype: '',
                  //             Cartype: '',
                  //             Amount: '',
                  //             Hour: '',
                  //             Vendorid: '',
                  //             sts: '',
                  //             payableDuration: Duration.zero,
                  //             subscriptiontype: '',
                  //             parkingTime: '',
                  //             parkingDate: '',
                  //             Approvedate: '',
                  //             Approvedtime: '',
                  //             parkeddate: '',
                  //             parkedtime: '',
                  //             bookType: '',
                  //             otp: '',
                  //             userid: '',
                  //           ),
                  //         );
                  //
                  //         if (booking.id.isEmpty) {
                  //           return Center(
                  //             child: Text(
                  //               "Fetching..",
                  //               style: GoogleFonts.poppins(
                  //                 color: Colors.black,
                  //                 fontSize: 14 * textScaleFactor,
                  //               ),
                  //             ),
                  //           );
                  //         }
                  //
                  //         double payableAmount = calculatePayableAmount(
                  //           booking.payableDuration,
                  //           booking.bookType,
                  //           booking.parkeddate,
                  //           booking.parkedtime,
                  //         );
                  //
                  //         return Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Row(
                  //               children: [
                  //                 Text(
                  //                   'Booking ID:',
                  //                   style: GoogleFonts.poppins(
                  //                     color: Colors.black,
                  //                     fontSize: 12 * textScaleFactor,
                  //                     fontWeight: FontWeight.bold,
                  //                   ),
                  //                 ),
                  //                 Spacer(),
                  //                 Text(
                  //                   ' ${booking.id.length > 6 ? booking.id.substring(booking.id.length - 6) : booking.id}',
                  //                   style: GoogleFonts.poppins(
                  //                     color: Colors.black,
                  //                     fontSize: 12 * textScaleFactor,
                  //                     fontWeight: FontWeight.bold,
                  //                   ),
                  //                 ),
                  //               ],
                  //             ),
                  //             Row(
                  //               children: [
                  //                 Text(
                  //                   'Payable Amount: ',
                  //                   style: GoogleFonts.poppins(
                  //                     color: Colors.black,
                  //                     fontSize: 14 * textScaleFactor,
                  //                     fontWeight: FontWeight.bold,
                  //                   ),
                  //                 ),
                  //                 Spacer(),
                  //                 Text(
                  //                   '₹${payableAmount.toStringAsFixed(2)}',
                  //                   style: GoogleFonts.poppins(
                  //                     color: Colors.black,
                  //                     fontSize: 14 * textScaleFactor,
                  //                     fontWeight: FontWeight.bold,
                  //                   ),
                  //                 ),
                  //               ],
                  //             ),
                  //           ],
                  //         );
                  //       },
                  //     ),
                  //   ),
                  // ),
                  SizedBox(height: screenHeight * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Booking ID:",
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
                              subscriptionenddate: "",
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
                              userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
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
                          );

                          return  Text(
                            ' ${booking.id.length > 8 ? booking.id.substring(booking.id.length - 8) : booking.id}',
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 12 * textScaleFactor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const Divider(),
                  // Replace the GST, Handling Fee, and Total Amount sections with this
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Payable Amount:",
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
                              subscriptionenddate: "",
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
                              userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
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
                          );
                          double roundedAmount = roundUpToNearestRupee(payableAmount);


                          return Text(
                            "₹${roundedAmount.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 12 * textScaleFactor,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const Divider(),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

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
                                parkedtime: '', bookType: '', otp: '', userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                                // Your default booking data
                              ),
                            );

                            if (booking.id.isEmpty) return const Text("Calculating...");

                            double payableAmount = calculatePayableAmount(
                              booking.payableDuration,
                              booking.bookType,
                              booking.parkeddate,
                              booking.parkedtime,
                            );
                            double roundedBaseAmount = roundUpToNearestRupee(payableAmount);
                            double roundedGst = roundUpToNearestRupee((roundedBaseAmount * gstPercentage) / 100);
                            double gstAmount = (payableAmount * gstPercentage) / 100;

                            return Text(
                              "₹${roundedGst.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                fontSize: 12 * textScaleFactor,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const Divider(),

                    // Total Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount:",
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
                                parkedtime: '', bookType: '', otp: '', userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                                // Your default booking data
                              ),
                            );

                            if (booking.id.isEmpty) return const Text("Calculating...");

                            double payableAmount = calculatePayableAmount(
                              booking.payableDuration,
                              booking.bookType,
                              booking.parkeddate,
                              booking.parkedtime,
                            );
                            double total = calculateTotalWithTaxes(payableAmount);

                            return Text(
                              "₹${total.toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(
                                fontSize: 14 * textScaleFactor,
                                color: ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),

                        // if (widget.userid.isNotEmpty)
                        // Pinput(
                        //   controller: _otpController,
                        //   length: 3,
                        //   mainAxisAlignment: MainAxisAlignment.center,
                        //   defaultPinTheme: PinTheme(
                        //     width: screenWidth * 0.1,
                        //     height: screenWidth * 0.1,
                        //     textStyle: GoogleFonts.poppins(
                        //       fontSize: 20 * textScaleFactor,
                        //       color: Colors.black,
                        //       fontWeight: FontWeight.w600,
                        //     ),
                        //     decoration: BoxDecoration(
                        //       color: Colors.white,
                        //       borderRadius: BorderRadius.circular(8),
                        //       border: Border.all(color: ColorUtils.primarycolor()),
                        //     ),
                        //   ),
                        //   focusedPinTheme: PinTheme(
                        //     width: screenWidth * 0.12,
                        //     height: screenWidth * 0.12,
                        //     textStyle: GoogleFonts.poppins(
                        //       fontSize: 20 * textScaleFactor,
                        //       color: ColorUtils.primarycolor(),
                        //       fontWeight: FontWeight.bold,
                        //     ),
                        //     decoration: BoxDecoration(
                        //       color: Colors.white,
                        //       borderRadius: BorderRadius.circular(8),
                        //       border: Border.all(
                        //         color: ColorUtils.primarycolor(),
                        //         width: 2,
                        //       ),
                        //     ),
                        //   ),
                        //   onCompleted: (otp) {
                        //     setState(() {
                        //       isOtpEntered = true; // Set to true when OTP is entered
                        //     });
                        //     // Optionally, you can also verify the OTP here
                        //   },
                        // ),

                      ],
                    ),
                  ],
                  SizedBox(height: screenHeight * 0.02),
// In your build method, replace the Exit button section with:

                  if (!isLoading) ...[
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SizedBox(
                        height: screenHeight * 0.04,
                        width: screenWidth * 0.2,
                        child: ElevatedButton(
                          onPressed: () {
                            final booking = bookingDataNotifier.value.firstWhere(
                                  (booking) => booking.id == widget.bookingid,
                              orElse: () => Bookingdata(
                                subscriptionenddate: "",
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
                                userid: '', totalamout: '', amount: '', invoice: '', invoiceid: '', exitvehicledate: '', exitvehicletime: '',
                              ),
                            );

                            if (booking.id.isNotEmpty) {
                              double payableAmount = calculatePayableAmount(
                                booking.payableDuration,
                                booking.bookType,
                                booking.parkeddate,
                                booking.parkedtime,
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
                                'Exit',
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
    );
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

class userdashright extends StatelessWidget {

  final Bookingdata vehicle; // Expecting Bookingdata type
  const userdashright({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {

    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom = combinebook != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
        : 'N/A';

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime = combinedDateTime != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
        : 'N/A';
    return GestureDetector(
      onTap: ()
      {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate,
              parkedtime: vehicle.parkedtime,
              subscriptionenddate:vehicle.subscriptionenddate,
              exitdate:vehicle.exitvehicledate,
              exittime:vehicle.exitvehicletime,
              mobilenumber: vehicle.mobilenumber,
              sts:vehicle.sts,
              bookingtype: vehicle.bookingtype,
              otp: vehicle.otp,
              vehiclenumber: vehicle.vehicleNumber,
              vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid,
              parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime,
              bookedid: vehicle.id,
              bookeddate: formattedDateTime,
              schedule: bookcom,
              status: vehicle.status,
              vehicletype: vehicle.vehicletype, username: vehicle.username, amount: vehicle.amount, totalamount: vehicle.totalamout, invoice: vehicle.invoice, invoiceid:  vehicle.invoiceid,
            ),
          ),
        );
      },
      child: SizedBox(
        height: 110,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: vehicle.status == 'PARKED'
                      ? ColorUtils.primarycolor()
                      : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
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
                alignment:
                Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                      5.0), // Added padding for better spacing
                  child: Text(
                    ' ${vehicle.parkingDate}, ${vehicle.parkingTime}',
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
                            if (vehicle.cancelledStatus
                                ?.isEmpty ??
                                true) // Check if cancelledStatus is empty
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                    right: 12.0),
                                child: Text(
                                  " ${vehicle.status}", // Display vehicle status if cancelledStatus is empty
                                  style:
                                  GoogleFonts.poppins(
                                    color: vehicle.status ==
                                        'Cancelled'
                                        ? Colors.red
                                        : ColorUtils
                                        .primarycolor(),
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ),






                            if (vehicle.status == "PARKED")

                            const SizedBox(height: 2),

                          ],
                        ),
                      ),

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
                              vehicle.vehicletype == "Car"
                                  ? Icons.directions_car // Car icon
                                  : vehicle.vehicletype == "Bike"
                                  ? Icons.directions_bike // Bike icon
                                  : Icons.directions_transit, // Default for Others
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 0),
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
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking Schedule: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),

                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '',
                                      style: GoogleFonts
                                          .poppins(
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight
                                              .bold),
                                    ),
                                    Text(' ${vehicle.sts}',),
                                  ],
                                ),



                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment
                                      .start,
                                  children: [
                                    Container(
                                      height: 10,
                                    ),
                                    if (vehicle.status ==
                                        "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment
                                            .topCenter,


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




  }
}

class myspacesubleft extends StatelessWidget {
  final Bookingdata vehicle; // Expecting Bookingdata type
  final VoidCallback? onRefresh; // Added callback for refreshing the parent list
  const myspacesubleft({super.key, required this.vehicle, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // Helper copied to match BlockSpot calculation for exact consistency (inclusive counting)
    String _calculateRemainingDaysMessage(
        String parkedDate, String? subscriptionEndDate, String status, String vehicleNumber) {
      try {
        DateTime _parseDate(String dateStr) {
          dateStr = dateStr.trim();
          final normalized = dateStr.replaceAll('/', '-');
          if (normalized.contains('-')) {
            final parts = normalized.split('-');
            if (parts.length >= 3) {
              if (parts[0].length == 4) {
                return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
              } else {
                return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
          }
          throw FormatException('Unable to parse date: $dateStr');
        }

        final DateTime subscriptionStartDate = _parseDate(parkedDate);

        DateTime subscriptionEndDateParsed;
        if (subscriptionEndDate != null && subscriptionEndDate.isNotEmpty) {
          final String endDateStr = subscriptionEndDate.trim().split(' ')[0];
          subscriptionEndDateParsed = _parseDate(endDateStr);
        } else {
          subscriptionEndDateParsed = subscriptionStartDate.add(const Duration(days: 30));
        }

        final DateTime todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final DateTime startOnly = DateTime(subscriptionStartDate.year, subscriptionStartDate.month, subscriptionStartDate.day);
        final DateTime endOnly = DateTime(subscriptionEndDateParsed.year, subscriptionEndDateParsed.month, subscriptionEndDateParsed.day);

        String remainingDaysMessage;

        if (todayOnly.isAfter(endOnly)) {
          remainingDaysMessage = "Expired";
        } else if (todayOnly.isBefore(startOnly)) {
          // Not started yet: show full subscription period (end - start)
          int remainingDays = endOnly.difference(startOnly).inDays;
          remainingDaysMessage = remainingDays == 1 ? "1 day left" : "$remainingDays days left";
        } else {
          // Started (today >= parked date): show remaining days (end - today - 1)
          // Subtract 1 because parked date is day 0, so remaining = end - today - 1
          int remainingDays = endOnly.difference(todayOnly).inDays;
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

    // Use the same logic as BlockSpot: start = parkeddate, end = subscriptionenddate
    final String remainingDaysMessage = _calculateRemainingDaysMessage(
        vehicle.parkeddate, vehicle.subscriptionenddate, vehicle.status, vehicle.vehicleNumber);
    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'
    String formatWithSuffix(DateTime date) {
      int day = date.day;
      String suffix = "th";
      if (!(day >= 11 && day <= 13)) {
        switch (day % 10) {
          case 1:
            suffix = "st";
            break;
          case 2:
            suffix = "nd";
            break;
          case 3:
            suffix = "rd";
            break;
        }
      }
      String formattedMonthYear = DateFormat("MMMM yyyy").format(date);
      return "$day$suffix $formattedMonthYear";
    }
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(vehicle.parkingDate);
    String formattedDate = formatWithSuffix(parsedDate);

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom = combinebook != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
        : 'N/A';

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime = combinedDateTime != null
        ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
        : 'N/A';
    return GestureDetector(
      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate,
              parkedtime: vehicle.parkedtime,
              subscriptionenddate:vehicle.subscriptionenddate,
              exitdate:vehicle.exitvehicledate,
              exittime:vehicle.exitvehicletime,
              invoiceid: vehicle.invoiceid,
              mobilenumber: vehicle.mobilenumber,
              sts:vehicle.sts,
              bookingtype: vehicle.bookingtype,
              vehiclenumber: vehicle.vehicleNumber,
              vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid,
              parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime,
              bookedid: vehicle.id,
              bookeddate: formattedDateTime,
              schedule: bookcom,
              otp:vehicle.otp,
              status: vehicle.status,
              vehicletype: vehicle.vehicletype, username: vehicle.username, amount: vehicle.amount, totalamount: vehicle.totalamout, invoice: vehicle.invoice,
            ),
          ),
        );
      },
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              child: Container(
                height: 85,
                decoration: BoxDecoration(
                  color: vehicle.status == 'PARKED'
                      ? ColorUtils.primarycolor()
                      : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
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
                alignment:
                Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                      5.0), // Added padding for better spacing
                  child: Text(
                    'Booking on : $formattedDate, ${vehicle.parkingTime}',
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


                            if (vehicle.status.toUpperCase() == "PARKED")
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0, bottom: 5.0),
                                child: SizedBox(
                                  height: 25,
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
                                                  navi: "",
                                                  onRefresh: onRefresh,
                                                  // userid: vehicle.userid,
                                                  userid: "",
                                                  otp: vehicle.otp,
                                                  vehicletype: vehicle.vehicletype,
                                                  bookingid: vehicle.id,
                                                  parkingdate: vehicle.parkingDate,
                                                  vehiclenumber: vehicle.vehicleNumber,
                                                  username: vehicle.username,
                                                  phoneno: vehicle.mobilenumber,
                                                  parkingtime: vehicle.parkingTime,
                                                  bookingtypetemporary: vehicle.status,
                                                  sts: vehicle.sts,
                                                  cartype: vehicle.Cartype,
                                                  vendorid: vehicle.Vendorid,
                                                  parkeddate: vehicle.parkeddate,
                                                  parkedtime: vehicle.parkedtime,
                                                  status: vehicle.status,
                                                  totalamount: vehicle.totalamout,
                                                  newEndDate: null,
                                                  gstfee: "0",
                                                  handlingfee: "0",
                                                  amout: vehicle.amount,
                                                  payableduration: "0",
                                                  venodorname: "Vendor",

                                                  subscriptionEndDate: vehicle.subscriptionenddate,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                      if (result == true && onRefresh != null) {
                                        onRefresh!();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: ColorUtils.primarycolor(),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      minimumSize: const Size(0, 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(5)),
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
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Renew',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: ColorUtils.primarycolor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: SizedBox(
                                height: 25,
                                child: Padding(
                                  padding:
                                  const EdgeInsets.only(
                                      right: 8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
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
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                                ),
                                                child: subexit(
                                                  userid: vehicle.userid,
                                                  otp: vehicle.otp,
                                                  vehicletype: vehicle.vehicletype,
                                                  bookingid: vehicle.id,
                                                  invoiceid: vehicle.invoiceid,
                                                  parkingdate: vehicle.parkingDate,
                                                  vehiclenumber: vehicle.vehicleNumber,
                                                  username: vehicle.username,
                                                  phoneno: vehicle.mobilenumber,
                                                  parkingtime: vehicle.parkingTime,
                                                  bookingtypetemporary: vehicle.status,
                                                  sts: vehicle.sts,
                                                  cartype: vehicle.Cartype,
                                                  vendorid: vehicle.Vendorid,
                                                  parkeddate: vehicle.parkeddate,
                                                  parkedtime: vehicle.parkedtime,
                                                  status: vehicle.status,
                                                  subscriptionenddate: vehicle.subscriptionenddate,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ).then((result) {
                                        // Refresh data when modal closes
                                        print('🔄 Modal closed, refreshing data...');
                                        if (onRefresh != null) {
                                          onRefresh!();
                                        }
                                      });
                                    },
                                    style: ElevatedButton
                                        .styleFrom(
                                      backgroundColor: Colors
                                          .white, // Transparent background
                                      foregroundColor: Colors
                                          .red, // Text & Icon color
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                          10,
                                          vertical: 5),
                                      minimumSize:
                                      const Size(0, 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        const BorderRadius
                                            .all(Radius
                                            .circular(
                                            5)),
                                        side:
                                        BorderSide(
                                          color: ColorUtils.primarycolor(), // Border color
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize:
                                      MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons
                                              .exit_to_app,
                                          color: ColorUtils.primarycolor(), // Icon color
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'complete',
                                          style: GoogleFonts
                                              .poppins(
                                            fontSize: 10,
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                            color:  ColorUtils.primarycolor(), // Text color
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
                              vehicle.vehicletype == "Car"
                                  ? Icons
                                  .drive_eta // Car icon
                                  : Icons
                                  .directions_bike, // Bike icon
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 0),
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
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking Schedule: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(fontSize: 12), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),

                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Remaining :',
                                      style: GoogleFonts
                                          .poppins(
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight
                                              .bold),
                                    ),

                                    Text(
                                      remainingDaysMessage,
                                      style: GoogleFonts.poppins(color: ColorUtils.primarycolor()),
                                    ),
                                  ],
                                ),



                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment
                                      .start,
                                  children: [
                                    Container(
                                      height: 10,
                                    ),
                                    if (vehicle.status ==
                                        "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment
                                            .topCenter,


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


  }
}