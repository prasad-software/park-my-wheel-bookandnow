import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/utils/sts_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;


import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../vendor/vendorbottomnav/thirdbottom.dart';
class bookticket extends StatefulWidget  {
  final String vehiclenumber;
  final String vendorname;
  final String vendorid;
  final String parkingdate;
  final String parkingtime;
  final String bookedid;
  final String otp;
  final String vehicletype;
  final String bookeddate;
  final String status;
  final String schedule;
  final String bookingtype;
  final String sts;
  final String mobileno;
  const bookticket({
    super.key,
    required this.vehiclenumber,
    required this.vendorname,
    required this.otp,
    required this.vendorid,
    required this.parkingdate,
    required this.parkingtime,
    required this.bookedid,
    required this.vehicletype,
    required this.bookeddate,
    required this.status,
    required this.schedule,
    required this.bookingtype,
    required this.sts,
    required this.mobileno,
  });

  @override
  _bookticketState createState() => _bookticketState();
}

class _bookticketState extends State<bookticket> {
  bool _isLoading = false;
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
  // bool _isLoading = false;
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

    _fetchVendorData();
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
        // print('Fetched Amenities: $amenities');
        // print('Fetched Services: $services');
      }).catchError((error) {
        print('Error fetching amenities: $error'); // Debugging print statement
      });
    }
    _fetchVendorData();
  }

  Future<void> fetchChargesData(String vendorId, String selectedCarType) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    // Construct the URL
    final String url = '${ApiConfig.baseUrl}vendor/fetchbookcharge/$vendorId/$selectedCarType';

    // Print the URL for debugging
    print('Fetching charges book gtivk data from URL: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response Data: $data');

        // Check if the response contains the expected charges list
        if (data is List) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data);
          });
        } else if (data['vendor'] != null && data['vendor']['charges'] != null) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data['vendor']['charges']);
          });
        } else {
          print('Charges data is missing or invalid in the response.');
          setState(() {
            charges = []; // Reset charges if data is invalid
          });
        }
      } else {
        print('Failed to load charges data. Status Code: ${response.statusCode}');
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
        _isLoading = false; // Stop loading
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

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
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

  // Future<void> _getCurrentLocation() async {
  //   try {
  //     _currentPosition = await Geolocator.getCurrentPosition(
  //         desiredAccuracy: LocationAccuracy.high);
  //     setState(() {
  //       // Update the map with the current position
  //     });
  //   } catch (e) {
  //     print('Error fetching location: $e');
  //   }
  // }

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
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _isLoading = false; // Hide loading indicator after data is fetched
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
        _isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   titleSpacing: 0,
      //   backgroundColor:  ColorUtils.primarycolor(),
      //   title: const Text("Parking Ticket", style: TextStyle(color: Colors.white)),
      //   iconTheme: const IconThemeData(color: Colors.white),
      // ),

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
    return Container(
      // height: MediaQuery.of(context).size.height - kToolbarHeight,
      child: CustomScrollView(slivers: [
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
          background: Stack(
            fit: StackFit.expand,
            children: [
              // --- Image Layer ---
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

              // --- Gradient Overlay for readability ---
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
                                    Text(
                                      "OTP: ", // Add the "OTP" label
                                      style: GoogleFonts.poppins(
                                        fontWeight:
                                        FontWeight.bold,
                                        color: Colors.white,
                                        fontSize:
                                        16, // Adjust the font size as needed
                                      ),
                                    ),
                                    ...(widget.otp.length >= 3
                                        ? (widget.status == 'PARKED'
                                        ? widget.otp
                                        .substring(widget.otp.length - 3) // last 3 digits
                                        .split('')
                                        .map((digit) => _pinBox(digit))
                                        : widget.otp
                                        .substring(0, 3) // first 3 digits
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
                                    ]),

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
                                                  "Mobilenumber:${widget.mobileno}",
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
                                          gmaps.Marker(
                                            markerId: const gmaps.MarkerId('vendor_location'),
                                            position: gmaps.LatLng(
                                              double.tryParse(_vendor?.latitude ?? '0') ?? 0.0,
                                              double.tryParse(_vendor?.longitude ?? '0') ?? 0.0,
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
      ]),
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
