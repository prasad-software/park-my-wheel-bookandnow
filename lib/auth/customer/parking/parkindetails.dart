import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/customer/parking/userpayment.dart';
import 'package:mywheels/explorebooknow.dart' hide Vendor;
import 'package:mywheels/model/user.dart';
import 'package:mywheels/pageloader.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'package:mywheels/utils/sts_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart' as pw; // Ensure this import is present
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../vendor/vendorbottomnav/thirdbottom.dart';
class uParkingDetails extends StatefulWidget {
  final String userid;
  final String vehiclenumber;
  final String vendorname;
  final String vendorid;
  final String parkingdate;
  final String parkingtime;
  final String bookedid;
  final String schedule;
  final String bookeddate;
  final String vehicletype;
  final String status;
  final String otp;
  final String bookingtype;
  final String sts;
  final String nav;
  final String mobilenumber;
  final String invoice;
  final String invoiceid;
  final String parkeddate;
  final String parkedtime;
  final String subscriptionenddate;
  final String exitdate;
  final String exittime;
  const uParkingDetails({
    super.key,
    required this.invoice,
    required this.invoiceid,
    required this.mobilenumber,
    required this.bookedid,
    required this.userid,
    required this.schedule,
    required this.bookeddate,
    required this.vehiclenumber,
    required this.vendorname,
    required this.vendorid,
    required this.parkingdate,
    required this.parkingtime,
    required this.vehicletype,
    required this .status,
    required this.bookingtype,
    required this.sts,
    required this.otp, required this.nav, required this.parkeddate, required this.parkedtime, required this.subscriptionenddate, required this.exitdate, required this.exittime,
  });

  @override
  _uParkingDetailsState createState() => _uParkingDetailsState();
}

class _uParkingDetailsState extends State<uParkingDetails> {
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double totalAmountWithTaxes = 0.0;
  double payableAmount = 0.0; // To store the payable amount for the booking
  bool isLoading = false;
  String? spaceid = null; // Add spaceid variable
  String? spacearea = null; // Add spacearea variable

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  List<dynamic> charges = [];

  late Position _currentPosition;
  List<String> favoriteVendorIds = [];
  List<String> amenities = []; // Add your amenities list
  List<Services> services = []; // Add your services list
  int selectedTabIndex = 0; // Track selected tab index
  double containerHeight = 500.0; // Define the containerHeight variable
  Map<String, dynamic>? _transactionDetails; // Store transaction details
  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case "open parking":
        return Icons.local_parking;
      case "gated parking":
        return Icons.lock;
      case "charging":
        return Icons.electric_car;
      case "covered parking":
        return Icons.garage;
      case "cctv":
        return Icons.videocam;
      case "atms":
        return Icons.atm;
      case "wi-fi":
        return Icons.wifi;
      case "self car wash":
        return Icons.local_car_wash;
      case "restroom":
        return Icons.wc;
      case "security":
        return Icons.security;
      default:
        return Icons.help_outline; // Default icon for unknown amenities
    }
  }
  User? _user;
  Vendor? _vendor;
  @override
  void initState() {

    super.initState();
    _fetchTransactionDetails();
    _fetchUserData();

    fetchChargesData(widget.vendorid, widget.vehicletype);
    // Ensure vendor ID is not null before fetching amenities and parking
    if (_vendor?.id != null) {
      fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
        setState(() {
          amenities = amenitiesAndParking
              .amenities; // Update the state with fetched amenities
          services = amenitiesAndParking
              .services; // Update the state with fetched services
        });
        // Print the amenities and services after fetching
        print('Fetched Amenities: $amenities');
        print('Fetched Services: $services');
      }).catchError((error) {
        print('Error fetching amenities: $error'); // Debugging print statement
      });
    }
    _fetchVendorData();
    if (widget.status == "PARKED") {
      _fetchPayableAmount(widget.bookedid);
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      isLoading = true; // Start loading
    });

    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userid}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            _nameController.text = _user?.username ?? '';
            _mobileNumberController.text = _user?.mobileNumber ?? '';
            // _emailController.text = _user?.email ?? '';
            // _vehicleController.text = _user?.vehicleNumber ?? '';
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  Future<void> fetchChargesData(String vendorId, String selectedCarType) async {
    setState(() {
      isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchbookcharge/$vendorId/$selectedCarType'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response Data: $data');

        // Check if the response contains the expected charges list
        if (data is List) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data);
          });
        } else if (data['vendor'] != null &&
            data['vendor']['charges'] != null) {
          setState(() {
            charges =
                List<Map<String, dynamic>>.from(data['vendor']['charges']);
          });
        } else {
          print('Charges data is missing or invalid in the response.');
          setState(() {
            charges = []; // Reset charges if data is invalid
          });
        }
      } else {
        print(
            'Failed to load charges data. Status Code: ${response.statusCode}');
        setState(() {
          charges = []; // Reset charges on failure
        });
      }
    } catch (e) {
      print('Error fetching charges data: $e');
      setState(() {
        charges = []; // Reset charges on error
      });
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }


  void _showTransactionDetailsBottomSheet() {
    if (_transactionDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction details not available')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Transaction Details",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Base Amount:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['amount']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
                  "Handling Fee:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['handlingfee']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
                  "GST:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['gst']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Amount:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['totalAmount']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

          ],
        ),
      ),
    );
  }
  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check if the response contains the expected structure
        if (data['AmenitiesData'] != null) {
          // Print the fetched amenities data
          print('Fetched Amenities Data: ${data['AmenitiesData']}');
          return AmenitiesAndParking.fromJson(data);
        } else {
          throw Exception('AmenitiesData is null in response');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }


  String apiUrl = '${ApiConfig.baseUrl}vendor/fetch-all-vendor-data';
  Future<Map<String, dynamic>> fetchAmountDetailsByBookingId(String bookingId) async {
    try {
      print('Fetching booking details for ID: $bookingId');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/getbooking/$bookingId'),
      );

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        print('Parsed JSON response: $jsonResponse');

        if (jsonResponse['message'] == 'Booking details fetched successfully') {
          final data = jsonResponse['data'];
          print('Extracted booking data: $data');

          final amount = data['amount'] ?? '0';
          final gst = data['gstamout'] ?? '0';
          final handlingfee = data['handlingfee']?? '0';
          final totalAmount = data['totalamout'] ?? '0';

          print('Amount: $amount, GST: $gst, Total Amount: $totalAmount');

          return {
            'amount': amount,
            'gst': gst,
            'handlingfee':handlingfee,
            'totalAmount': totalAmount,
          };
        } else {
          throw Exception('Failed to fetch booking: ${jsonResponse['message']}');
        }
      } else {
        throw Exception('Failed to fetch booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception occurred: $e');
      throw Exception('Error fetching booking details: $e');
    }
  }

  Future<void> _fetchTransactionDetails() async {
    try {
      final transactionData = await fetchAmountDetailsByBookingId(widget.bookedid);
      setState(() {
        _transactionDetails = transactionData;
      });
    } catch (e) {
      print('Error fetching transaction details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load transaction details. Please try again later.'),
        ),
      );
    }
  }
