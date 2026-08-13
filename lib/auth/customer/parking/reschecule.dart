import 'dart:async';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';
import 'package:mywheels/model/user.dart';
import 'package:mywheels/pageloader.dart';
import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';

class reschedule extends StatefulWidget {
  final String userId;
  final String vehicleId;
  final String vendorname;
  final String vehicle;
  final String parkingdate;
  final String parkingtime;
  final String Vendorid;

  const reschedule({super.key, required this.parkingtime,required this.userId,required this.vehicleId, required this.vendorname, required this.vehicle, required this.parkingdate, required this.Vendorid});

  @override
  _rescheduleState createState() => _rescheduleState();
}

class _rescheduleState extends State<reschedule> {
  Color customTeal = ColorUtils.primarycolor();
  DateTime? selectedDateTime;
  String? selectedParkingPlace;
  String? selectedCar;
  List<BusinessHours> businessHours = [];
  bool isVendorOpen = false;
  String closedReason = "";
  List<String> cars = [];
  bool isLoading = false;
  String? selectedCarType;
  final TextEditingController dateController = TextEditingController();
  final TextEditingController reschedule = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController checkout = TextEditingController();
  final FocusNode _subscriptionFocusNode = FocusNode();
  final SingleSelectController<String?> carController = SingleSelectController(null);
  final SingleSelectController<String?> _parkingPlaceController = SingleSelectController(null);
  Map<String, String> carTypeMap = {}; // Map to store car model and its type
  List<Vendor> vendors = [];
  DateTime? subscriptionParkingDateTime;
  final FocusNode _dateTimeFocusNode = FocusNode();
  late Timer _timer;
  bool _isLoading=false;
  String? dropdownValue; // Initial selected value
  String? _selectedCarType;

