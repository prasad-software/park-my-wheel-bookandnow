
import 'dart:async';

import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'package:mywheels/auth/vendor/subscription/addsubscribe.dart';
import 'package:mywheels/auth/vendor/subscription/vendorsubscriptonbooking.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';

import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/vendor/vendorsearch.dart';
import 'package:mywheels/auth/vendor/vendorsubscriptionapply.dart';

import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywheels/utils/sts_utils.dart';
import 'package:pinput/pinput.dart';
import 'package:tab_container/tab_container.dart';

import '../customer/parking/bookparking.dart';
import 'menusscreen.dart';
import 'vendorbottomnav/thirdpage.dart';

class Bookings extends StatefulWidget {
  final String vendorid;
  const Bookings({super.key,
    required this.vendorid,
    // required this.userName
  });

  @override
  State<Bookings> createState() => _BookingsState();
}

class _BookingsState extends State<Bookings> with SingleTickerProviderStateMixin {
  final DateTime _selectedDate = DateTime.now(); // Initialize with today's date
  final TextEditingController _dateController = TextEditingController();
  late final TabController _controller;
  int selectedTabIndex = 0;
  DateTime selectedDateTime = DateTime.now();  // Initialize with the current date and time
  int selectedSegment = 0; // Default selected segment (0 = All Today, 1 = Approved)
  bool _isLoading = true;
  late Future<Map<String, List<Bookingdata>>> _requestsFuture;

  String? _menuImageUrl;

  Vendor? _vendor;

  final int _selectedIndex = 1;
  int _selecteddIndex = 1;
  late List<Widget> _pagess;
  Timer? _timer;
  void _navigateToPage(int index) {
    setState(() {
      _selecteddIndex = index;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _pagess[index]),
    );
  }
  void _onTabChange(int index) {
    _navigateToPage(index);
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


  Future<Map<String, List<Bookingdata>>> fetchFastRequests() async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/fast-requests/${widget.vendorid}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'pending': (data['pending'] as List? ?? []).map((e) => Bookingdata.fromJson(e)).toList(),
        'approved': (data['approved'] as List? ?? []).map((e) => Bookingdata.fromJson(e)).toList(),
        'cancelled': (data['cancelled'] as List? ?? []).map((e) => Bookingdata.fromJson(e)).toList(),
      };
    } else {
      throw Exception('Failed to load requests');
    }
  }
  Future<void> _fetchVendorDat() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}')
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _menuImageUrl = data['data']['image']; // Fetch menu image URL
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      );
    }
  }
  Future<String> fetchSubscriptionStatus(String vendorId) async {
    // Make HTTP request and get the subscription status
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/fetchsubscription/$vendorId'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final vendor = data['vendor'];
      return vendor['subscription']; // Return 'true' or 'false'
    } else {
      return 'false'; // Default to false if there's an error
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchVendorData();
    _fetchVendorDat();
    _dateController.text = DateFormat('dd-MM-yyyy').format(_selectedDate);

    _controller = TabController(vsync: this, length: 3);
    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
        print('Selected Tab Index: $selectedTabIndex');  // Print statement to check the selected tab index
      });
    });
    _requestsFuture = fetchFastRequests();
    _requestsFuture.then((_) {
      if (mounted) setState(() { _isLoading = false; });
    }).catchError((error) {
      if (mounted) setState(() { _isLoading = false; });
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // _checkAndUpdateBookings();
      // _checkAnduBookings();
    });
    // Define the pages (if necessary)
    _pagess = [
      vendordashScreen(vendorid: widget.vendorid),
      Bookings(vendorid: widget.vendorid),
      qrcodeallowpark(vendorid: widget.vendorid),
      Third(vendorid: widget.vendorid),
      menu(vendorid: widget.vendorid),
    ];

  }
  // Future<void> _checkAndUpdateBookings() async {
  //   try {
  //     final bookings = await fetchBookingData();
  //     final now = DateTime.now();
  //
  //     for (var booking in bookings) {
  //       try {
  //         if (booking.status != 'PENDING') {
  //           print('Skipping booking ${booking.id} as it is not pending.');
  //           continue; // Skip this booking
  //         }
  //
  //         String dateTimeString = '${booking.parkingDate} ${booking.parkingTime}';
  //         DateTime scheduledDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(dateTimeString);
  //
  //         print('Current Time: $now');
  //         print('Scheduled Time: $scheduledDateTime');
  //
  //         // Check if the scheduled time has passed by more than 10 minutes
  //         if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 10)))) {
  //           await updatecancel(booking.id, 'Cancelled');
  //           print('Booking ${booking.id} has been cancelled.');
  //         }
  //       } catch (e) {
  //         print('Error parsing date for booking ${booking.id}: $e');
  //       }
  //     }
  //
  //     // Refresh the list of bookings after updates
  //     await refreshBookingList();
  //   } catch (e) {
  //     print('Error checking and updating bookings: $e');
  //   }
  // }
  // Future<void> _checkAnduBookings() async {
  //   try {
  //     final bookings = await fetchBookingData();
  //     final now = DateTime.now();
  //
  //     for (var booking in bookings) {
  //       try {
  //         // Ensure the booking is in "Pending" status before attempting to cancel
  //         if (booking.status != 'Approved') {
  //           print('Skipping booking ${booking.id} as it is not Approved.');
  //           continue; // Skip this booking
  //         }
  //
  //         String dateTimeString = '${booking.parkingDate} ${booking.parkingTime}';
  //         DateTime scheduledDateTime = DateFormat('dd-MM-yyyy hh:mm a').parse(dateTimeString);
  //
  //         // Check if the booking time is 10 minutes past
  //         if (now.isAfter(scheduledDateTime.add(const Duration(minutes: 10)))) {
  //           await updateapprovecancel(booking.id, 'Cancelled');
  //           print('Booking ${booking.id} has been cancelled (10 minutes past the scheduled time).');
  //         }
  //       } catch (e) {
  //         print('Error parsing date for booking ${booking.id}: $e');
  //       }
  //     }
  //
  //     // Refresh the list of bookings after updates
  //     await refreshBookingList();
  //   } catch (e) {
  //     print('Error checking and updating bookings: $e');
  //   }
  // }
