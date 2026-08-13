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

// import '../../vendor/vendorbottomnav/thirdbottom.dart';

class bookingtransactiondetails extends StatefulWidget {
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


  const bookingtransactiondetails({
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

class _vParkingDetailsState extends State<bookingtransactiondetails> {

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
    return {
      'amount': widget.amount ?? '0',
      'gst': '0',
      'handlingfee': '0',
      'totalAmount': widget.totalamount ?? '0',
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

        return {
          'amount': amount,
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
      print('Received transaction data: ${widget.bookedid}');
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


    // Define date format for parsing widget.schedule
    // Define readable date format
    final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    String fromDate = 'N/A';
    String toDate = 'N/A';

    final sts = (_transactionDetails?['sts']?.toString() ?? widget.sts ?? '').trim();
    final isSubscription = isSubscriptionSts(sts);

    final parkedDate = (_transactionDetails?['parkedDate']?.toString() ?? widget.parkeddate ?? '').trim();
    final parkedTime = (_transactionDetails?['parkedTime']?.toString() ?? widget.parkedtime ?? '').trim();
    final subEndDate = (_transactionDetails?['subscriptionenddate']?.toString() ?? widget.subscriptionenddate ?? '').trim();
    final exitDate = (_transactionDetails?['exitdate']?.toString() ?? widget.exitdate ?? '').trim();
    final exitTime = (_transactionDetails?['exittime']?.toString() ?? widget.exittime ?? '').trim();

    try {
      // From date: always parked date & time
      fromDate = (parkedDate.isNotEmpty && parkedTime.isNotEmpty)
          ? '$parkedDate, $parkedTime'
          : ((widget.parkeddate ?? '').trim().isNotEmpty ? '${widget.parkeddate}, ${widget.parkedtime}' : 'N/A');

      // To date (Exit on): Subscription → subscription end date; otherwise → exit vehicle date & time
      if (isSubscription) {
        toDate = subEndDate.isNotEmpty ? subEndDate : ((widget.subscriptionenddate ?? '').trim().isNotEmpty ? (widget.subscriptionenddate ?? 'N/A') : 'N/A');
      } else {
        final hasExit = exitDate.isNotEmpty || exitTime.isNotEmpty;
        final exitParts = [exitDate, exitTime].where((s) => s.isNotEmpty).join(', ');
        final widgetExit = [widget.exitdate ?? '', widget.exittime ?? ''].map((s) => (s ?? '').toString().trim()).where((s) => s.isNotEmpty).join(', ');
        toDate = hasExit ? exitParts : (widgetExit.isNotEmpty ? widgetExit : 'N/A');
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
                            _transactionDetails?['totalAmount'] ?? widget.totalamount ?? '0.00',
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
                'Amount: ₹${_transactionDetails?['totalAmount'] ?? widget.totalamount ?? '0.00'}',
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
                'Total Amount (in INR): ₹${_transactionDetails?['totalAmount'] ?? widget.totalamount ?? '0.00'}',
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