  // New validation variables
  bool isValidTime = false; // Track if selected time is valid
  bool isCheckingBusinessHours = false; // Loading state for business hours validation

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']); // Initialize user with fetched data
          });
          // Print the fetched user data for debugging
          // print('Fetched user data: ${data['data']}');
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

  User? _user;

  @override
  void initState() {
    super.initState();
    isLoading = true; // Start loading

    fetchVendors().then((_) {
      setState(() {
        isLoading = false; // Stop loading after fetching
      });

      // After vendors are loaded, check business hours and validate initial time
      if (widget.Vendorid != null && widget.Vendorid.isNotEmpty) {
        checkBusinessHours(widget.Vendorid).then((_) {
          // Small delay to ensure UI is updated
          Future.delayed(const Duration(milliseconds: 100), () {
            if (selectedDateTime != null) {
              _validateSelectedTime();
            }
          });
        });
      }
    });

    // Initialize selectedDateTime with the provided parking date and time
    if (widget.parkingdate.isNotEmpty && widget.parkingtime.isNotEmpty) {
      try {
        // Parse the parking date and time
        DateTime initialDateTime = DateFormat("dd-MM-yyyy hh:mm a").parse('${widget.parkingdate} ${widget.parkingtime}');
        selectedDateTime = initialDateTime;
        reschedule.text = _formatDateTime(initialDateTime); // Set the initial text
      } catch (e) {
        print('Error parsing initial date time: $e');
        final now = DateTime.now();
        selectedDateTime = now;
        reschedule.text = _formatDateTime(now);
      }
    } else {
      final now = DateTime.now();
      selectedDateTime = now;
      reschedule.text = _formatDateTime(now);
    }

    _fetchUserData();
  }

  // Helper function to format date (day, month, year) and time (hour, minute, AM/PM)
  String _formatDateTime(DateTime dateTime) {
    return DateFormat("dd-MM-yyyy hh:mm a").format(dateTime);  // Full date + time with AM/PM
  }

  Future<List<Vendor>> fetchVendors() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-slot-details-vendor'));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> vendorData = data['vendorData'];
        setState(() {
          vendors = vendorData.map((json) => Vendor.fromJson(json)).toList(); // Store vendors in state
          isLoading = false;  // Data loaded, stop showing the loader
        });
        return vendors; // Return the list of vendors
      } else {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load vendors');
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vendors: $e')),
      );
      return []; // Return an empty list in case of error
    }
  }

  String _getFormattedCurrentDateTime() {
    DateTime now = DateTime.now();
    DateFormat formatter = DateFormat('yyyy-MM-dd hh:mm a'); // 12-hour format with AM/PM
    return formatter.format(now);
  }

  // Updated method to validate selected time against business hours
  void _validateSelectedTime() async {
    if (widget.Vendorid == null || widget.Vendorid.isEmpty) {
      print("No vendor selected for validation");
      setState(() {
        isValidTime = false;
      });
      return;
    }

    // If business hours not loaded, fetch them first
    if (businessHours.isEmpty) {
      setState(() {
        isCheckingBusinessHours = true;
      });

      await checkBusinessHours(widget.Vendorid);

      setState(() {
        isCheckingBusinessHours = false;
      });
    }

    // Now validate the selected time
    final isValid = checkIfVendorIsOpenForSelectedTime();

    if (!isValid && closedReason.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closedReason),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Updated method to check if vendor is open for the selected time
  bool checkIfVendorIsOpenForSelectedTime() {
    if (widget.Vendorid == null || widget.Vendorid.isEmpty || businessHours.isEmpty || selectedDateTime == null) {
      setState(() {
        isVendorOpen = false;
        isValidTime = false;
        closedReason = "";
      });
      print("Validation: Skipped - Missing vendor, hours, or selected time");
      return false;
    }

    final checkDateTime = selectedDateTime!;
    final currentDay = DateFormat('EEEE').format(checkDateTime);
    final currentTime = DateFormat('HH:mm').format(checkDateTime);

    print("🔍 Validating vendor availability for: $currentDay at $currentTime");

    // Find the business hours for the selected day
    final todayHours = businessHours.firstWhere(
          (hours) => hours.day.toLowerCase() == currentDay.toLowerCase(),
      orElse: () => BusinessHours.empty(),
    );

    // If no hours for this day
    if (todayHours.day.isEmpty) {
      setState(() {
        isVendorOpen = false;
        isValidTime = false;
        closedReason = "No service available on $currentDay";
      });
      print("❌ Validation failed: No business hours for $currentDay");
      return false;
    }

    // Check if the day is completely closed
    if (todayHours.isClosed) {
      setState(() {
        isVendorOpen = false;
        isValidTime = false;
        closedReason = "Closed on $currentDay";
      });
      print("❌ Validation failed: Day is closed ($currentDay)");
      return false;
    }

    // Check if it's 24 hours open - always valid
    if (todayHours.is24Hours) {
      setState(() {
        isVendorOpen = true;
        isValidTime = true;
        closedReason = "";
      });
      print("✅ Validation passed: 24 hours operation");
      return true;
    }

    // Parse times for comparison
    try {
      final openTime = TimeOfDay(
        hour: int.parse(todayHours.openTime.split(':')[0]),
        minute: int.parse(todayHours.openTime.split(':')[1]),
      );

      final closeTime = TimeOfDay(
        hour: int.parse(todayHours.closeTime.split(':')[0]),
        minute: int.parse(todayHours.closeTime.split(':')[1]),
      );

      final selectedTimeOfDay = TimeOfDay.fromDateTime(checkDateTime);

      // Check if selected time is within operating hours
      final isOpen = (selectedTimeOfDay.hour > openTime.hour ||
          (selectedTimeOfDay.hour == openTime.hour &&
              selectedTimeOfDay.minute >= openTime.minute)) &&
          (selectedTimeOfDay.hour < closeTime.hour ||
              (selectedTimeOfDay.hour == closeTime.hour &&
                  selectedTimeOfDay.minute <= closeTime.minute));

      setState(() {
        isVendorOpen = isOpen;
        isValidTime = isOpen;
        closedReason = isOpen
            ? ""
            : "Selected time is outside operating hours. Opens at ${todayHours.openTime}, closes at ${todayHours.closeTime}";
      });

      print("🔍 Validation result: ${isOpen ? 'Valid' : 'Invalid'} - Selected time: $selectedTimeOfDay, Operating: ${openTime.hour}:${openTime.minute} - ${closeTime.hour}:${closeTime.minute}");
      return isOpen;
    } catch (e) {
      print("❌ Validation error parsing times: $e");
      setState(() {
        isValidTime = false;
        closedReason = "Invalid operating hours format";
      });
      return false;
    }
  }

  void _showDateTimePickerForSubscription() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = selectedDateTime ?? now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(now.year, now.month, now.day), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                DateTime currentNow = DateTime.now(); // Refresh the current time

                // Check if it's past time today
                if (dateTime.year == currentNow.year &&
                    dateTime.month == currentNow.month &&
                    dateTime.day == currentNow.day &&
                    dateTime.isBefore(currentNow)) {
                  // Restrict past times only on the current day
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot select a past time today!")),
                  );
                  return;
                }

                setState(() {
                  selectedDateTime = dateTime;
                  dateController.text = DateFormat("dd-MM-yyyy").format(dateTime); // Set date
                  timeController.text = DateFormat("hh:mm a").format(dateTime); // Set time
                  checkout.text = _formatDateTime(dateTime); // Set date and time in the text box
                  reschedule.text = _formatDateTime(dateTime); // Update the reschedule text controller
                  print("Selected Date: ${dateController.text}, Selected Time: ${timeController.text}"); // Debugging line
                });

                // Validate business hours after selection
                _validateSelectedTime();
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _parkingPlaceController.dispose();
    carController.dispose();
    super.dispose();
  }

  Future<void> checkBusinessHours(String vendorId) async {
    try {
      print("🔄 Fetching business hours for vendorId: $vendorId");

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId'),
      );

      print("✅ Response status: ${response.statusCode}");
      print("📩 Raw response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("📦 Decoded JSON: $data");

        setState(() {
          businessHours = (data['businessHours'] as List)
              .map((json) => BusinessHours.fromJson(json))
              .toList();

          print("⏰ Business hours parsed: $businessHours");

          // Check if vendor is currently open
          if (selectedDateTime != null) {
            checkIfVendorIsOpenForSelectedTime();
          }
          print("🏪 Vendor open check triggered");
        });
      } else {
        print("⚠️ Failed to fetch business hours. Status code: ${response.statusCode}");
        setState(() {
          isValidTime = false;
          closedReason = "Unable to fetch operating hours";
        });
      }
    } catch (e) {
      print('❌ Error fetching business hours: $e');
      setState(() {
        isValidTime = false;
        closedReason = "Unable to fetch operating hours";
      });
    }
  }

  void checkIfVendorIsOpen() {
    // This method is kept for backward compatibility but now uses the new validation logic
    if (selectedDateTime != null) {
      checkIfVendorIsOpenForSelectedTime();
    }
  }

  Future<void> _registerParking() async {
    // Additional validation before proceeding with API call
    if (!isValidTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closedReason.isNotEmpty ? closedReason : 'Please select a valid time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Format the date and time
    String formattedDate = DateFormat("dd-MM-yyyy").format(selectedDateTime!);
    String formattedTime = DateFormat("hh:mm a").format(selectedDateTime!);
    DateTime now = DateTime.now();

    try {
      // Prepare the data to send
      var data = {
        'userid': widget.userId,
        'bookingDate': DateFormat("dd-MM-yyyy").format(now),
        'parkingDate': formattedDate,
        'parkingTime': formattedTime,
        'bookingTime': DateFormat("hh:mm a").format(now),
        'status':"PENDING"
      };

      // Debugging: Print the data being sent
      print('Sending data to server: $data');

      setState(() {
        _isLoading = true;
      });

      var response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}updatebookingbyid/${widget.vehicleId}'),
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );

      // Debugging: Print the response status and body
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parking rescheduled successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ParkingPage(userId: widget.userId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register parking: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to server')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          child: AppBar(titleSpacing: 0,
            // backgroundColor: ColorUtils.primarycolor(),
            title: const Text(
              'Reschedule',
              style: TextStyle(color: Colors.black),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: SingleChildScrollView(
          child: Column(
            children: [
              // Text(
              //   widget.vehicle,
              //   style: const TextStyle(
              //     color: Colors.black,
              //     fontWeight: FontWeight.bold,
              //     fontSize: 24,
              //   ),
              // ),
              const SizedBox(height: 15),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey), // Add a border
                  borderRadius: BorderRadius.circular(5), // Circular border radius
                ),
                child: CustomDropdown<String?>(
                  hintText: widget.vendorname,
                  items: [widget.vendorname], // Wrap vendor name in a list
                  controller: _parkingPlaceController,
                  onChanged: (String? value) {
                    setState(() {
                      _parkingPlaceController.value = value; // Set the selected value
                      // selectedCarType = carTypeMap[value!]; // Get the vehicle type from the map
                    });
                  },
                ),
              ),

              const SizedBox(height: 15),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey), // Add a border
                  borderRadius: BorderRadius.circular(5), // Circular border radius
                ),
                child: CustomDropdown<String?>(
                  hintText: widget.vehicle,
                  items: [widget.vehicle], // Wrap vendor name in a list
                  controller: carController,
                  onChanged: (String? value) {
                    setState(() {
                      carController.value = value; // Set the selected value
                      selectedCarType = carTypeMap[value!]; // Get the vehicle type from the map
                    });
                  },
                ),
              ),

              const SizedBox(height: 15),
              CusTextField(
                labelColor: customTeal,
                selectedColor: customTeal,
                controller: reschedule,
                focusNode: _subscriptionFocusNode,
                keyboard: TextInputType.text,
                obscure: false,
                textInputAction: TextInputAction.done,
                inputFormatter: const [],
                label: 'Reschedule Parking Date & Time',
                hint: reschedule.text.isNotEmpty
                    ? reschedule.text
                    : (widget.parkingdate.isNotEmpty && widget.parkingtime.isNotEmpty)
                    ? '${widget.parkingdate}, ${widget.parkingtime}' // Show default values
                    : 'Select Date & Time', // Fallback hint if both are empty
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10.0,right: 5),
                  child: Icon(Icons.calendar_today, color: customTeal),
                ),
                readOnly: true,
                onTap: () async {
                  _showDateTimePickerForSubscription(); // Opens the date-time picker
                },
              ),

              const SizedBox(height: 10),

              // Container(
              //   alignment: Alignment.centerLeft, // Aligns text to the left
              //   child: Text(
              //     " Optional Information",
              //     style: TextStyle(
              //       color: Colors.black,
              //       fontWeight: FontWeight.bold,
              //       fontSize: 18,
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 10),
              // CusTextField(
              //   labelColor: customTeal,
              //   selectedColor: customTeal,
              //   controller: checkout,
              //   focusNode: _dateTimeFocusNode,
              //   keyboard: TextInputType.text,
              //   obscure: false,
              //   textInputAction: TextInputAction.next,
              //   inputFormatter: [],
              //   label: 'Tentitve checkout date & time',
              //   hint: ' Tentitve checkout date & time',
              //   prefixIcon: Icon(Icons.calendar_month_outlined, color: customTeal), // Icon color for car
              //   readOnly: true,
              //   onTap: () async {
              //     _tenditivecheckout(); // Opens the date-time picker
              //   },
              //
              //
              // ),

              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  child: IconButton(
                    onPressed: widget.Vendorid != null && widget.Vendorid.isNotEmpty ? () => _showOperationalTimingsBottomSheet() : null,
                    icon: const Icon(
                      Icons.info_outline,
                      color: Colors.grey,
                      size: 24,
                    ),
                    tooltip: 'View Operational Timings',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 10,
                      minHeight: 10,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,  // Align the button to the bottom-right
                child: SizedBox(
                  width: 100,  // Set width of the button
                  height: 40,  // Set height of the button
                  child: ElevatedButton(
                    onPressed: (_isLoading || isLoading || !isValidTime)
                        ? null
                        : _registerParking, // Disable if loading or invalid time
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValidTime
                          ? customTeal
                          : Colors.grey.shade400, // Grey out if invalid time
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    )
                        : const Align(
                      child: Text('Confirm', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ), );
  }

  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isSmallScreen ? 4 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _styledBox(String value) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(":");
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = "${hour12.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")} $period";
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }

  void _showOperationalTimingsBottomSheet() {
    print('🔍 _showOperationalTimingsBottomSheet called');
    print('📍 widget.vendorId: ${widget.Vendorid}');
    print('📋 businessHours.length: ${businessHours.length}');
    print('🏪 businessHours: $businessHours');

    // Check if vendorId exists
    if (widget.Vendorid == null || widget.Vendorid.isEmpty) {
      print('❌ Vendor ID is null or empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vendor selected')),
      );
      return;
    }

    // Check if business hours are available, if not, fetch them
    if (businessHours.isEmpty) {
      print('⏳ Business hours empty, fetching...');
      setState(() {
        isCheckingBusinessHours = true;
      });
      checkBusinessHours(widget.Vendorid).then((_) {
        if (mounted) {
          setState(() {
            isCheckingBusinessHours = false;
          });
          print('✅ Business hours fetched, retrying bottom sheet');
          _showOperationalTimingsBottomSheet();
        }
      }).catchError((error) {
        setState(() {
          isCheckingBusinessHours = false;
        });
        print('❌ Error fetching business hours: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load operational timings')),
        );
      });
      return;
    }

    print('🎉 Showing bottom sheet with ${businessHours.length} business hours');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Operational Timings',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.vendorname ?? 'Unknown Vendor',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isVendorOpen ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVendorOpen ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isVendorOpen ? Icons.check_circle : Icons.schedule,
                          color: isVendorOpen ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVendorOpen ? 'Open Now' : 'Closed',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isVendorOpen
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              if (!isVendorOpen && closedReason.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    closedReason,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Weekly Schedule Header
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: customTeal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Updated Schedule Table
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text('Day',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Open at',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Close at',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                              ],
                            ),
                          ),
                          if (businessHours.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  'No business hours available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: businessHours.length,
                              itemBuilder: (context, index) {
                                final dayData = businessHours[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4.0, vertical: 3.0),
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 3,
                                          offset: Offset(0, 2))
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          dayData.day,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: dayData.isClosed
                                            ? _statusLabel('Closed', Colors.red)
                                            : dayData.is24Hours
                                            ? _statusLabel('24 Hours', Colors.green)
                                            : _styledBox(dayData.openTime),
                                      ),
                                      if (!dayData.isClosed && !dayData.is24Hours)
                                        const SizedBox(width: 8.0),
                                      if (!dayData.isClosed && !dayData.is24Hours)
                                        Expanded(
                                          flex: 3,
                                          child: _styledBox(dayData.closeTime),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      print('📱 Bottom sheet closed');
    }).catchError((error) {
      print('❌ Error showing bottom sheet: $error');
    });
  }
}