// Function to refresh the booking list
  Future<void> refreshBookingList() async {
    if (mounted) {
      setState(() {
        _requestsFuture = fetchFastRequests();
      });
    }
  }

  Future<void> updateAllowParking(
      String bookingId, String newStatus, String parkedDate, String parkedTime) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/allowparking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
          'parkedDate': parkedDate,  // Pass date from function argument
          'parkedTime': parkedTime,  // Pass time from function argument
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

  Future<void> _fetchVendorData() async {
    try {
      print('Fetching data for vendor ID: ${widget.vendorid}');

      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}')
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Parsed Response Data: $data');

        // Here we assume the response is structured as you showed
        // Check if 'data' is present and not null
        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
          });
        } else {
          // If 'data' is null, throw an exception with the message from the API
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching booking page data: $error');

      // Display a user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      );
    }
  }
  Future<void> updateBookingStatus(
      String bookingId, String newStatus, String approvedDate, String approvedTime) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/approvebooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
          'approvedDate': approvedDate,
          'approvedTime': approvedTime,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        print('Failed to update booking: ${response.statusCode} ${response.body}');
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
  @override
  Widget build(BuildContext context) {
    return Scaffold( backgroundColor: const Color(0xFFF1F2F6) ,
      appBar: AppBar(
        titleSpacing: 15,
        automaticallyImplyLeading: false,
        title:  Text(
          "Requests",
          style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        actions: [
          // Search Icon
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'Booking') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Bookings(vendorid: widget.vendorid),
                  ),
                );
              } else if (value == 'Subscription') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => viewsubscriptionamout(vendorid: widget.vendorid),
                  ),
                );
              }
            },
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black), // Add arrow icon
            itemBuilder: (BuildContext context) {
              return {'Booking', 'Subscription'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),

          // Filter Icon
          IconButton(
            icon: Icon(Icons.settings,size: 22, color: ColorUtils.primarycolor()),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Third(vendorid: widget.vendorid),
                ),
              );
              // Implement filter action
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => vSearchScreen(vendorid: widget.vendorid),
                ),
              );
            },
            child: SvgPicture.asset( // Correct widget name for displaying SVGs
              'assets/search.svg',color: ColorUtils.primarycolor(), // Ensure the file path is correct
              height: 14, // Set the desired height for the SVG
            ),
          ),
          // SizedBox(width: 5,),

          IconButton(
            icon: Icon(Icons.filter_list,size: 20, color: ColorUtils.primarycolor()),
            onPressed: () {
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => MyHomePage(vendorid: widget.vendorid),
              //   ),
              // );
            },
          ),
          // GestureDetector(
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => vendorChooseParkingPage(vendorid: widget.vendorid),
          //       ),
          //     );
          //   },
          //   child: Image.asset(
          //     'assets/addicon.png',
          //     height: 25,
          //   ),
          // ),
          GestureDetector(

            onTap: () async {
              String subscriptionStatus = await fetchSubscriptionStatus(widget.vendorid);

              if (subscriptionStatus == 'true') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => vendorChooseParkingPage(vendorid: widget.vendorid),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChoosePlan(vendorid: widget.vendorid),
                  ),
                );
              }
            },

            child: Image.asset(
              'assets/addicon.png',
              height: 24,
            ),
          ),
          const SizedBox(width: 15,),
          // Remove the SizedBox to eliminate extra space
        ],

        backgroundColor: const Color(0xFFF1F2F6) ,
      ),


      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(),
            borderRadius: BorderRadius.circular(20),  // Circular border
            border: Border.all(
              color: Colors.white,  // Border color, change as needed
              width: 2.0,           // Border width, adjust as needed
            ),
          ),
          child: TabContainer(
            controller: _controller,  // Ensure the controller is passed here
            borderRadius: BorderRadius.circular(20),  // Ensure this is passed as well
            tabEdge: TabEdge.top,
            curve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0.2, 0.0),
                  end: const Offset(0.0, 0.0),
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF),],
            selectedTextStyle:  GoogleFonts.poppins(
              fontSize: 15.0,
              color: ColorUtils.primarycolor(),
            ),
            unselectedTextStyle:  GoogleFonts.poppins(
              fontSize: 13.0,
              color: Colors.black, // Set default unselected color
            ),
            tabs: _getTabs(),
            children: [
              Center(
                child: FutureBuilder<Map<String, List<Bookingdata>>>(
                  future: _requestsFuture,
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
                    } else if (!snapshot.hasData) {
                      return const Center(child: Text('No Parking Request Pending'));
                    } else {
                      final filteredData = snapshot.data!['pending'] ?? [];

                      if (filteredData.isEmpty) {
                        return const Center(child: Text('No Parking Request Pending'));
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                        child: ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredData[index];

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


                            // For other items, use the regular container without the extra padding
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
                                                            DateTime now = DateTime.now();
                                                            String approvedDate = DateFormat('dd-MM-yyyy').format(now);
                                                            String approvedTime = DateFormat('hh:mm a').format(now); // Formats as 10:30 AM

                                                            try {
                                                              await updateBookingStatus(vehicle.id, 'Approved', approvedDate, approvedTime);
                                                              await refreshBookingList();
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(content: Text('Booking approved')),
                                                              );
                                                            } catch (e) {
                                                              print('Approve error: $e');
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Failed to approve booking: $e')),
                                                              );
                                                            }
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
                                                            try {
                                                              await updatecancel(vehicle.id, 'Cancelled');
                                                              await refreshBookingList();
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(content: Text('Booking cancelled')),
                                                              );
                                                            } catch (e) {
                                                              print('Cancel error: $e');
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(content: Text('Failed to cancel booking: $e')),
                                                              );
                                                            }
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
              // Provide content for the "On Parking" tab
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Align(
                      alignment: Alignment.centerRight, // Align to the right end
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5.0),
                        child: SizedBox(
                          height: 30, // Reduce height
                          child: CustomSlidingSegmentedControl<int>(
                            initialValue: selectedSegment,
                            children: {
                              0: Text("Today", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                              1: Text("All", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
                            },
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8), // Reduce border radius
                            ),
                            thumbDecoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(8), // Reduce thumb size
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            onValueChanged: (value) {
                              setState(() {
                                selectedSegment = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),


                  Expanded(
                    child: FutureBuilder<Map<String, List<Bookingdata>>>(
                      future: _requestsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Image.asset('assets/gifload.gif',),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return const Center(child: Text('No Approved Request Pending'));
                        } else if (!snapshot.hasData) {
                          return const Center(child: Text('No Approved Request Pending'));
                        } else {
                          final today = DateTime.now();
                          final todayDate = "${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}";
                          final approvedList = snapshot.data!['approved'] ?? [];
                          final filteredData = selectedSegment == 0
                              ? approvedList.where((b) => b.parkingDate == todayDate).toList()
                              : approvedList;

                          if (filteredData.isEmpty) {
                            return const Center(child: Text('No Approved Request Pending'));
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                            child: ListView.builder(
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final vehicle = filteredData[index];

                                // Add a SizedBox for space before the first data item

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


                                // If it's not the first item, return the regular item widget without additional padding
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







                                                      Padding(
                                                        padding: const EdgeInsets.only(bottom: 5.0),
                                                        child: SizedBox(
                                                          height: 25,
                                                          child: Padding(
                                                            padding:
                                                            const EdgeInsets.only(
                                                                right: 8.0),
                                                            child: ElevatedButton(
                                                              // In the Approved tab section, replace the Allow Parking button onPressed with:
                                                              onPressed: () async {
                                                                // First, validate the parking date against today's date
                                                                final today = DateTime.now();
                                                                final todayDate = "${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}";

                                                                if (vehicle.parkingDate != todayDate) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                        'Parking date does not match with today\'s date. Cannot allow parking.',
                                                                        style: GoogleFonts.poppins(),
                                                                      ),
                                                                      backgroundColor: Colors.red,
                                                                      behavior: SnackBarBehavior.floating,
                                                                      duration: const Duration(seconds: 3),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }

                                                                // If date matches, show the OTP modal
                                                                _showOtpModal(context, vehicle);
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
                                                                if (vehicle.status != 'Approved') {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(content: Text('Only approved bookings can be cancelled')),
                                                                  );
                                                                  return;
                                                                }
                                                                try {
                                                                  await updateapprovecancel(vehicle.id, 'Cancelled');
                                                                  await refreshBookingList();
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(content: Text('Booking cancelled successfully')),
                                                                  );
                                                                } catch (e) {
                                                                  print('Cancel error: $e');
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(content: Text('Failed to cancel booking: $e')),
                                                                  );
                                                                }
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
                ],
              ),
              // Provide content for the "Completed" tab
              Center(
                child: FutureBuilder<Map<String, List<Bookingdata>>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Image.asset('assets/gifload.gif',),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return const Center(child: Text('Nothing Cancelled'));
                    } else if (!snapshot.hasData) {
                      return const Center(child: Text('Nothing Cancelled'));
                    } else {
                      final filteredData = (snapshot.data!['cancelled'] ?? []).where((booking) {
                        List<String> parts = booking.bookingDate.split('-');
                        if (parts.length != 3) return false;
                        int day = int.parse(parts[0]);
                        int month = int.parse(parts[1]);
                        int year = int.parse(parts[2]);
                        DateTime bookingDate = DateTime(year, month, day);
                        DateTime selectedDateWithoutTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                        return selectedDateWithoutTime.isAtSameMomentAs(bookingDate);
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


                                  return SizedBox(
                                    height: 130,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: 20,
                                          right: 0,
                                          child: Container(
                                            height: 85,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
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





                                                        Padding(
                                                          padding: const EdgeInsets.only(right: 2.0),
                                                          child: Text(
                                                            vehicle.status,
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
                                                        )




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
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
// Example content
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: _onTabChange,
        menuImageUrl: _menuImageUrl,
      ),
    );

  }

  List<Widget> _getTabs() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.pending_actions,
          //   color: selectedTabIndex == 0 ? Colors.black : Colors.white,
          // ),
          const SizedBox(width: 8),
          Text(
            'Pending',
            style:  GoogleFonts.poppins(
              color: selectedTabIndex == 0 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.approval_rounded,
          //   color: selectedTabIndex == 1 ? Colors.black : Colors.white,
          // ),
          const SizedBox(width: 8),
          Text(
            'Approved',
            style:  GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.cancel_outlined,
          //   color: selectedTabIndex == 2 ? Colors.black : Colors.white,
          // ),
          const SizedBox(width: 8),
          Text(
            'Cancelled',
            style:  GoogleFonts.poppins(
              color: selectedTabIndex == 2 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    ];
  }







}