// Function to fetch vendor data
  Future<List<Map<String, dynamic>>> fetchVendors() async {
    setState(() {
      isLoading = true; // Set loading to true while fetching data
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['data'] != null) {
          return (jsonResponse['data'] as List).map((vendor) {
            double? latitude;
            double? longitude;

            // Attempt to parse latitude and longitude
            try {
              latitude = double.tryParse(
                  vendor['latitude'] ?? '0.0'); // Use '0.0' as default
              longitude = double.tryParse(
                  vendor['longitude'] ?? '0.0'); // Use '0.0' as default
            } catch (e) {
              print('Error parsing latitude/longitude: $e');
            }

            return {
              'id': vendor['_id'] ?? '',
              'name': vendor['vendorName'] ??
                  'Unknown Vendor', // Default name if null
              'latitude': latitude ?? 0.0, // Default to 0.0 if parsing fails
              'longitude': longitude ?? 0.0, // Default to 0.0 if parsing fails
              'image': vendor['image'] ?? '', // Default to empty string if null
              'address':
                  vendor['address'] ?? 'No Address', // Default address if null
              'contactNo': vendor['contactNo'] ??
                  'No Contact', // Default contact if null
              'landMark': vendor['landMark'] ??
                  'No Landmark', // Default landmark if null
            };
          }).toList();
        } else {
          print('No vendor data found');
          return [];
        }
      } else {
        print('Failed to load vendors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      return [];
    } finally {
      setState(() {
        isLoading = false; // Set loading to false once the data is fetched
      });
    }
  }




  Future<void> _fetchVendorData() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            isLoading = false; // Hide loading indicator after data is fetched
          });

          // Now that _vendor is initialized, fetch amenities and parking
          fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
            setState(() {
              amenities = amenitiesAndParking
                  .amenities; // Update the state with fetched amenities
              services = amenitiesAndParking
                  .services; // Update the state with fetched services
            });
          }).catchError((error) {
            print(
                'Error fetching amenities: $error'); // Debugging print statement
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
            'Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }
  Future<Map<String, dynamic>> fetchGstData() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0];
      }
      return {'gst': '0', 'handlingfee': '0'};
    } else {
      throw Exception('Failed to load GST fees');
    }
  }

  // Fetch payable amount for the booking
  Future<void> _fetchPayableAmount(String bookingId) async {
    final String url = "${ApiConfig.baseUrl}vendor/fet/$bookingId";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            payableAmount = double.tryParse(data['payableAmount'].toString()) ?? 0.0;
            // Extract spaceid and spacearea from API response
            spaceid = data['spaceid']?.toString();
            spacearea = data['spacearea']?.toString();
          });
        } else {
          print('Failed to fetch payable amount: ${data['message']}');
        }
      } else {
        print('Failed to load payable amount: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching payable amount: $error');
    }
  }

  // Helper function to round to nearest rupee (0.5 or above rounds up)
  // Matches `ParkingPage.roundUpToNearestRupee` behavior in `parking.dart`
  double roundUpToNearestRupeeForExitFirst(double amount) {
    final decimal = amount - amount.floor();
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }

  // Calculate total amount with taxes
  double calculateTotalWithTaxes(double payableAmount) {
    // Use raw amounts; no per-component rounding
    double parkingCharge = payableAmount;
    double handlingFeeAmount = handlingFee;

    // GST on (amount + handling)
    double gstBase = parkingCharge + handlingFeeAmount;
    double gstAmount = (gstBase * gstPercentage) / 100;

    // Exact total, then round only the final payable amount
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
    double roundedTotal = roundUpToNearestRupeeForExitFirst(exactTotal);

    totalAmountWithTaxes = roundedTotal;
    return roundedTotal;
  }

  // Parse parking date time string to DateTime for exit (first class)
  DateTime parseParkingDateTimeForExitFirst(String dateTimeString) {
    try {
      final parts = dateTimeString.trim().split(' ');
      if (parts.length < 3) {
        return DateTime.parse(dateTimeString);
      }
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');

      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      int second = 0;

      if (parts[2] == 'PM' && hour != 12) {
        hour += 12;
      } else if (parts[2] == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now();
    }
  }

  // Get payable duration from parked date/time (first class)
  Duration getPayableDurationForExitFirst() {
    if (widget.parkeddate.isEmpty || widget.parkedtime.isEmpty) {
      return Duration.zero;
    }
    try {
      final parkingDateTime = parseParkingDateTimeForExitFirst("${widget.parkeddate} ${widget.parkedtime}");
      final now = DateTime.now();
      final difference = now.difference(parkingDateTime);
      return difference.isNegative ? Duration.zero : difference;
    } catch (e) {
      print('Error calculating payable duration: $e');
      return Duration.zero;
    }
  }

  // Format duration as HH.MM.SS (first class)
  String formatDurationForExitFirst(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours.$minutes.$seconds';
  }

  // Show exit confirmation bottom sheet
  void _showExitConfirmation() async {
    // Fetch GST and handling fee data only if it's a customer booking
    if (widget.userid.isNotEmpty) {
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

    // Create a ValueNotifier for the payable duration
    final durationNotifier = ValueNotifier<Duration>(getPayableDurationForExitFirst());
      
      // Start a timer to update the duration every second
      Timer? durationTimer;
      durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          durationNotifier.value = getPayableDurationForExitFirst();
        } else {
          timer.cancel();
        }
      });

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
        builder: (context) {
          // Cancel timer when bottom sheet is closed
          return WillPopScope(
            onWillPop: () async {
              durationTimer?.cancel();
              return true;
            },
            child: SafeArea(
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
                                durationTimer?.cancel();
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
                                  painter: RadialTicksPainterForExit(),
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
                                    ValueListenableBuilder<Duration>(
                                      valueListenable: durationNotifier,
                                      builder: (context, duration, child) {
                                        return Text(
                                          formatDurationForExitFirst(duration),
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
                                        widget.bookedid.length > 8 ? widget.bookedid.substring(widget.bookedid.length - 8) : widget.bookedid,
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
                                        "${widget.parkingdate} ${widget.parkingtime}",
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
                                        _user?.username ?? '',
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
                                        widget.mobilenumber,
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
                                        '${widget.sts} (${widget.bookingtype})',
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
                                        widget.userid.isEmpty ? 'Vendor' : 'Customer',
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
                    // Parking Charges (round ONLY payableAmount for exit)
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
                        Text(
                          "₹${roundUpToNearestRupeeForExitFirst(payableAmount).toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (widget.userid.isNotEmpty) ...[
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
                        Text(
                          "₹${((payableAmount + handlingFee) * gstPercentage / 100).toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                              color: Colors.black,
                            ),
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
                        Text(
                          "₹${calculateTotalWithTaxes(payableAmount).toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 14 * MediaQuery.of(context).textScaleFactor,
                            color: ColorUtils.primarycolor(),
                            fontWeight: FontWeight.bold,
                          ),
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
                            durationTimer?.cancel();
                            Navigator.pop(context);
                            _navigateToPayment();
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
        },
      );
  }
  Future<void> _generateInvoicePdf() async {
    final pdf = pw.Document();

    // Load Google Fonts for the PDF
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final logoImage = await rootBundle.load('assets/top.png');
    final logoImageBytes = logoImage.buffer.asUint8List();
    final pwImage = pw.MemoryImage(logoImageBytes);

    // Helper function to get display-friendly booking type
    String getBookingTypeDisplay() {
      if (widget.sts == null || widget.sts.isEmpty) return 'N/A';
      if (widget.bookingtype == '24 Hours') return 'Full Day';
      return widget.sts; // always show sts value
    }

    // Define date format for parsing widget.schedule
    final dateFormat = DateFormat('dd MMM, yyyy, hh:mm a');

    // Determine fromDate and toDate based on widget.sts
    String fromDate;
    String toDate;

    if (isVendorShortParkingSts(widget.sts)) {
      fromDate = "${widget.parkeddate}, ${widget.parkedtime}";
      toDate = "${widget.exitdate}, ${widget.exittime}";
    } else if (isSubscriptionSts(widget.sts)) {
      fromDate = "${widget.parkeddate}, ${widget.parkedtime}";
      toDate = widget.subscriptionenddate;
    } else {
      fromDate = widget.parkeddate;
      toDate = widget.subscriptionenddate;
    }

    try {
      if (isVendorShortParkingSts(widget.sts)) {
        final parsedDate = dateFormat.parse(fromDate);
        final endDate = dateFormat.parse(toDate);
        fromDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);
        toDate = DateFormat('dd MMM yyyy, hh:mm a').format(endDate);
      } else if (isSubscriptionSts(widget.sts)) {
        final parsedDate = dateFormat.parse(fromDate);
        final endDate = dateFormat.parse(toDate);
        fromDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);
        toDate = DateFormat('dd MMM yyyy, hh:mm a').format(endDate);
      }
    } catch (e) {
      print('Error parsing date: $e');
      if (isVendorShortParkingSts(widget.sts)) {
        fromDate = "${widget.parkeddate}, ${widget.parkedtime}";
        toDate = "${widget.exitdate}, ${widget.exittime}";
      } else if (isSubscriptionSts(widget.sts)) {
        fromDate = "${widget.parkeddate}, ${widget.parkedtime}";
        toDate = widget.subscriptionenddate;
      } else {
        fromDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
        toDate = 'N/A';
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ParkMyWheels – Parking Invoice',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 14,
                        color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Smart Parking Made Easy!',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side: Invoice Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice No: ${widget.invoiceid}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Date of Issue: ${DateTime.now().toString().split(' ')[0]}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Image
                  pw.Image(
                    pwImage,
                    width: 100,
                    height: 100,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer Details
              pw.Text(
                'Customer Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Customer Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Name: ${_user?.username ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Number: ${widget.vehiclenumber}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Type: ${widget.vehicletype}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Parking Location, Vendor, and Vendor Address
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Parking Location',
                        style: pw.TextStyle(font: font, fontSize: 14),
                      ),
                      pw.Text(
                        '${widget.vendorname ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Address: ${_vendor?.address ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Subscription Details
              pw.Text(
                'Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                    ),
                    children: [
                      for (var header in ['Description', 'Parked on', 'Exit on', 'Fees (₹)'])
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Center(
                            child: pw.Text(
                              header,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                color: PdfColor.fromInt(ColorUtils.whiteclr().value),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Data Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            getBookingTypeDisplay(),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            fromDate,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            toDate,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            _transactionDetails?['amount'] ?? '0.00',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total Payable
              pw.Text(
                'Total Payable',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Base Amount: ₹${_transactionDetails?['amount'] ?? '0.00'}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  // Only show Handling Fee if it's non-zero
                  if ((_transactionDetails?['handlingfee'] ?? '0') != '0' &&
                      double.tryParse(_transactionDetails?['handlingfee']?.toString() ?? '0') != 0.0)
                    pw.Text(
                      'Handling Fee: ₹${_transactionDetails?['handlingfee'] ?? '0.00'}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  // Only show GST if it's non-zero
                  if ((_transactionDetails?['gst'] ?? '0') != '0' &&
                      double.tryParse(_transactionDetails?['gst']?.toString() ?? '0') != 0.0)
                    pw.Text(
                      'GST: ₹${_transactionDetails?['gst'] ?? '0.00'}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  pw.Text(
                    'Total Amount (in INR): ₹${_transactionDetails?['totalAmount'] ?? '0.00'}',
                    style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Payment Details
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Mode of Payment: ${widget.invoice != null ? 'Online' : 'Cash'}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                'Transaction ID: ${widget.invoice}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Authorized Signature
              pw.Text(
                'Authorized Signature',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Digitally signed by ParkMyWheels',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                '(This is a computer-generated invoice and does not require a physical signature.)',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Column(
                children: [
                  pw.Text(
                    'Website: www.parkmywheels.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    'Email: parkmywheels3@gmail.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Display the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
  // Navigate to payment page
  void _navigateToPayment() {
    // Round ONLY payableAmount (parking charge) for exit payment
    final parkingCharge = roundUpToNearestRupeeForExitFirst(payableAmount);
    final handlingFeeAmount = handlingFee;
    final gstBase = parkingCharge + handlingFeeAmount;
    final gstAmount = (gstBase * gstPercentage) / 100;
    final totalAmount = parkingCharge + handlingFeeAmount + gstAmount;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPayment(
          venodorname: widget.vendorname,
          vendorid: widget.vendorid,
          userid: widget.userid,
          mobilenumber:  _user?.username ?? '', // You may need to fetch this from user data
          vehicleid: widget.bookedid,
          amout: parkingCharge.toStringAsFixed(2),
          payableduration: '', // You may need to fetch or calculate this
          handlingfee: handlingFeeAmount.toStringAsFixed(2),
          gstfee: gstAmount.toStringAsFixed(2),
          totalamount: totalAmount.toStringAsFixed(2),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildDetailsTab(), // This allows the tab to take available space
          ),
        ],
      ),),
    );
  }

  Widget _buildDetailsTab() {
    return CustomScrollView(slivers: [
      SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_circle_left, color: Colors.white),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        _vendor?.vendorName ?? '',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(1, 1),
              blurRadius: 3,
              color: Colors.black.withOpacity(0.7),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax, // smooth scroll effect
        background: Stack(
          fit: StackFit.expand,
          children: [
            // --- Image Background ---
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              child: Image.network(
                _vendor?.image ?? '',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: LoadingAnimationWidget.halfTriangleDot(
                      color: Colors.white,
                      size: 50,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: ColorUtils.primarycolor(),
                    child: const Center(
                      child: Icon(Icons.error, color: Colors.white, size: 40),
                    ),
                  );
                },
              ),
            ),

            // --- Gradient Overlay (for better text contrast) ---
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vendor != null) ...[

                  Column(
                    children: [
                      Column(
                        children: [
                          Container(
                            // color: ColorUtils.primarycolor(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: ColorUtils
                                  .primarycolor(), // Ensure the background color is set
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(15),
                                bottomRight: Radius.circular(15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment
                                  .start, // Aligns everything to the top
                              children: [
                                Expanded(
                                  // Ensures the column takes only necessary space
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start, // Aligns text to the left
                                    mainAxisSize: MainAxisSize
                                        .min, // Reduces extra space
                                    children: [
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        child: Text(
                                          _vendor?.vendorName ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            height: 1.2,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 0), // Adjusted spacing
                                      Text(
                                        _vendor!.address,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            height: 1.2,
                                            color: Colors.white),
                                      ),
                                      const SizedBox(height: 5),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    const SizedBox(height: 5),
                                    Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: GestureDetector(
                                        onTap: () async {
                                          final double latitude =
                                              double.tryParse(
                                                      _vendor?.latitude ??
                                                          '0') ??
                                                  0.0;
                                          final double longitude =
                                              double.tryParse(
                                                      _vendor?.longitude ??
                                                          '0') ??
                                                  0.0;

                                          final String googleMapsUrl =
                                              'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

                                          if (await canLaunch(
                                              googleMapsUrl)) {
                                            await launch(googleMapsUrl);
                                          } else {
                                            debugPrint(
                                                "Could not launch $googleMapsUrl");
                                          }
                                        },
                                        child: Container(
                                          height: 20,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 1.2),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${_vendor?.distance != null ? _vendor!.distance?.toStringAsFixed(2) : 'N/A'} km',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.telegram,
                                                  size: 16.0,
                                                  color: Colors.blue),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // const SizedBox(height: 5), // Reduced spacing
                        ],
                      ),
                      const SizedBox(height: 8),

                       Padding(
                         padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                         child: SizedBox(
                          height: 200,
                             child: Stack(
                             children: [

                             Positioned(
                             left: 0,
                             top: 10,
                             right: 0,
                             child: Container(
                             height: 190, // Set the appropriate height
                             decoration: BoxDecoration(
                             color: ColorUtils.primarycolor(),
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
                             child:  Row(
                               mainAxisAlignment:
                               MainAxisAlignment.center,
                               children: [
                                 if (widget.status != "COMPLETED" &&
                                     widget.status != "Cancelled") ...[
                                   Text(
                                     "OTP: ",
                                     style: GoogleFonts.poppins(
                                       fontWeight: FontWeight.bold,
                                       color: Colors.white,
                                       fontSize: 16,
                                     ),
                                   ),
                                   ...(widget.otp.length >= 3
                                       ? (widget.status == 'PARKED'
                                       ? widget.otp
                                       .substring(widget.otp.length - 3)
                                       .split('')
                                       .map((digit) => _pinBox(digit))
                                       : widget.otp
                                       .substring(0, 3)
                                       .split('')
                                       .map((digit) => _pinBox(digit)))
                                       : [
                                     Text(
                                       "Invalid OTP ID",
                                       style: GoogleFonts.poppins(
                                         color: Colors.white,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     )
                                   ])
                                 ],
                                 // Show "Book Again" button for completed or cancelled bookings
                                 if (widget.status == "COMPLETED" ||
                                     widget.status == "Cancelled")

                                   ElevatedButton(
                                     onPressed: () {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(
                                           builder: (context) =>
                                               ExploreBook(
                                                 vendorId: widget.vendorid,
                                                 userId: widget.userid,
                                                 vendorName:widget.vendorname,
                                               ),
                                         ),
                                       );
                                       print("Book Again pressed");
                                     },
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: Colors.white,
                                       foregroundColor: ColorUtils.primarycolor(),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(5),
                                       ),
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 8,
                                         vertical: 6,
                                       ),
                                       minimumSize: const Size(100, 10), // small button
                                     ),
                                     child: Text(
                                       "Book Again",
                                       style: GoogleFonts.poppins(
                                         fontSize: 14,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ),
                               ],
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
                                 color: Colors.white,
                                 child: Align(
                                   alignment: Alignment.center, // Aligns content to the left
                                   child: Text(
                                     "Booking details",
                                     style: GoogleFonts.poppins(
                                       fontSize: 16,
                                       fontWeight: FontWeight.bold,
                                       // decoration: TextDecoration.underline, // Add underline here
                                       decorationColor: Colors.black, // Optional: Set the color of the underline
                                       // Optional: Set the thickness of the underline
                                     ),
                                   ),
                                 ),
                               ),
                               Divider(
                                 thickness: 0.5, // Set the thickness of the divider
                                 color: ColorUtils.primarycolor(), // Set the color of the divider
                               ),
                             // Container(
                             // padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                             // decoration: BoxDecoration(
                             // border: Border(
                             // bottom: BorderSide(
                             // color: ColorUtils.primarycolor(), // Replace with ColorUtils.primarycolor()
                             // width: 0.5,
                             // ),
                             // ),
                             // borderRadius: const BorderRadius.only(
                             // topLeft: Radius.circular(5.0),
                             // topRight: Radius.circular(5.0),
                             // ),
                             // ),
                             // child: Row(
                             // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             // children: [
                             //   Padding(
                             //     padding: const EdgeInsets.only(right: 12.0),
                             //     child: Text(
                             //       widget.vehiclenumber,
                             //       style: GoogleFonts.poppins(
                             //         color:ColorUtils.primarycolor(),
                             //         fontWeight: FontWeight.bold,
                             //       ),
                             //     ),
                             //   ),
                             // const Spacer(),
                             // Padding(
                             // padding: const EdgeInsets.only(right: 12.0),
                             // child: Text(
                             // widget.status,
                             // style: GoogleFonts.poppins(
                             // color:ColorUtils.primarycolor(),
                             // fontWeight: FontWeight.bold,
                             // ),
                             // ),
                             // ),
                             //
                             // ],
                             // ),
                             // ),
                               Row(
                                 mainAxisAlignment:
                                 MainAxisAlignment.start,
                                 crossAxisAlignment:
                                 CrossAxisAlignment.start,
                                 children: [
                                   ClipPath(
                                     clipper: TicketClipper(),
                                     child: Container(
                                       padding: const EdgeInsets.all(5),
                                       decoration: const BoxDecoration(),
                                       child: Column(
                                         crossAxisAlignment:
                                         CrossAxisAlignment.center,
                                         children: [
                                           Container(
                                             // decoration: BoxDecoration(
                                             //   color: Colors.white,
                                             //   borderRadius: BorderRadius.circular(16),
                                             //   boxShadow: const [
                                             //     BoxShadow(
                                             //       color: Colors.black12,
                                             //       blurRadius: 4,
                                             //     ),
                                             //   ],
                                             // ),
                                             padding:
                                             const EdgeInsets.all(10),
                                             child: PrettyQr(
                                               data: widget.bookedid,
                                               size: 100,
                                               roundEdges: true,
                                               errorCorrectLevel:
                                               QrErrorCorrectLevel.H,
                                               elementColor: Colors.black,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                   const SizedBox(
                                       width:
                                       2), // Spacing between QR and details
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment:
                                       CrossAxisAlignment.start,
                                       children: [

                                         const SizedBox(
                                             height:
                                             13),
                                         Text(
                                           " ${widget.vehiclenumber.toString()}",
                                           style: GoogleFonts.poppins(fontSize: 16),
                                         ),
                                         Text(
                                           "Booking date:${widget.bookeddate.toString()}",
                                           style: GoogleFonts.poppins(fontSize: 11),
                                         ),
                                         Text(
                                           "Parking date:${widget.schedule.toString()}",
                                           style: GoogleFonts.poppins(fontSize: 11),
                                         ),

                                         Text(
                                           "Status: ${widget.status.toString()},",
                                           style: GoogleFonts.poppins(fontSize: 11),
                                         ),
                                         Text(
                                           "Mobile Number: ${widget.mobilenumber.toString()},",
                                           style: GoogleFonts.poppins(fontSize: 11),
                                         ),
                                         Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             // Text(
                                             //   ": ${widget.sts}",
                                             //   style: GoogleFonts.poppins(fontSize: 11),
                                             // ),
                                             Text(
                                               "Booking Type: ${isSubscriptionSts(widget.sts) ? 'Monthly' : (widget.bookingtype == '24 Hours' ? 'Full Day' : 'Hourly')}",
                                               style: GoogleFonts.poppins(fontSize: 11),
                                             ),
                                           ],
                                         )

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
                       ),

                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Column(
                          children: [


                            const SizedBox(height: 15),
                            if (widget.status.toString() == "COMPLETED")

                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                // color: Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 10,),
                                    Text(
                                      "Invoice",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Spacer(),
                                    TextButton.icon(
                                      onPressed: _transactionDetails == null
                                          ? null
                                          : () {
                                        _generateInvoicePdf();
                                      },
                                      icon: Icon(
                                        Icons.remove_red_eye,
                                        color: ColorUtils.primarycolor(),
                                      ),
                                      label: Text(
                                        "View",
                                        style: TextStyle(
                                          color: ColorUtils.primarycolor(),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (widget.status.toString() == "COMPLETED")
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                // color: Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 10,),
                                    Text(
                                      "Transaction details",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Spacer(),
                                    TextButton.icon(
                                      onPressed: _showTransactionDetailsBottomSheet,
                                      icon: Icon(
                                        Icons.remove_red_eye,
                                        color: ColorUtils.primarycolor(),
                                      ),
                                      label: Text(
                                        "View",
                                        style: TextStyle(
                                          color: ColorUtils.primarycolor(),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              ),



                            const SizedBox(height: 15),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(5), // Set border radius
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              // color: Colors.white,
                              child: Column(
                                children: [
                                  const SizedBox(height: 5),
                                  Container(
                                    color: Colors.white,
                                    child: Align(
                                      alignment: Alignment.center, // Aligns content to the left
                                      child: Text(
                                        "Price details",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // decoration: TextDecoration.underline, // Add underline here
                                          decorationColor: Colors.black, // Optional: Set the color of the underline
                                          // Optional: Set the thickness of the underline
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness: 0.5, // Set the thickness of the divider
                                    color: ColorUtils.primarycolor(), // Set the color of the divider
                                  ),
                                  // const SizedBox(height: 2),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Move color inside decoration
                                      borderRadius: BorderRadius.circular(5), // Set border radius
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal, // Enable horizontal scrolling
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center, // Center items inside Row
                                          children: List.generate(charges.length, (index) {
                                            var charge = charges[index];
                                            return Row(
                                              children: [
                                                Container(
                                                  width: 85, // Set width for each item
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 6, horizontal: 4), // Reduce vertical padding
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        charge['type'],
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 10,
                                                          height: 1.2, // Reduce line spacing
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 1), // Reduce space between text
                                                      Text(
                                                        "₹${charge['amount']}",
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.black,
                                                          fontSize: 14,
                                                          height: 1.2, // Reduce line spacing
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (index < charges.length - 1)
                                                  const SizedBox(
                                                    width: 16, // Reduce spacing between items
                                                    height: 35, // Set height to match container's height
                                                    child: VerticalDivider(
                                                      color: Colors.grey,
                                                      thickness: 0.5,
                                                      width: 8, // Reduce space between items
                                                    ),
                                                  ),
                                              ],
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),


        const SizedBox(height: 8),
    if (amenities.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(5), // Set border radius
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
                                children: [
                                  const SizedBox(height: 5),

                                  Container(
                                    color: Colors.white,
                                    child: Align(
                                      alignment: Alignment.center, // Aligns content to the left
                                      child: Text(
                                        "Facilities",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // decoration: TextDecoration.underline, // Add underline here
                                          decorationColor: Colors.black, // Optional: Set the color of the underline
                                          // Optional: Set the thickness of the underline
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness: 0.5, // Set the thickness of the divider
                                    color: ColorUtils.primarycolor(), // Set the color of the divider
                                  ),
                                  //
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children: amenities.map((amenity) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              // color:  ColorUtils.primarycolor() ,
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: Colors.black, // Set the color of the border
                                                width: 0.5, // Set the width of the border
                                              ),
                                              boxShadow: const [
                                                // BoxShadow(
                                                //   color: Colors.black26,
                                                //   blurRadius: 4.0,
                                                //   offset: Offset(0, 2),
                                                // ),
                                              ]),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getAmenityIcon(amenity),
                                                size: 12,
                                                color: Colors.black,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                amenity,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                  // fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
],
                            const SizedBox(height: 8),
    if (services.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(5), // Set border radius
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
                                children: [

                                  Container(
                                    color: Colors.white,
                                    child: Align(
                                      alignment: Alignment.center, // Aligns content to the left
                                      child: Text(
                                        "Additional Services",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // decoration: TextDecoration.underline, // Add underline here
                                          decorationColor: Colors.black, // Optional: Set the color of the underline
                                          // Optional: Set the thickness of the underline
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness: 0.5, // Set the thickness of the divider
                                    color: ColorUtils.primarycolor(), // Set the color of the divider
                                  ),
                                  const SizedBox(height: 8),
                                  // Heading Card


                                  // Loop through the services list
                                  Wrap(
                                    spacing: 6.0,
                                    runSpacing: 6.0,
                                    children: services.asMap().entries.map((entry) {
                                      final s = entry.value;

                                      return Container(
                                        // width: 100, // Adjust width as needed
                                        padding: const EdgeInsets.all(5.0),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.black, width: 0.5),
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              s.type,
                                              style: GoogleFonts.poppins(fontSize: 12),
                                              textAlign: TextAlign.center,
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              ": ₹${s.amount}",
                                              style: GoogleFonts.poppins(fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),

                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
],
                            // Add more widgets as needed
                            // Google Map
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                // color: Colors.white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(5), // Set border radius
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              // color: Colors.white,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 5),
                                    child: Container(
                                      width: double.infinity,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        // border:
                                        //     Border.all(color: Colors.grey),
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        child: GoogleMap(
                                          initialCameraPosition:
                                              CameraPosition(
                                            target: LatLng(
                                              double.tryParse(
                                                      _vendor?.latitude ??
                                                          '0') ??
                                                  0.0, // Convert latitude to double
                                              double.tryParse(
                                                      _vendor?.longitude ??
                                                          '0') ??
                                                  0.0,
                                            ),
                                            zoom: 15,
                                          ),
                                          markers: {
                                            Marker(
                                              markerId: const MarkerId(
                                                  'vendor_location'),
                                              position: LatLng(
                                                double.tryParse(
                                                        _vendor?.latitude ??
                                                            '0') ??
                                                    0.0, // Convert latitude to double
                                                double.tryParse(
                                                        _vendor?.longitude ??
                                                            '0') ??
                                                    0.0,
                                              ),
                                            ),
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  if (widget.status.toString() == "PARKED" && widget.nav == "daily")
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: payableAmount == 0.0
                                          ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              ColorUtils.primarycolor()),
                                        ),
                                      )
                                          : (spaceid != null && spaceid!.isNotEmpty)
                                              ? const SizedBox.shrink() // Hide button if spaceid is present
                                              : SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _showExitConfirmation();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            minimumSize: const Size(0, 0),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.all(Radius.circular(5)),
                                              side: BorderSide(
                                                color: Colors.red,
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.qr_code_scanner,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 50,)
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),

            ],
          ],
        ),
      ),
    ]);
  }
}

class uvParkingDetails extends StatefulWidget {
  final String parkeddate;
  final String parkedtime;
  final String subscriptionenddate;
  final String exitdate;
  final String exittime;
  final String userid;
  final String invoiceid;
  final String vehiclenumber;
  final String vendorname;
  final String vendorid;
  final String parkingdate;
  final String parkingtime;
  final String bookedid;
  final String schedule;
  final String bookeddate;
  final String vehicletype;
  final String status;
  final String otp;
  final String bookingtype;
  final String sts;
  final String nav;
  final String?spaceid;
  const uvParkingDetails({
    super.key,
    required this.bookedid,
    required this.userid,
    required this.invoiceid,
    required this.schedule,
    required this.bookeddate,
    required this.vehiclenumber,
    required this.vendorname,
    required this.vendorid,
    required this.parkingdate,
    required this.parkingtime,
    required this.vehicletype,
    required this .status,
    required this.bookingtype,
    required this.sts,
   this.spaceid,
    required this.otp, required this.nav, required this.parkeddate, required this.parkedtime, required this.subscriptionenddate, required this.exitdate, required this.exittime,
  });

  @override
  _uvParkingDetailsState createState() => _uvParkingDetailsState();
}

class _uvParkingDetailsState extends State<uvParkingDetails> {
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  double totalAmountWithTaxes = 0.0;
  double payableAmount = 0.0; // To store the payable amount for the booking
  bool isLoading = false;
  String? spaceid = null; // Add spaceid variable
  String? spacearea = null; // Add spacearea variable
  bool _locationDenied = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  List<dynamic> charges = [];
  bool _locationPermanentlyDenied = false;
  late Position _currentPosition;
  List<String> favoriteVendorIds = [];
  List<String> amenities = []; // Add your amenities list
  List<Services> services = []; // Add your services list
  int selectedTabIndex = 0; // Track selected tab index
  double containerHeight = 500.0; // Define the containerHeight variable
  Map<String, dynamic>? _transactionDetails; // Store transaction details
  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case "open parking":
        return Icons.local_parking;
      case "gated parking":
        return Icons.lock;
      case "charging":
        return Icons.electric_car;
      case "covered parking":
        return Icons.garage;
      case "cctv":
        return Icons.videocam;
      case "atms":
        return Icons.atm;
      case "wi-fi":
        return Icons.wifi;
      case "self car wash":
        return Icons.local_car_wash;
      case "restroom":
        return Icons.wc;
      case "security":
        return Icons.security;
      default:
        return Icons.help_outline; // Default icon for unknown amenities
    }
  }
  User? _user;
  Vendor? _vendor;
  @override
  void initState() {

    super.initState();
    _fetchTransactionDetails();
    _fetchUserData();
    _requestLocationPermission();
    fetchChargesData(widget.vendorid, widget.vehicletype);
    // Ensure vendor ID is not null before fetching amenities and parking
    if (_vendor?.id != null) {
      fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
        setState(() {
          amenities = amenitiesAndParking
              .amenities; // Update the state with fetched amenities
          services = amenitiesAndParking
              .services; // Update the state with fetched services
        });
        // Print the amenities and services after fetching
        print('Fetched Amenities: $amenities');
        print('Fetched Services: $services');
      }).catchError((error) {
        print('Error fetching amenities: $error'); // Debugging print statement
      });
    }
    _fetchVendorData();
    if (widget.status == "PARKED") {
      fetchBookingsAndCharges();
      _fetchPayableAmount(widget.bookedid);
    }
  }
  Future<void> _fetchUserData() async {
    setState(() {
      isLoading = true; // Start loading
    });

    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userid}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            _nameController.text = _user?.username ?? '';
            _mobileNumberController.text = _user?.mobileNumber ?? '';
            // _emailController.text = _user?.email ?? '';
            // _vehicleController.text = _user?.vehicleNumber ?? '';
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }


  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (_vendor != null) {
        double distance = haversineDistance(
          _currentPosition.latitude,
          _currentPosition.longitude,
          double.tryParse(_vendor!.latitude) ?? 0.0,
          double.tryParse(_vendor!.longitude) ?? 0.0,
        );
        setState(() {
          _vendor!.distance = distance; // Now this will work
        });
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    final url =
    Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check if the response contains the expected structure
        if (data['AmenitiesData'] != null) {
          // Print the fetched amenities data
          print('Fetched Amenities Data: ${data['AmenitiesData']}');
          return AmenitiesAndParking.fromJson(data);
        } else {
          throw Exception('AmenitiesData is null in response');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      setState(() {
        _locationDenied = true;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _locationPermanentlyDenied = true;
      });
    }
  }

  String apiUrl = '${ApiConfig.baseUrl}vendor/fetch-all-vendor-data';
  Future<Map<String, dynamic>> fetchAmountDetailsByBookingId(String bookingId) async {
    try {
      print('Fetching booking details for ID: $bookingId');

      // Fetch booking details
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/getbooking/$bookingId'),
      );

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        print('Parsed JSON response: $jsonResponse');

        if (jsonResponse['message'] == 'Booking details fetched successfully') {
          final data = jsonResponse['data'];
          print('Extracted booking data: $data');

          final amount = data['amount'] ?? '0';
          final gst = data['gstamout'] ?? '0';
          final totalAmount = data['totalamout'] ?? '0';
          // Use booking's actual handling fee (not vendor GST rate) so invoice shows 0 when fee is 0
          final handlingFee = data['handlingfee'] ?? '0';

          print('Amount: $amount, GST: $gst, Handling Fee: $handlingFee, Total Amount: $totalAmount');

          return {
            'amount': amount,
            'gst': gst,
            'handlingfee': handlingFee,
            'totalAmount': totalAmount,
          };
        } else {
          throw Exception('Failed to fetch booking: ${jsonResponse['message']}');
        }
      } else {
        throw Exception('Failed to fetch booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception occurred: $e');
      throw Exception('Error fetching booking details: $e');
    }
  }
  Future<void> _fetchTransactionDetails() async {
    try {
      final transactionData = await fetchAmountDetailsByBookingId(widget.bookedid);
      setState(() {
        _transactionDetails = transactionData;
      });
    } catch (e) {
      print('Error fetching transaction details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load transaction details. Please try again later.'),
        ),
      );
    }
  }
// Function to fetch vendor data
  Future<List<Map<String, dynamic>>> fetchVendors() async {
    setState(() {
      isLoading = true; // Set loading to true while fetching data
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['data'] != null) {
          return (jsonResponse['data'] as List).map((vendor) {
            double? latitude;
            double? longitude;

            // Attempt to parse latitude and longitude
            try {
              latitude = double.tryParse(
                  vendor['latitude'] ?? '0.0'); // Use '0.0' as default
              longitude = double.tryParse(
                  vendor['longitude'] ?? '0.0'); // Use '0.0' as default
            } catch (e) {
              print('Error parsing latitude/longitude: $e');
            }

            return {
              'id': vendor['_id'] ?? '',
              'name': vendor['vendorName'] ??
                  'Unknown Vendor', // Default name if null
              'latitude': latitude ?? 0.0, // Default to 0.0 if parsing fails
              'longitude': longitude ?? 0.0, // Default to 0.0 if parsing fails
              'image': vendor['image'] ?? '', // Default to empty string if null
              'address':
              vendor['address'] ?? 'No Address', // Default address if null
              'contactNo': vendor['contactNo'] ??
                  'No Contact', // Default contact if null
              'landMark': vendor['landMark'] ??
                  'No Landmark', // Default landmark if null
            };
          }).toList();
        } else {
          print('No vendor data found');
          return [];
        }
      } else {
        print('Failed to load vendors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      return [];
    } finally {
      setState(() {
        isLoading = false; // Set loading to false once the data is fetched
      });
    }
  }


  Future<void> _requestPermissionAgain() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
      setState(() {
        _locationDenied = false;
        _locationPermanentlyDenied = false;
      });
    }
  }

  Future<void> _fetchVendorData() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            isLoading = false; // Hide loading indicator after data is fetched
          });

          // Now that _vendor is initialized, fetch amenities and parking
          fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
            setState(() {
              amenities = amenitiesAndParking
                  .amenities; // Update the state with fetched amenities
              services = amenitiesAndParking
                  .services; // Update the state with fetched services
            });
          }).catchError((error) {
            print(
                'Error fetching amenities: $error'); // Debugging print statement
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
            'Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }
  Future<Map<String, dynamic>> fetchGstData() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0];
      }
      return {'gst': '0', 'handlingfee': '0'};
    } else {
      throw Exception('Failed to load GST fees');
    }
  }

  Future<void> fetchChargesData(String vendorId, String selectedCarType) async {
    setState(() {
      isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchbookcharge/$vendorId/$selectedCarType'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response Data: $data');

        // Check if the response contains the expected charges list
        if (data is List) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data);
          });
        } else if (data['vendor'] != null &&
            data['vendor']['charges'] != null) {
          setState(() {
            charges =
            List<Map<String, dynamic>>.from(data['vendor']['charges']);
          });
        } else {
          print('Charges data is missing or invalid in the response.');
          setState(() {
            charges = []; // Reset charges if data is invalid
          });
        }
      } else {
        print(
            'Failed to load charges data. Status Code: ${response.statusCode}');
        setState(() {
          charges = []; // Reset charges on failure
        });
      }
    } catch (e) {
      print('Error fetching charges data: $e');
      setState(() {
        charges = []; // Reset charges on error
      });
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }

  void calculatePayableAmount(List<dynamic> charges, String vehicleType) {
    double amount = 0.0;
    final vehicleCharges = charges
        .where((charge) => charge['category'] == vehicleType)
        .toList();

    if (vehicleCharges.isNotEmpty) {
      var monthlyCharge = vehicleCharges
          .firstWhere((charge) => charge['type'] == 'Monthly', orElse: () => {});

      if (monthlyCharge.isNotEmpty) {
        amount += double.tryParse(monthlyCharge['amount'].toString()) ?? 0.0;
      }
    }

    setState(() {
      payableAmount = amount; // Update the payableAmount directly
    });
  }
  Future<List<VehicleBooking>> fetchBookingsAndCharges() async {
    try {
      List<VehicleBooking> bookings = await fetchBookings();
      await Future.wait(
          bookings.map((booking) => fetchChargesData(booking.vendorId, booking as String))
      );
      return bookings;
    } catch (e) {
      print('Error in fetchBookingsAndCharges: $e');
      rethrow;
    }
  }
  Future<List<VehicleBooking>> fetchBookings() async {
    final String url = "${ApiConfig.baseUrl}vendor/getbookinguserid/${widget.userid}";
    print("Fetching bookings from URL: $url");

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('error')) {
          print('Error from API: ${responseData['error']}');
          return [];
        }

        if (responseData['bookings'] is List) {
          List<dynamic> data = responseData['bookings'];
          if (data.isNotEmpty) {
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

  // Fetch payable amount for the booking
  Future<void> _fetchPayableAmount(String bookingId) async {
    final String url = "${ApiConfig.baseUrl}vendor/fet/$bookingId";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            payableAmount = double.tryParse(data['payableAmount'].toString()) ?? 0.0;
            // Extract spaceid and spacearea from API response
            spaceid = data['spaceid']?.toString();
            spacearea = data['spacearea']?.toString();
          });
        } else {
          print('Failed to fetch payable amount: ${data['message']}');
        }
      } else {
        print('Failed to load payable amount: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching payable amount: $error');
    }
  }

  // Calculate total amount with taxes
  double calculateTotalWithTaxes(double payableAmount) {
    // Use raw amounts; no per-component rounding
    double parkingCharge = payableAmount;
    double handlingFeeAmount = handlingFee;

    // GST on (amount + handling)
    double gstBase = parkingCharge + handlingFeeAmount;
    double gstAmount = (gstBase * gstPercentage) / 100;

    // Exact total, then round only the final payable amount
    double exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
    double roundedTotal = roundUpToNearestRupeeForExit(exactTotal);

    totalAmountWithTaxes = roundedTotal;
    return roundedTotal;
  }

  // Helper function to round to nearest rupee (0.5 or above rounds up)
  double roundUpToNearestRupeeForExit(double amount) {
    double decimal = amount - amount.floor();
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }

  // Parse parking date time string to DateTime for exit
  DateTime parseParkingDateTimeForExit(String dateTimeString) {
    try {
      final parts = dateTimeString.trim().split(' ');
      if (parts.length < 3) {
        return DateTime.parse(dateTimeString);
      }
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');

      int day = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);

      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      int second = 0;

      if (parts[2] == 'PM' && hour != 12) {
        hour += 12;
      } else if (parts[2] == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now();
    }
  }

  // Get payable duration from parked date/time
  Duration getPayableDurationForExit() {
    if (widget.parkeddate.isEmpty || widget.parkedtime.isEmpty) {
      return Duration.zero;
    }
    try {
      final parkingDateTime = parseParkingDateTimeForExit("${widget.parkeddate} ${widget.parkedtime}");
      final now = DateTime.now();
      final difference = now.difference(parkingDateTime);
      return difference.isNegative ? Duration.zero : difference;
    } catch (e) {
      print('Error calculating payable duration: $e');
      return Duration.zero;
    }
  }

  // Format duration as HH.MM.SS
  String formatDurationForExit(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours.$minutes.$seconds';
  }

  // Show exit confirmation bottom sheet
  void _showExitConfirmation() async {
    // Fetch GST and handling fee data only if it's a customer booking
    if (widget.userid.isNotEmpty) {
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

    // Create a ValueNotifier for the payable duration
    final durationNotifier = ValueNotifier<Duration>(getPayableDurationForExit());
      
      // Start a timer to update the duration every second
      Timer? durationTimer;
      durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          durationNotifier.value = getPayableDurationForExit();
        } else {
          timer.cancel();
        }
      });

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
        builder: (context) {
          // Cancel timer when bottom sheet is closed
          return WillPopScope(
            onWillPop: () async {
              durationTimer?.cancel();
              return true;
            },
            child: SafeArea(
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
                                durationTimer?.cancel();
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
                                  painter: RadialTicksPainterForExit(),
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
                                    ValueListenableBuilder<Duration>(
                                      valueListenable: durationNotifier,
                                      builder: (context, duration, child) {
                                        return Text(
                                          formatDurationForExit(duration),
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
                                        widget.bookedid.length > 8 ? widget.bookedid.substring(widget.bookedid.length - 8) : widget.bookedid,
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
                                        "${widget.parkingdate} ${widget.parkingtime}",
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
                                        _user?.username ?? '',
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
                                        _user?.mobileNumber ?? '',
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
                                        '${widget.sts} (${widget.bookingtype})',
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
                                        widget.userid.isEmpty ? 'Vendor' : 'Customer',
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
                    // Parking Charges (round ONLY payableAmount for exit)
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
                        Text(
                          "₹${roundUpToNearestRupeeForExit(payableAmount).toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (widget.userid.isNotEmpty) ...[
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
                        Text(
                          "₹${((payableAmount + handlingFee) * gstPercentage / 100).toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                              color: Colors.black,
                            ),
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
                        Text(
                          "₹${calculateTotalWithTaxes(payableAmount).toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 14 * MediaQuery.of(context).textScaleFactor,
                            color: ColorUtils.primarycolor(),
                            fontWeight: FontWeight.bold,
                          ),
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
                            durationTimer?.cancel();
                            Navigator.pop(context);
                            _navigateToPayment();
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
        },
      );
  }
  void _showTransactionDetailsBottomSheet() {
    if (_transactionDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction details not available')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Transaction Details",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Base Amount:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['amount']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
                  "Handling Fee:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['handlingfee']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
                  "GST:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['gst']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Amount:",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "₹${_transactionDetails!['totalAmount']}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

          ],
        ),
      ),
    );
  }
  // Navigate to payment page
  void _navigateToPayment() {
    // Round ONLY payableAmount (parking charge) for exit payment
    final parkingCharge = roundUpToNearestRupeeForExit(payableAmount);
    final gstBase = parkingCharge + handlingFee;
    final gstAmount = (gstBase * gstPercentage) / 100;
    final totalAmount = parkingCharge + gstAmount + handlingFee;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPayment(
          venodorname: widget.vendorname,
          vendorid: widget.vendorid,
          userid: widget.userid,
          mobilenumber:  _user?.username ?? '', // You may need to fetch this from user data
          vehicleid: widget.bookedid,
          amout: parkingCharge.toStringAsFixed(2),
          payableduration: '', // You may need to fetch or calculate this
          handlingfee: handlingFee.toStringAsFixed(2),
          gstfee: gstAmount.toStringAsFixed(2),
          totalamount: totalAmount.toStringAsFixed(2),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildDetailsTab(), // This allows the tab to take available space
          ),
        ],
      ),),
    );
  }

  Future<void> _generateInvoicePdf() async {
    final pdf = pw.Document();

    // Load Google Fonts for the PDF
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final logoImage = await rootBundle.load('assets/top.png');
    final logoImageBytes = logoImage.buffer.asUint8List();
    final pwImage = pw.MemoryImage(logoImageBytes);

    // Define date format for parsing widget.schedule
// Define readable date format
    final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    String fromDate = 'N/A';
    String toDate = 'N/A';

    try {
      if (isVendorShortParkingSts(widget.sts)) {
        // From: Parked date + time
        fromDate = '${widget.parkeddate}, ${widget.parkedtime}';
        // To: Exit date + time
        toDate = '${widget.exitdate ?? 'N/A'}, ${widget.exittime ?? ''}';
      } else if (isSubscriptionSts(widget.sts)) {
        // From: Parked date + time
        fromDate = '${widget.parkeddate}, ${widget.parkedtime}';
        // To: Subscription end date
        toDate = widget.subscriptionenddate ?? 'N/A';
      } else {
        // Fallback if sts unknown
        fromDate = '${widget.parkeddate}, ${widget.parkedtime}';
        toDate = widget.subscriptionenddate ?? 'N/A';
      }
    } catch (e) {
      print('Date formatting error: $e');
      fromDate = 'N/A';
      toDate = 'N/A';
    }


    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ParkMyWheels – Invoice',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 14,
                        color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Smart Parking Made Easy!',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side: Invoice Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice No: ${widget.invoiceid}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Date of Issue: ${DateTime.now().toString().split(' ')[0]}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Image
                  pw.Image(
                    pwImage,
                    width: 100,
                    height: 100,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer Details
              pw.Text(
                'Customer Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Customer Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Name: ${_user?.username ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Number: ${widget.vehiclenumber}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Type: ${widget.vehicletype}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Parking Location, Vendor, and Vendor Address
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Parking Location',
                        style: pw.TextStyle(font: font, fontSize: 14),
                      ),
                      pw.Text(
                        '${widget.vendorname ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Address: ${_vendor?.address ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Subscription Details
              pw.Text(
                'Subscription Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                    ),
                    children: [
                      for (var header in ['Description', 'Parked on', 'Exit on', 'Fees (₹)'])
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Center(
                            child: pw.Text(
                              header,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                color: PdfColor.fromInt(ColorUtils.whiteclr().value),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Data Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            'Monthly Parking Subscription',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            fromDate,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            toDate,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            _transactionDetails?['amount'] ?? '0.00',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: font, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total Payable
              pw.Text(
                'Total Payable',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Base Amount: ₹${_transactionDetails?['amount'] ?? '0.00'}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  // Only show Handling Fee if it's non-zero
                  if ((_transactionDetails?['handlingfee'] ?? '0') != '0' &&
                      double.tryParse(_transactionDetails?['handlingfee']?.toString() ?? '0') != 0.0)
                    pw.Text(
                      'Handling Fee: ₹${_transactionDetails?['handlingfee'] ?? '0.00'}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  // Only show GST if it's non-zero
                  if ((_transactionDetails?['gst'] ?? '0') != '0' &&
                      double.tryParse(_transactionDetails?['gst']?.toString() ?? '0') != 0.0)
                    pw.Text(
                      'GST: ₹${_transactionDetails?['gst'] ?? '0.00'}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  pw.Text(
                    'Total Amount (in INR): ₹${_transactionDetails?['totalAmount'] ?? '0.00'}',
                    style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Payment Details
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Mode of Payment: ${_transactionDetails != null ? 'Online' : 'N/A'}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                'Transaction ID: ${widget.bookedid}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Authorized Signature
              pw.Text(
                'Authorized Signature',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Digitally signed by ParkMyWheels',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                '(This is a computer-generated invoice and does not require a physical signature.)',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Column(
                children: [
                  pw.Text(
                    'Website: www.parkmywheels.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    'Email: parkmywheels3@gmail.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Display the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildDetailsTab() {
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 180.0,
        pinned: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_circle_left, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          _vendor?.vendorName ?? '',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 3,
                color: Colors.black.withOpacity(0.7),
              ),
            ],
          ),
        ),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax, // smooth scroll effect
          background: Stack(
            fit: StackFit.expand,
            children: [
              // --- Image Background ---
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: Image.network(
                  _vendor?.image ?? '',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: LoadingAnimationWidget.halfTriangleDot(
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: ColorUtils.primarycolor(),
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 40),
                      ),
                    );
                  },
                ),
              ),

              // --- Gradient Overlay (for better text contrast) ---
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vendor != null) ...[

              Column(
                children: [
                  Column(
                    children: [
                      Container(
                        // color: ColorUtils.primarycolor(),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ColorUtils
                              .primarycolor(), // Ensure the background color is set
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Aligns everything to the top
                          children: [
                            Expanded(
                              // Ensures the column takes only necessary space
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment
                                    .start, // Aligns text to the left
                                mainAxisSize: MainAxisSize
                                    .min, // Reduces extra space
                                children: [
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    child: Text(
                                      _vendor?.vendorName ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        height: 1.2,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 0), // Adjusted spacing
                                  Text(
                                    _vendor!.address,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        height: 1.2,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final double latitude =
                                          double.tryParse(
                                              _vendor?.latitude ??
                                                  '0') ??
                                              0.0;
                                      final double longitude =
                                          double.tryParse(
                                              _vendor?.longitude ??
                                                  '0') ??
                                              0.0;

                                      final String googleMapsUrl =
                                          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

                                      if (await canLaunch(
                                          googleMapsUrl)) {
                                        await launch(googleMapsUrl);
                                      } else {
                                        debugPrint(
                                            "Could not launch $googleMapsUrl");
                                      }
                                    },
                                    child: Container(
                                      height: 20,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(3),
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${_vendor?.distance != null ? _vendor!.distance?.toStringAsFixed(2) : 'N/A'} km',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.telegram,
                                              size: 16.0,
                                              color: Colors.blue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // const SizedBox(height: 5), // Reduced spacing
                    ],
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 10,
                            right: 0,
                            child: Container(
                              height: 190, // Set the appropriate height
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
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
                              child:  Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  if (widget.status != "COMPLETED" &&
                                      widget.status != "Cancelled") ...[
                                    Text(
                                      "OTP: ",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    ...(widget.otp.length >= 3
                                        ? (widget.status == 'PARKED'
                                        ? widget.otp
                                        .substring(widget.otp.length - 3)
                                        .split('')
                                        .map((digit) => _pinBox(digit))
                                        : widget.otp
                                        .substring(0, 3)
                                        .split('')
                                        .map((digit) => _pinBox(digit)))
                                        : [
                                      Text(
                                        "Invalid OTP ID",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    ])
                                  ],
                                  // Show "Book Again" button for completed or cancelled bookings
                                  if (widget.status == "COMPLETED" ||
                                      widget.status == "Cancelled")

                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ExploreBook(
                                                  vendorId: widget.vendorid,
                                                  userId: widget.userid,
                                                  vendorName:widget.vendorname,
                                                ),
                                          ),
                                        );
                                        print("Book Again pressed");
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: ColorUtils.primarycolor(),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        minimumSize: const Size(100, 10), // small button
                                      ),
                                      child: Text(
                                        "Book Again",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
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
                                      color: Colors.white,
                                      child: Align(
                                        alignment: Alignment.center, // Aligns content to the left
                                        child: Text(
                                          "Booking details",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            // decoration: TextDecoration.underline, // Add underline here
                                            decorationColor: Colors.black, // Optional: Set the color of the underline
                                            // Optional: Set the thickness of the underline
                                          ),
                                        ),
                                      ),
                                    ),
                                    Divider(
                                      thickness: 0.5, // Set the thickness of the divider
                                      color: ColorUtils.primarycolor(), // Set the color of the divider
                                    ),

                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.start,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        ClipPath(
                                          clipper: TicketClipper(),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(),
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  // decoration: BoxDecoration(
                                                  //   color: Colors.white,
                                                  //   borderRadius: BorderRadius.circular(16),
                                                  //   boxShadow: const [
                                                  //     BoxShadow(
                                                  //       color: Colors.black12,
                                                  //       blurRadius: 4,
                                                  //     ),
                                                  //   ],
                                                  // ),
                                                  padding:
                                                  const EdgeInsets.all(10),
                                                  child: PrettyQr(
                                                    data: widget.bookedid,
                                                    size: 100,
                                                    roundEdges: true,
                                                    errorCorrectLevel:
                                                    QrErrorCorrectLevel.H,
                                                    elementColor: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                            2), // Spacing between QR and details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [

                                              const SizedBox(
                                                  height:
                                                  13),
                                              Text(
                                                " ${widget.vehiclenumber.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 16),
                                              ),
                                              Text(
                                                "Booking date:${widget.bookeddate.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),
                                              Text(
                                                "Parking date:${widget.schedule.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),

                                              Text(
                                                "Status: ${widget.status.toString()},",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Text(
                                                  //   ": ${widget.sts}",
                                                  //   style: GoogleFonts.poppins(fontSize: 11),
                                                  // ),
                                                  Text(
                                                    "Booking Type: ${isSubscriptionSts(widget.sts) ? 'Monthly' : (widget.bookingtype == '24 Hours' ? 'Full Day' : 'Hourly')}",
                                                    style: GoogleFonts.poppins(fontSize: 11),
                                                  ),
                                                ],
                                              )

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
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Column(
                      children: [


                        const SizedBox(height: 15),
                        // Hide transaction details if status is PENDING/APPROVED/CANCELLED and spaceid is present
                        Builder(
                          builder: (context) {
                            // Debug print statements
                            print('🔍 Transaction Details Debug:');
                            print('   Status: "${widget.status.toString()}"');
                            print('   widget.spaceid: ${widget.spaceid}');
                            print('   widget.spaceid is null: ${widget.spaceid == null}');
                            print('   widget.spaceid is empty: ${widget.spaceid?.isEmpty ?? true}');
                            
                            final isPendingApprovedCancelled = widget.status.toString() == "PENDING" || 
                                                              widget.status.toString() == "Approved" || 
                                                              widget.status.toString() == "APPROVED" || 
                                                              widget.status.toString() == "Cancelled" || 
                                                              widget.status.toString() == "CANCELLED";
                            final hasSpaceid = widget.spaceid != null && widget.spaceid!.isNotEmpty;
                            final shouldHide = isPendingApprovedCancelled && hasSpaceid;
                            final shouldShow = widget.status.toString() == "COMPLETED" || 
                                             widget.status.toString() == "PARKED" || 
                                             (isSubscriptionSts(widget.sts) && _transactionDetails != null);
                            
                            print('   isPendingApprovedCancelled: $isPendingApprovedCancelled');
                            print('   hasSpaceid: $hasSpaceid');
                            print('   shouldHide: $shouldHide');
                            print('   shouldShow: $shouldShow');
                            print('   Final condition: ${!shouldHide && shouldShow}');
                            
                            if (!shouldHide && shouldShow) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                // color: Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 10,),
                                    Text(
                                      "Transaction details",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Spacer(),
                                    TextButton.icon(
                                      onPressed: _showTransactionDetailsBottomSheet,
                                      icon: Icon(
                                        Icons.remove_red_eye,
                                        color: ColorUtils.primarycolor(),
                                      ),
                                      label: Text(
                                        "View",
                                        style: TextStyle(
                                          color: ColorUtils.primarycolor(),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 10),
                        // Hide invoice if status is PENDING/APPROVED/CANCELLED and spaceid is present
                        Builder(
                          builder: (context) {
                            // Debug print statements for Invoice
                            print('🔍 Invoice Debug:');
                            print('   Status: "${widget.status.toString()}"');
                            print('   widget.spaceid: ${widget.spaceid}');
                            print('   widget.spaceid is null: ${widget.spaceid == null}');
                            print('   widget.spaceid is empty: ${widget.spaceid?.isEmpty ?? true}');
                            
                            final isPendingApprovedCancelled = widget.status.toString() == "PENDING" || 
                                                              widget.status.toString() == "Approved" || 
                                                              widget.status.toString() == "APPROVED" || 
                                                              widget.status.toString() == "Cancelled" || 
                                                              widget.status.toString() == "CANCELLED";
                            final hasSpaceid = widget.spaceid != null && widget.spaceid!.isNotEmpty;
                            final shouldHide = isPendingApprovedCancelled && hasSpaceid;
                            final shouldShow = widget.status.toString() == "COMPLETED" || 
                                             widget.status.toString() == "PARKED" || 
                                             (isSubscriptionSts(widget.sts) && _transactionDetails != null);
                            
                            print('   isPendingApprovedCancelled: $isPendingApprovedCancelled');
                            print('   hasSpaceid: $hasSpaceid');
                            print('   shouldHide: $shouldHide');
                            print('   shouldShow: $shouldShow');
                            print('   Final condition: ${!shouldHide && shouldShow}');
                            
                            if (!shouldHide && shouldShow) {
                              return Container(
                            decoration: BoxDecoration(
                              color: Colors.white, // Move color inside decoration
                              borderRadius: BorderRadius.circular(5), // Set border radius
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            // color: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 10,),
                                Text(
                                  "Invoice",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                TextButton.icon(
                                  onPressed: _transactionDetails == null
                                      ? null
                                      : () {
                                    _generateInvoicePdf();
                                  },
                                  icon: Icon(
                                    Icons.remove_red_eye,
                                    color: ColorUtils.primarycolor(),
                                  ),
                                  label: Text(
                                    "View",
                                    style: TextStyle(
                                      color: ColorUtils.primarycolor(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              ],
                            ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 15),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          // color: Colors.white,
                          child: Column(
                            children: [
                              const SizedBox(height: 5),
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Price details",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              // const SizedBox(height: 2),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal, // Enable horizontal scrolling
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center, // Center items inside Row
                                      children: List.generate(charges.length, (index) {
                                        var charge = charges[index];
                                        return Row(
                                          children: [
                                            Container(
                                              width: 85, // Set width for each item
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 6, horizontal: 4), // Reduce vertical padding
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    charge['type'],
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 1), // Reduce space between text
                                                  Text(
                                                    "₹${charge['amount']}",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (index < charges.length - 1)
                                              const SizedBox(
                                                width: 16, // Reduce spacing between items
                                                height: 35, // Set height to match container's height
                                                child: VerticalDivider(
                                                  color: Colors.grey,
                                                  thickness: 0.5,
                                                  width: 8, // Reduce space between items
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),


                        const SizedBox(height: 8),
    if (amenities.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
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
                            children: [
                              const SizedBox(height: 5),
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Facilities",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              //
                              Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 6.0,
                                  children: amenities.map((amenity) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        // color:  ColorUtils.primarycolor() ,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: Colors.black, // Set the color of the border
                                            width: 0.5, // Set the width of the border
                                          ),
                                          boxShadow: const [
                                            // BoxShadow(
                                            //   color: Colors.black26,
                                            //   blurRadius: 4.0,
                                            //   offset: Offset(0, 2),
                                            // ),
                                          ]),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getAmenityIcon(amenity),
                                            size: 12,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            amenity,
                                            style: GoogleFonts.poppins(
                                              color: Colors.black,
                                              fontSize: 12,
                                              // fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                          ),
                        ),
],
                        const SizedBox(height: 8),
    if (services.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
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
                            children: [

                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Additional Services",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              const SizedBox(height: 8),
                              // Heading Card


                              // Loop through the services list
                              Wrap(
                                spacing: 6.0,
                                runSpacing: 6.0,
                                children: services.asMap().entries.map((entry) {
                                  final s = entry.value;

                                  return Container(
                                    // width: 100, // Adjust width as needed
                                    padding: const EdgeInsets.all(5.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black, width: 0.5),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.type,
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          ": ₹${s.amount}",
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
],
                        // Add more widgets as needed
                        // Google Map
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            // color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          // color: Colors.white,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5),
                                child: Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    // border:
                                    //     Border.all(color: Colors.grey),
                                    borderRadius:
                                    BorderRadius.circular(5.0),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(5.0),
                                    child: GoogleMap(
                                      initialCameraPosition:
                                      CameraPosition(
                                        target: LatLng(
                                          double.tryParse(
                                              _vendor?.latitude ??
                                                  '0') ??
                                              0.0, // Convert latitude to double
                                          double.tryParse(
                                              _vendor?.longitude ??
                                                  '0') ??
                                              0.0,
                                        ),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId(
                                              'vendor_location'),
                                          position: LatLng(
                                            double.tryParse(
                                                _vendor?.latitude ??
                                                    '0') ??
                                                0.0, // Convert latitude to double
                                            double.tryParse(
                                                _vendor?.longitude ??
                                                    '0') ??
                                                0.0,
                                          ),
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              if (widget.status.toString() == "PARKED" && widget.nav == "monthly")
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: payableAmount == 0.0
                                      ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          ColorUtils.primarycolor()),
                                    ),
                                  )
                                      : (spaceid != null && spaceid!.isNotEmpty)
                                          ? const SizedBox.shrink() // Hide button if spaceid is present
                                          : SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _showExitConfirmation();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        minimumSize: const Size(0, 0),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.all(Radius.circular(5)),
                                          side: BorderSide(
                                            color: Colors.red,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.qr_code_scanner,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Exit',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              // const SizedBox(height: 100,)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),

            ],
          ],
        ),
      ),
    ]);
  }
}





class vendorParkingDetails extends StatefulWidget {
  final String vehiclenumber;
  final String invoiceid;
  final String vendorname;
  final String vendorid;
  final String parkingdate;
  final String parkingtime;
  final String bookedid;
  final String schedule;
  final String bookeddate;
  final String vehicletype;
  final String status;
  final String otp;
  final String bookingtype;
  final String sts;
  final String mobilenumber;
  final String username;
  final String invoice;
  final String amount;
  final String totalamount;
  final String parkeddate;
  final String parkedtime;
  final String subscriptionenddate;
  final String exitdate;
  final String exittime;


  const vendorParkingDetails({
    super.key,
    required this.invoiceid,
    required this.username,
    required this.bookedid,
    required this.schedule,
    required this.amount,
    required this.totalamount,
    required this.bookeddate,
    required this.vehiclenumber,
    required this.vendorname,
    required this.vendorid,
    required this.parkingdate,
    required this.parkingtime,
    required this.invoice,
    required this.vehicletype,
    required this .status,
    required this.bookingtype,
    required this.sts,
    required this.otp,
    required this.mobilenumber, required this.parkeddate, required this.parkedtime, required this.subscriptionenddate, required this.exitdate, required this.exittime,
  });

  @override
  _vParkingDetailsState createState() => _vParkingDetailsState();
}

class _vParkingDetailsState extends State<vendorParkingDetails> {

  bool isLoading = false;
  bool _locationDenied = false;
  List<dynamic> charges = [];
  bool _locationPermanentlyDenied = false;
  late Position _currentPosition;
  List<String> favoriteVendorIds = [];
  List<String> amenities = []; // Add your amenities list
  List<Services> services = []; // Add your services list
  int selectedTabIndex = 0; // Track selected tab index
  double containerHeight = 500.0; // Define the containerHeight variable
  Map<String, dynamic>? _transactionDetails; // Store transaction details

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case "open parking":
        return Icons.local_parking;
      case "gated parking":
        return Icons.lock;
      case "charging":
        return Icons.electric_car;
      case "covered parking":
        return Icons.garage;
      case "cctv":
        return Icons.videocam;
      case "atms":
        return Icons.atm;
      case "wi-fi":
        return Icons.wifi;
      case "self car wash":
        return Icons.local_car_wash;
      case "restroom":
        return Icons.wc;
      case "security":
        return Icons.security;
      default:
        return Icons.help_outline; // Default icon for unknown amenities
    }
  }

  Vendor? _vendor;
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _fetchTransactionDetails();
    fetchChargesData(widget.vendorid, widget.vehicletype);
    // Ensure vendor ID is not null before fetching amenities and parking
    if (_vendor?.id != null) {
      fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
        setState(() {
          amenities = amenitiesAndParking
              .amenities; // Update the state with fetched amenities
          services = amenitiesAndParking
              .services; // Update the state with fetched services
        });
        // Print the amenities and services after fetching
        print('Fetched Amenities: $amenities');
        print('Fetched Services: $services');
      }).catchError((error) {
        print('Error fetching amenities: $error'); // Debugging print statement
      });
    }
    _fetchVendorData();
  }

  Future<void> fetchChargesData(String vendorId, String selectedCarType) async {
    setState(() {
      isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchbookcharge/$vendorId/$selectedCarType'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response Data: $data');

        // Check if the response contains the expected charges list
        if (data is List) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data);
          });
        } else if (data['vendor'] != null &&
            data['vendor']['charges'] != null) {
          setState(() {
            charges =
            List<Map<String, dynamic>>.from(data['vendor']['charges']);
          });
        } else {
          print('Charges data is missing or invalid in the response.');
          setState(() {
            charges = []; // Reset charges if data is invalid
          });
        }
      } else {
        print(
            'Failed to load charges data. Status Code: ${response.statusCode}');
        setState(() {
          charges = []; // Reset charges on failure
        });
      }
    } catch (e) {
      print('Error fetching charges data: $e');
      setState(() {
        charges = []; // Reset charges on error
      });
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (_vendor != null) {
        double distance = haversineDistance(
          _currentPosition.latitude,
          _currentPosition.longitude,
          double.tryParse(_vendor!.latitude) ?? 0.0,
          double.tryParse(_vendor!.longitude) ?? 0.0,
        );
        setState(() {
          _vendor!.distance = distance; // Now this will work
        });
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    final url =
    Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check if the response contains the expected structure
        if (data['AmenitiesData'] != null) {
          // Print the fetched amenities data
          print('Fetched Amenities Data: ${data['AmenitiesData']}');
          return AmenitiesAndParking.fromJson(data);
        } else {
          throw Exception('AmenitiesData is null in response');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      setState(() {
        _locationDenied = true;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _locationPermanentlyDenied = true;
      });
    }
  }

  String apiUrl = '${ApiConfig.baseUrl}vendor/fetch-all-vendor-data';

// Function to fetch vendor data
  Future<List<Map<String, dynamic>>> fetchVendors() async {
    setState(() {
      isLoading = true; // Set loading to true while fetching data
    });
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['data'] != null) {
          return (jsonResponse['data'] as List).map((vendor) {
            double? latitude;
            double? longitude;

            // Attempt to parse latitude and longitude
            try {
              latitude = double.tryParse(
                  vendor['latitude'] ?? '0.0'); // Use '0.0' as default
              longitude = double.tryParse(
                  vendor['longitude'] ?? '0.0'); // Use '0.0' as default
            } catch (e) {
              print('Error parsing latitude/longitude: $e');
            }

            return {
              'id': vendor['_id'] ?? '',
              'name': vendor['vendorName'] ??
                  'Unknown Vendor', // Default name if null
              'latitude': latitude ?? 0.0, // Default to 0.0 if parsing fails
              'longitude': longitude ?? 0.0, // Default to 0.0 if parsing fails
              'image': vendor['image'] ?? '', // Default to empty string if null
              'address':
              vendor['address'] ?? 'No Address', // Default address if null
              'contactNo': vendor['contactNo'] ??
                  'No Contact', // Default contact if null
              'landMark': vendor['landMark'] ??
                  'No Landmark', // Default landmark if null
            };
          }).toList();
        } else {
          print('No vendor data found');
          return [];
        }
      } else {
        print('Failed to load vendors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      return [];
    } finally {
      setState(() {
        isLoading = false; // Set loading to false once the data is fetched
      });
    }
  }

  /// Fallback transaction details from widget when API fails (vendorParkingDetails).
  Map<String, dynamic> _defaultTransactionDetails() {
    final isSubscription = isSubscriptionSts(widget.sts);
    final totalAmt = widget.totalamount ?? '0';
    return {
      'amount': isSubscription ? totalAmt : (widget.amount ?? '0'),
      'gst': '0',
      'handlingfee': '0',
      'totalAmount': totalAmt,
      'personName': widget.username ?? '',
      'mobileNumber': widget.mobilenumber ?? '',
      'parkedDate': widget.parkeddate ?? '',
      'parkedTime': widget.parkedtime ?? '',
      'subscriptionenddate': widget.subscriptionenddate ?? '',
      'exitdate': widget.exitdate ?? '',
      'exittime': widget.exittime ?? '',
      'invoiceid': widget.invoiceid ?? '',
      'invoice': widget.invoice ?? '',
      'vendorName': widget.vendorname ?? '',
      'vehicleNumber': widget.vehiclenumber ?? '',
      'vehicleType': widget.vehicletype ?? '',
      'sts': widget.sts ?? '',
    };
  }

  Future<Map<String, dynamic>> fetchAmountDetailsByBookingId(String bookingId) async {
    try {
      final isSubscription = isSubscriptionSts(widget.sts);
      final url = isSubscription
          ? '${ApiConfig.baseUrl}vendor/fetchbookid/$bookingId'
          : '${ApiConfig.baseUrl}vendor/getbooking/$bookingId';
      print('Fetching booking details for ID: $bookingId (${isSubscription ? "fetchbookid" : "getbooking"})');

      final response = await http.get(
        Uri.parse(url),
      );
          print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 404) {
        print('Booking not found (404) for ID: ${widget.bookedid}');
        throw Exception('Booking not found');
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is! Map) {
          return _defaultTransactionDetails();
        }

        // Accept multiple response shapes: message/data, success/data, or data at root
        Map<String, dynamic>? data = jsonResponse['data'] != null
            ? Map<String, dynamic>.from(jsonResponse['data'] as Map)
            : null;
        if (data == null && jsonResponse['booking'] != null) {
          data = Map<String, dynamic>.from(jsonResponse['booking'] as Map);
        }
        if (data == null) {
          data = Map<String, dynamic>.from(jsonResponse as Map);
        }

        final d = data!;
        final amount = d['amount']?.toString() ?? widget.amount ?? '0';
        final gst = d['gstamout']?.toString() ?? '0';
        final totalAmount = d['totalamout']?.toString() ?? widget.totalamount ?? '0';
        final handlingFee = d['handlingfee']?.toString() ?? '0';
        final personName = d['personName']?.toString() ?? widget.username ?? '';
        final mobileNumber = d['mobileNumber']?.toString() ?? widget.mobilenumber ?? '';
        final parkedDate = d['parkedDate']?.toString() ?? d['parkingDate']?.toString() ?? widget.parkeddate ?? '';
        final parkedTime = d['parkedTime']?.toString() ?? d['parkingTime']?.toString() ?? widget.parkedtime ?? '';
        final subscriptionenddate = d['subsctiptionenddate']?.toString() ?? widget.subscriptionenddate ?? '';
        final exitdate = d['exitvehicledate']?.toString() ?? d['exitdate']?.toString() ?? widget.exitdate ?? '';
        final exittime = d['exitvehicletime']?.toString() ?? d['exittime']?.toString() ?? widget.exittime ?? '';
        final invoiceid = d['invoiceid']?.toString() ?? widget.invoiceid ?? '';
        final invoice = d['invoice']?.toString() ?? widget.invoice ?? '';
        final vendorName = d['vendorName']?.toString() ?? widget.vendorname ?? '';
        final vehicleNumber = d['vehicleNumber']?.toString() ?? widget.vehiclenumber ?? '';
        final vehicleType = d['vehicleType']?.toString() ?? widget.vehicletype ?? '';
        final sts = d['sts']?.toString() ?? widget.sts ?? '';

        // For subscription, show total amount everywhere (fees, total amount, total payable)
        final isSubscription = isSubscriptionSts(sts);
        final effectiveAmount = isSubscription ? totalAmount : amount;

        return {
          'amount': effectiveAmount,
          'gst': gst,
          'handlingfee': handlingFee,
          'totalAmount': totalAmount,
          'personName': personName,
          'mobileNumber': mobileNumber,
          'parkedDate': parkedDate,
          'parkedTime': parkedTime,
          'subscriptionenddate': subscriptionenddate,
          'exitdate': exitdate,
          'exittime': exittime,
          'invoiceid': invoiceid,
          'invoice': invoice,
          'vendorName': vendorName,
          'vehicleNumber': vehicleNumber,
          'vehicleType': vehicleType,
          'sts': sts,
        };
      } else {
        return _defaultTransactionDetails();
      }
    } catch (e) {
      print('Exception occurred: $e');
      // Rethrow so _fetchTransactionDetails can show "Booking not found" SnackBar
      if (e is Exception && e.toString().contains('Booking not found')) {
        rethrow;
      }
      return _defaultTransactionDetails();
    }
  }

  Future<Map<String, dynamic>> fetchGstData() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        return Map<String, dynamic>.from(data[0] as Map);
      } else if (data is Map) {
        return Map<String, dynamic>.from(data);
      } else {
        throw Exception('Unexpected data format');
      }
    } else {
      throw Exception('Failed to load GST data');
    }
  }

  Future<void> _fetchTransactionDetails() async {
    print('Starting _fetchTransactionDetails for bookingId: ${widget.bookedid}');

    try {
      final transactionData = await fetchAmountDetailsByBookingId(widget.bookedid);

      print('API call successful');
      print('Received transaction data: $transactionData');

      if (!mounted) {
        print('Widget is not mounted, returning without setState');
        return;
      }

      setState(() {
        _transactionDetails = transactionData;
      });

      print('Transaction details updated in state');

    } catch (e) {
      print('Error fetching transaction details: $e');

      if (!mounted) {
        print('Widget is not mounted in catch block');
        return;
      }

      setState(() {
        _transactionDetails = _defaultTransactionDetails();
      });

      final isNotFound = e is Exception && e.toString().contains('Booking not found');
      print(isNotFound ? 'Booking not found, showing fallback' : 'Default transaction details loaded');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNotFound
                ? 'Booking not found. Showing saved transaction amounts.'
                : 'Showing saved transaction amounts.',
          ),
        ),
      );
    }
  }

  Future<void> _generateInvoicePdf() async {
    final pdf = pw.Document();

    // Load Google Fonts for the PDF
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final logoImage = await rootBundle.load('assets/top.png');
    final logoImageBytes = logoImage.buffer.asUint8List();
    final pwImage = pw.MemoryImage(logoImageBytes);

    // Helper function to get display-friendly booking type (uses API data when available)
    String getBookingTypeDisplay() {
      final sts = (_transactionDetails?['sts']?.toString() ?? widget.sts ?? '').trim();
      if (sts.isEmpty || sts == 'N/A' || sts.toLowerCase() == 'null') return 'N/A';
      if (widget.bookingtype == '24 Hours') return 'Full Day';
      return sts;
    }

    // For subscription: fees, total amount and total payable all show total amount
    final invoiceSts = (_transactionDetails?['sts']?.toString() ?? widget.sts ?? '').trim().toLowerCase();
    final isSubscriptionInvoice = isSubscriptionSts(invoiceSts);
    final invoiceTotalAmount = _transactionDetails?['totalAmount']?.toString() ?? widget.totalamount ?? '0.00';
    final invoiceFeesAndBaseAmount = isSubscriptionInvoice ? invoiceTotalAmount : (_transactionDetails?['amount']?.toString() ?? widget.amount ?? '0.00');

    // Define date format for parsing widget.schedule
    // Define readable date format
    final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    String fromDate = 'N/A';
    String toDate = 'N/A';

    final parkedDate = (_transactionDetails?['parkedDate']?.toString() ?? widget.parkeddate ?? '').trim();
    final parkedTime = (_transactionDetails?['parkedTime']?.toString() ?? widget.parkedtime ?? '').trim();
    final subEndDate = (_transactionDetails?['subscriptionenddate']?.toString() ?? widget.subscriptionenddate ?? '').trim();
    final exitDate = (_transactionDetails?['exitdate']?.toString() ?? widget.exitdate ?? '').trim();
    final exitTime = (_transactionDetails?['exittime']?.toString() ?? widget.exittime ?? '').trim();

    try {
      if (isVendorShortParkingSts(widget.sts)) {
        fromDate = (parkedDate.isNotEmpty && parkedTime.isNotEmpty)
            ? '$parkedDate, $parkedTime'
            : ((widget.parkeddate ?? '').trim().isNotEmpty ? '${widget.parkeddate}, ${widget.parkedtime}' : 'N/A');
        toDate = (exitDate.isNotEmpty || exitTime.isNotEmpty)
            ? '$exitDate, $exitTime'
            : ((widget.exitdate ?? '').trim().isNotEmpty ? '${widget.exitdate}, ${widget.exittime}' : 'N/A');
      } else if (isSubscriptionSts(widget.sts)) {
        fromDate = (parkedDate.isNotEmpty && parkedTime.isNotEmpty)
            ? '$parkedDate, $parkedTime'
            : ((widget.parkeddate ?? '').trim().isNotEmpty ? '${widget.parkeddate}, ${widget.parkedtime}' : 'N/A');
        toDate = subEndDate.isNotEmpty ? subEndDate : ((widget.subscriptionenddate ?? '').trim().isNotEmpty ? (widget.subscriptionenddate ?? 'N/A') : 'N/A');
      } else {
        fromDate = (parkedDate.isNotEmpty && parkedTime.isNotEmpty)
            ? '$parkedDate, $parkedTime'
            : ((widget.parkeddate ?? '').trim().isNotEmpty ? '${widget.parkeddate}, ${widget.parkedtime}' : 'N/A');
        toDate = subEndDate.isNotEmpty ? subEndDate : ((widget.subscriptionenddate ?? '').trim().isNotEmpty ? (widget.subscriptionenddate ?? 'N/A') : 'N/A');
      }
    } catch (e) {
      print('Date formatting error: $e');
      fromDate = 'N/A';
      toDate = 'N/A';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ParkMyWheels – Parking Invoice',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 14,
                        color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Smart Parking Made Easy!',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side: Invoice Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice No: ${(() {
                          final id = (_transactionDetails?['invoiceid']?.toString() ?? widget.invoiceid ?? '').trim();
                          return (id.isEmpty || id == 'N/A') ? widget.bookedid : id;
                        })()}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Date of Issue: ${DateTime.now().toString().split(' ')[0]}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Image
                  pw.Image(
                    pwImage,
                    width: 100,
                    height: 100,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer Details
              pw.Text(
                'Customer Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Customer Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Name: ${((_transactionDetails?['personName']?.toString() ?? widget.username ?? '').trim().isEmpty ? 'N/A' : (_transactionDetails?['personName']?.toString() ?? widget.username ?? 'N/A').trim())}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Number: ${(_transactionDetails?['vehicleNumber']?.toString() ?? widget.vehiclenumber ?? '').trim().isEmpty ? 'N/A' : (_transactionDetails?['vehicleNumber'] ?? widget.vehiclenumber ?? 'N/A')}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vehicle Type: ${(_transactionDetails?['vehicleType']?.toString() ?? widget.vehicletype ?? '').trim().isEmpty ? 'N/A' : (_transactionDetails?['vehicleType'] ?? widget.vehicletype ?? 'N/A')}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  // Right side: Parking Location, Vendor, and Vendor Address
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Parking Location',
                        style: pw.TextStyle(font: font, fontSize: 14),
                      ),
                      pw.Text(
                        '${(_transactionDetails?['vendorName']?.toString() ?? widget.vendorname ?? '').trim().isEmpty ? 'N/A' : (_transactionDetails?['vendorName'] ?? widget.vendorname ?? 'N/A')}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Address: ${_vendor?.address ?? 'N/A'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Subscription Details
              pw.Text(
                'Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(ColorUtils.primarycolor().value),
                    ),
                    children: [
                      for (var header in ['Description', 'Parked on', 'Exit on', 'Fees (₹)'])
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Center(
                            child: pw.Text(
                              header,
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 12,
                                color: PdfColor.fromInt(ColorUtils.whiteclr().value),
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Data Row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            getBookingTypeDisplay(),
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            fromDate,
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            toDate,
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Text(
                            invoiceFeesAndBaseAmount,
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total Payable
              pw.Text(
                'Total Payable',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Base Amount: ₹$invoiceFeesAndBaseAmount',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              // Only show Handling Fee if it's non-zero and not subscription
              if (!isSubscriptionInvoice && (_transactionDetails?['handlingfee'] ?? '0') != '0' &&
                  double.tryParse(_transactionDetails?['handlingfee']?.toString() ?? '0') != 0.0)
                pw.Text(
                  'Handling Fee: ₹${_transactionDetails?['handlingfee'] ?? '0.00'}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              // Only show GST if it's non-zero and not subscription
              if (!isSubscriptionInvoice && (_transactionDetails?['gst'] ?? '0') != '0' &&
                  double.tryParse(_transactionDetails?['gst']?.toString() ?? '0') != 0.0)
                pw.Text(
                  'GST: ₹${_transactionDetails?['gst'] ?? '0.00'}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              pw.Text(
                'Total Amount (in INR): ₹$invoiceTotalAmount',
                style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 20),

              // Payment Details
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Mode of Payment: ${(() {
                  final inv = (_transactionDetails?['invoice']?.toString() ?? widget.invoice ?? '').trim();
                  return (inv.isNotEmpty && inv != 'N/A') ? 'Online' : 'Cash';
                })()}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),

              pw.Text(
                'Transaction ID: ${(() {
                  final inv = (_transactionDetails?['invoice']?.toString() ?? widget.invoice ?? '').trim();
                  return (inv.isEmpty || inv == 'N/A') ? widget.bookedid : inv;
                })()}',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Authorized Signature
              pw.Text(
                'Authorized Signature',
                style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Digitally signed by ParkMyWheels',
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
              pw.Text(
                '(This is a computer-generated invoice and does not require a physical signature.)',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Column(
                children: [
                  pw.Text(
                    'Website: www.parkmywheels.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    'Email: parkmywheels3@gmail.com',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Display the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _fetchVendorData() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            isLoading = false; // Hide loading indicator after data is fetched
          });

          // Now that _vendor is initialized, fetch amenities and parking
          fetchAmenitiesAndParking(_vendor!.id).then((amenitiesAndParking) {
            setState(() {
              amenities = amenitiesAndParking
                  .amenities; // Update the state with fetched amenities
              services = amenitiesAndParking
                  .services; // Update the state with fetched services
            });
          }).catchError((error) {
            print(
                'Error fetching amenities: $error'); // Debugging print statement
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
            'Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildDetailsTab(), // This allows the tab to take available space
          ),
        ],
      ),),
    );
  }

  Widget _buildDetailsTab() {
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 180.0,
        pinned: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_circle_left, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          _vendor?.vendorName ?? '',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 3,
                color: Colors.black.withOpacity(0.7),
              ),
            ],
          ),
        ),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax, // smooth scroll effect
          background: Stack(
            fit: StackFit.expand,
            children: [
              // --- Image Background ---
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: Image.network(
                  _vendor?.image ?? '',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: LoadingAnimationWidget.halfTriangleDot(
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: ColorUtils.primarycolor(),
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 40),
                      ),
                    );
                  },
                ),
              ),

              // --- Gradient Overlay (for better text contrast) ---
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vendor != null) ...[

              Column(
                children: [
                  Column(
                    children: [
                      Container(
                        // color: ColorUtils.primarycolor(),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ColorUtils
                              .primarycolor(), // Ensure the background color is set
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Aligns everything to the top
                          children: [
                            Expanded(
                              // Ensures the column takes only necessary space
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment
                                    .start, // Aligns text to the left
                                mainAxisSize: MainAxisSize
                                    .min, // Reduces extra space
                                children: [
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    child: Text(
                                      _vendor?.vendorName ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        height: 1.2,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 0), // Adjusted spacing
                                  Text(
                                    _vendor!.address,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        height: 1.2,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final double latitude =
                                          double.tryParse(
                                              _vendor?.latitude ??
                                                  '0') ??
                                              0.0;
                                      final double longitude =
                                          double.tryParse(
                                              _vendor?.longitude ??
                                                  '0') ??
                                              0.0;

                                      final String googleMapsUrl =
                                          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

                                      if (await canLaunch(
                                          googleMapsUrl)) {
                                        await launch(googleMapsUrl);
                                      } else {
                                        debugPrint(
                                            "Could not launch $googleMapsUrl");
                                      }
                                    },
                                    child: Container(
                                      height: 20,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(3),
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${_vendor?.distance != null ? _vendor!.distance?.toStringAsFixed(2) : 'N/A'} km',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.telegram,
                                              size: 16.0,
                                              color: Colors.blue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // const SizedBox(height: 5), // Reduced spacing
                    ],
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: SizedBox(
                      height: 200,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 10,
                            right: 0,
                            child: Container(
                              height: 190, // Set the appropriate height
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
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
                              child:  const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                    


                                ],
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
                                      color: Colors.white,
                                      child: Align(
                                        alignment: Alignment.center, // Aligns content to the left
                                        child: Text(
                                          "Booking details",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            // decoration: TextDecoration.underline, // Add underline here
                                            decorationColor: Colors.black, // Optional: Set the color of the underline
                                            // Optional: Set the thickness of the underline
                                          ),
                                        ),
                                      ),
                                    ),
                                    Divider(
                                      thickness: 0.5, // Set the thickness of the divider
                                      color: ColorUtils.primarycolor(), // Set the color of the divider
                                    ),
                                    // Container(
                                    // padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                    // decoration: BoxDecoration(
                                    // border: Border(
                                    // bottom: BorderSide(
                                    // color: ColorUtils.primarycolor(), // Replace with ColorUtils.primarycolor()
                                    // width: 0.5,
                                    // ),
                                    // ),
                                    // borderRadius: const BorderRadius.only(
                                    // topLeft: Radius.circular(5.0),
                                    // topRight: Radius.circular(5.0),
                                    // ),
                                    // ),
                                    // child: Row(
                                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    // children: [
                                    //   Padding(
                                    //     padding: const EdgeInsets.only(right: 12.0),
                                    //     child: Text(
                                    //       widget.vehiclenumber,
                                    //       style: GoogleFonts.poppins(
                                    //         color:ColorUtils.primarycolor(),
                                    //         fontWeight: FontWeight.bold,
                                    //       ),
                                    //     ),
                                    //   ),
                                    // const Spacer(),
                                    // Padding(
                                    // padding: const EdgeInsets.only(right: 12.0),
                                    // child: Text(
                                    // widget.status,
                                    // style: GoogleFonts.poppins(
                                    // color:ColorUtils.primarycolor(),
                                    // fontWeight: FontWeight.bold,
                                    // ),
                                    // ),
                                    // ),
                                    //
                                    // ],
                                    // ),
                                    // ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.start,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        ClipPath(
                                          clipper: TicketClipper(),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(),
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  // decoration: BoxDecoration(
                                                  //   color: Colors.white,
                                                  //   borderRadius: BorderRadius.circular(16),
                                                  //   boxShadow: const [
                                                  //     BoxShadow(
                                                  //       color: Colors.black12,
                                                  //       blurRadius: 4,
                                                  //     ),
                                                  //   ],
                                                  // ),
                                                  padding:
                                                  const EdgeInsets.all(10),
                                                  child: PrettyQr(
                                                    data: widget.vehiclenumber,
                                                    size: 100,
                                                    roundEdges: true,
                                                    errorCorrectLevel:
                                                    QrErrorCorrectLevel.H,
                                                    elementColor: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                            2), // Spacing between QR and details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [

                                              const SizedBox(
                                                  height:
                                                  13),
                                              Text(
                                                " ${widget.vehiclenumber.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 16),
                                              ),
                                              Text(
                                                "Booking date:${widget.bookeddate.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),
                                              Text(
                                                "Parking date:${widget.schedule.toString()}",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),

                                              Text(
                                                "Status: ${widget.status.toString()},",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),
                                              Text(
                                                "Mobilenumber: ${((_transactionDetails?['mobileNumber']?.toString() ?? widget.mobilenumber ?? '').trim().isEmpty ? 'N/A' : (_transactionDetails?['mobileNumber']?.toString() ?? widget.mobilenumber ?? 'N/A').trim())}",
                                                style: GoogleFonts.poppins(fontSize: 11),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Text(
                                                  //   ": ${widget.sts}",
                                                  //   style: GoogleFonts.poppins(fontSize: 11),
                                                  // ),
                                                  Text(
                                                    "Booking Type: ${isSubscriptionSts(widget.sts) ? 'Monthly' : (widget.bookingtype == '24 Hours' ? 'Full Day' : 'Hourly')}",
                                                    style: GoogleFonts.poppins(fontSize: 11),
                                                  ),
                                                ],
                                              )

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
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Column(
                      children: [


                        const SizedBox(height: 15),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          // color: Colors.white,
                          child: Column(
                            children: [
                              const SizedBox(height: 5),
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Price details",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              // const SizedBox(height: 2),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal, // Enable horizontal scrolling
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center, // Center items inside Row
                                      children: List.generate(charges.length, (index) {
                                        var charge = charges[index];
                                        return Row(
                                          children: [
                                            Container(
                                              width: 85, // Set width for each item
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 6, horizontal: 4), // Reduce vertical padding
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    charge['type'],
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 1), // Reduce space between text
                                                  Text(
                                                    "₹${charge['amount']}",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (index < charges.length - 1)
                                              const SizedBox(
                                                width: 16, // Reduce spacing between items
                                                height: 35, // Set height to match container's height
                                                child: VerticalDivider(
                                                  color: Colors.grey,
                                                  thickness: 0.5,
                                                  width: 8, // Reduce space between items
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // if (widget.status.toString() == "COMPLETED")

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white, // Move color inside decoration
                              borderRadius: BorderRadius.circular(5), // Set border radius
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            // color: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 10,),
                                Text(
                                  "Invoice",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                TextButton.icon(
                                  onPressed: _transactionDetails == null
                                      ? null
                                      : () {
                                    _generateInvoicePdf();
                                  },
                                  icon: Icon(
                                    Icons.remove_red_eye,
                                    color: ColorUtils.primarycolor(),
                                  ),
                                  label: Text(
                                    "View",
                                    style: TextStyle(
                                      color: ColorUtils.primarycolor(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),


                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
    if (amenities.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
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
                            children: [
                              const SizedBox(height: 5),
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Facilities",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              //
                              Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 6.0,
                                  children: amenities.map((amenity) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        // color:  ColorUtils.primarycolor() ,
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: Colors.black, // Set the color of the border
                                            width: 0.5, // Set the width of the border
                                          ),
                                          boxShadow: const [
                                            // BoxShadow(
                                            //   color: Colors.black26,
                                            //   blurRadius: 4.0,
                                            //   offset: Offset(0, 2),
                                            // ),
                                          ]),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getAmenityIcon(amenity),
                                            size: 12,
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            amenity,
                                            style: GoogleFonts.poppins(
                                              color: Colors.black,
                                              fontSize: 12,
                                              // fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                          ),
                        ),
],
                        const SizedBox(height: 8),
    if (services.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
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
                            children: [

                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Additional Services",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              const SizedBox(height: 8),
                              // Heading Card


                              // Loop through the services list
                              Wrap(
                                spacing: 6.0,
                                runSpacing: 6.0,
                                children: services.asMap().entries.map((entry) {
                                  final s = entry.value;

                                  return Container(
                                    // width: 100, // Adjust width as needed
                                    padding: const EdgeInsets.all(5.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black, width: 0.5),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.type,
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          ": ₹${s.amount}",
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
],
                        // Add more widgets as needed
                        // Google Map
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            // color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          // color: Colors.white,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5),
                                child: Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    // border:
                                    //     Border.all(color: Colors.grey),
                                    borderRadius:
                                    BorderRadius.circular(5.0),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(5.0),
                                    child: GoogleMap(
                                      initialCameraPosition:
                                      CameraPosition(
                                        target: LatLng(
                                          double.tryParse(
                                              _vendor?.latitude ??
                                                  '0') ??
                                              0.0, // Convert latitude to double
                                          double.tryParse(
                                              _vendor?.longitude ??
                                                  '0') ??
                                              0.0,
                                        ),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId(
                                              'vendor_location'),
                                          position: LatLng(
                                            double.tryParse(
                                                _vendor?.latitude ??
                                                    '0') ??
                                                0.0, // Convert latitude to double
                                            double.tryParse(
                                                _vendor?.longitude ??
                                                    '0') ??
                                                0.0,
                                          ),
                                        ),
                                      },
                                    ),
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            ],
          ],
        ),
      ),
    ]);
  }

}

Widget _buildDetailRow(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

Widget _pinBox(String number) {
  return Container(
    height: 20, // Adjust height for better visibility
    width: 20, // Adjust width for better visibility
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black, width: 0.5),// White background
      borderRadius: BorderRadius.circular(5), // Rounded corners
      boxShadow: [
        BoxShadow(

          color: Colors.black.withOpacity(0.1), // Shadow color
          blurRadius: 4, // Shadow blur radius
          offset: const Offset(0, 2), // Shadow offset
        ),
      ],
    ),
    alignment: Alignment.center, // Center the text within the box
    child: Text(
      number,
      style: GoogleFonts.poppins(
        fontSize: 12,
        height: 1.0,// Increased font size for better visibility
        color: Colors.black, // Black text color for contrast
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double cutoutRadius = 20.0;
    Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cutoutRadius)
      ..arcToPoint(
        Offset(size.width - cutoutRadius, size.height),
        radius: Radius.circular(cutoutRadius),
        clockwise: false,
      )
      ..lineTo(cutoutRadius, size.height)
      ..arcToPoint(
        Offset(0, size.height - cutoutRadius),
        radius: Radius.circular(cutoutRadius),
        clockwise: false,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class Services {
  final String type;
  final String amount;

  Services({required this.type, required this.amount});

  factory Services.fromJson(Map<String, dynamic> json) {
    return Services(
      type: json['text'], // Assuming 'text' is the type you want
      amount: json['amount'].toString(), // Ensure amount is a string
    );
  }
}

// Model for Amenity
class Amenity {
  final String name;
  final String description;

  Amenity({required this.name, required this.description});

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      name: json['name'],
      description: json['description'] ??
          '', // Provide a default value if description is null
    );
  }
}

// Function to fetch amenities and parking services
Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
  final url =
      Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AmenitiesAndParking.fromJson(data);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    throw Exception('Error fetching data: $e');
  }
}

// Model for combined amenities and parking services
class AmenitiesAndParking {
  final List<String> amenities; // Change to List<String>
  final List<Services> services;

  AmenitiesAndParking({required this.amenities, required this.services});

  factory AmenitiesAndParking.fromJson(Map<String, dynamic> json) {
    return AmenitiesAndParking(
      amenities: List<String>.from(
        json['AmenitiesData']['amenities']
            .map((item) => item.toString()), // Convert to List<String>
      ),
      services: List<Services>.from(
        json['AmenitiesData']['parkingEntries']
            .map((item) => Services.fromJson(item)),
      ),
    );
  }
}
// Define your Services class here

class ParkingCharge {
  final String type;
  final String amount;

  ParkingCharge({required this.type, required this.amount});

  factory ParkingCharge.fromJson(Map<String, dynamic> json) {
    return ParkingCharge(
      type: json['type'],
      amount: json['amount'],
    );
  }
}

class RadialTicksPainterForExit extends CustomPainter {
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
