import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/explorebooknow.dart' show ExploreBook, explorebook;
import 'package:mywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/authconfig.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../vendor/vendorbottomnav/thirdbottom.dart';
import '../parking/parking.dart';


class MallDetailPage extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final String userid;

  const MallDetailPage({
    super.key,
    required this.vendor,
    required this.userid,
  });

  @override
  _MallDetailPageState createState() => _MallDetailPageState();
}
class _MallDetailPageState extends State<MallDetailPage> {
  bool _locationDenied = false;
  bool _locationPermanentlyDenied = false;
  late Position _currentPosition;
  List<String> favoriteVendorIds = [];
  List<String> amenities = []; // Add your amenities list
  List<Services> services = []; // Add your services list
  int selectedTabIndex = 0; // Track selected tab index
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
  bool isLoading = true; // Add this loading state variable
  List<Map<String, dynamic>> businessHours = List.generate(7, (index) {
    return {
      'day': getDayOfWeek(index),
      'openTime': '09:00',
      'closeTime': '21:00',
      'is24Hours': false,
      'isClosed': false,
    };
  });

  List<String> hours = List.generate(24, (index) {
    return index < 10 ? '0$index:00' : '$index:00';
  });



  Future<Map<String, dynamic>> fetchVendor(String vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId'),
      );

      if (response.statusCode == 200) {
        isLoading = false;
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch vendor');
      }
    } catch (e) {
      print('Error: $e');
      isLoading = false;
      return {};
    }
  }
  late Future<Map<String, dynamic>> vendorData;
  late Future<Vendor> _futureVendor;
  @override
  void initState() {
    super.initState();
    vendorData = fetchVendor(widget.vendor['id']); // Initialize vendorData here

    vendorData.then((data) {
      setState(() {
        if (data['businessHours'] != null) {
          businessHours = List<Map<String, dynamic>>.from(data['businessHours']);
        }
        isLoading = false;
      });
    });
    isLoading = true; // Set loading to true initially
    loadFavoriteVendors();
    _requestLocationPermission();

    _futureVendor = ApiService().getParkingCharges(widget.vendor['id']);

    if (widget.vendor['id'] != null) {
      fetchAmenitiesAndParking(widget.vendor['id']).then((amenitiesAndParking) {
        // Introduce a 2-second delay before updating the state
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            amenities = amenitiesAndParking.amenities;
            services = amenitiesAndParking.services;
            isLoading = false; // Set loading to false when data is loaded
          });
        });
      }).catchError((error) {
        setState(() {
          isLoading = false; // Also set loading to false if there's an error
        });
        print('Error fetching amenities: $error');
      });
    } else {
      setState(() {
        isLoading = false; // Set loading to false if vendor ID is null
      });
    }
    loadFavoriteVendors();
  }
  void loadFavoriteVendors() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}getfavourite?userId=${widget.userid}'));
    print('Request URL: ${ApiConfig.baseUrl}getfavourite?userId=${widget.userid}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Response Data: $data'); // Log the response data
      setState(() {
        favoriteVendorIds = List<String>.from(data['favorites'].map((fav) => fav['vendorId'])); // Adjust based on your API response
      });
    } else {
      print('Failed to load favorites: ${response.statusCode}'); // Log error
    }
  }
  bool isVendorFavorited(String vendorId) {
    print('Checking if vendor $vendorId is favorited: ${favoriteVendorIds.contains(vendorId)}');
    return favoriteVendorIds.contains(vendorId);
  }
  // Toggle favorite status
  void toggleFavorite(String vendorId) async {
    if (isVendorFavorited(vendorId)) {
      await removeFromFavorites(vendorId);
      setState(() {
        favoriteVendorIds.remove(vendorId);
      });
    } else {
      await addToFavorites(vendorId);
      setState(() {
        favoriteVendorIds.add(vendorId);
      });
    }
  }

  // Add to favorites
  Future<void> addToFavorites(String vendorId) async {
    final Map<String, String> requestData = {
      'userId': widget.userid,
      'vendorId': vendorId,
    };

    print('Attempting to add vendor to favorites...');
    print('Request URL: ${ApiConfig.baseUrl}addfavourite');
    print('Request Data: ${jsonEncode(requestData)}');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}addfavourite'),
      body: jsonEncode(requestData),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('Vendor added to favorites successfully!');
    } else {
      print('Failed to add vendor to favorites. Please check the API response.');
    }
  }

  // Remove from favorites
  Future<void> removeFromFavorites(String vendorId) async {
    final Map<String, String> requestData = {
      'userId': widget.userid,
      'vendorId': vendorId,
    };

    print('Attempting to remove vendor from favorites...');
    print('Request URL: ${ApiConfig.baseUrl}removefavourite');
    print('Request Data: ${jsonEncode(requestData)}');

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}removefavourite'),
      body: jsonEncode(requestData),
      headers: {'Content-Type': 'application/json'},
    );

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('Vendor removed from favorites successfully!');
    } else {
      print('Failed to remove vendor from favorites. Please check the API response.');
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

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        // Update the map with the current position
      });
    } catch (e) {
      print('Error fetching location: $e');
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



  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check if the response contains the expected structure
        if (data['AmenitiesData'] != null) {
          // Print the fetched amenities data
          // print('Fetched Amenities Data: ${data['AmenitiesData']}');
          return AmenitiesAndParking.fromJson(data);
        } else {
          throw Exception('AmenitiesData is null in response');
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      // print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      // backgroundColor: ColorUtils.secondarycolor(),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
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
          widget.vendor['name'] ?? '',
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
        actions: [
          IconButton(
            onPressed: () {
              toggleFavorite(widget.vendor['id'] ?? '');
            },
            icon: Icon(
              isVendorFavorited(widget.vendor['id'] ?? '')
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.white,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) {
              if (value == 'share') {
                // _shareVendor();
              } else if (value == 'my_booking') {
                // _navigateToMyBooking();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'share',
                  child: Text(
                    'Share',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'my_booking',
                  child: Text(
                    'My Booking',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ];
            },
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: Image.network(
                  widget.vendor['image'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.error));
                  },
                ),
              ),
              // Gradient overlay to darken bottom area
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
                // crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // const SizedBox(height: 5),
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
                                          widget.vendor['name'],
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


                                         Text(widget.vendor['address'],
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
                                          final double latitude = widget.vendor['latitude'];
                                          final double longitude = widget.vendor['longitude'];

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
                                                width: 0.5),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${widget.vendor['distance'] != null ? widget.vendor['distance'].toStringAsFixed(2) : 'N/A'} km',
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







                      const SizedBox(height: 10), // Spacing
                      // Bike Parking Row

                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Container(color: Colors.white,
                          child: Column(
                            children: [
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Price Details",
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
                              const SizedBox(height: 5),
                              FutureBuilder<Vendor>(
                                future: _futureVendor,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return _buildGridView(snapshot.data!.charges);
                                  } else if (snapshot.hasError) {
                                    // return Center(child: Text('Error: ${snapshot.error}'));
                                    return const Center(child: Text('No price chart found'));
                                  }
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Container(color: Colors.white,
                          child: Column(
                            children: [
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Operational Hours",
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
                              const SizedBox(height: 5),
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 3, child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          Expanded(flex: 3, child: Text('Open at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          Expanded(flex: 3, child: Text('Close at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        ],
                                      ),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: businessHours.length,
                                      itemBuilder: (context, index) {
                                        final dayData = businessHours[index];
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                                          padding: const EdgeInsets.all(4.0),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(dayData['day'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black87)),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: dayData['isClosed']
                                                    ? _statusLabel('Closed', Colors.red)
                                                    : dayData['is24Hours']
                                                    ? _statusLabel('24 Hours', Colors.green)
                                                    : _styledBox(dayData['openTime']),

                                              ),
                                              if (!dayData['isClosed'] && !dayData['is24Hours'])
                                                const SizedBox(width: 8.0),
                                              if (!dayData['isClosed'] && !dayData['is24Hours'])
                                                Expanded(
                                                  flex: 3,
                                                  child: _styledBox(dayData['closeTime']),
                                                ),

                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    // Text("Contact details", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Container(
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
                      ),

                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Container(
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
                      ),


                      const SizedBox(height: 8),








                        // Loop through the services list


                      // Add more widgets as needed
                      // Google Map
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            // border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5.0),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  widget.vendor['latitude'],
                                  widget.vendor['longitude'],
                                ),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('vendor_location'),
                                  position: LatLng(
                                    widget.vendor['latitude'],
                                    widget.vendor['longitude'],
                                  ),
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                      // Conditional display for location permission
                      if (_locationDenied) ...[
                        Column(
                          children: [
                            const Text('Location permission is denied.'),
                            ElevatedButton(
                              onPressed: _requestPermissionAgain,
                              child: const Text('Allow Location'),
                            ),
                          ],
                        ),
                      ],
                      if (_locationPermanentlyDenied) ...[
                        Column(
                          children: [
                            const Text('Location permission is permanently denied.'),
                            ElevatedButton(
                              onPressed: () {
                                openAppSettings();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      ],
                      if (!_locationDenied && !_locationPermanentlyDenied) ...[
                        const Center(child: Text('')),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end, // Aligns the button to the right
                        children: [
                          SizedBox(
                            width: 100, // Set your desired width
                            height: 30, // Set your desired height
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExploreBook(
                                      vendorId: widget.vendor['id'],
                                      userId: widget.userid,
                                      vendorName: widget.vendor['name'],
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: ColorUtils.primarycolor(), // Set the background color to your primary color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8), // Optional: Add border radius
                                ),
                              ),
                              child:  Text(
                                'Book Now',
                                style: GoogleFonts.poppins(fontSize: 10), // Optional: Customize text style
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

      ),);
  }
  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 4, horizontal: isSmallScreen ? 4 : 8),
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
  static String getDayOfWeek(int index) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[index];
  }
  Widget _buildGridView(List<Charge> charges) {
    return Wrap(
      spacing: 0, // Horizontal space between items
      runSpacing: 0, // Vertical space between items
      children: charges.map((charge) => _buildChargeCard(charge)).toList(),
    );
  }

  Widget _buildChargeCard(Charge charge) {
    IconData iconData;

    // Determine the icon based on the category
    switch (charge.category.toLowerCase()) {
      case 'car':
        iconData = Icons.directions_car;
        break;
      case 'bike':
        iconData = Icons.directions_bike;
        break;
      default:
        iconData = Icons.help; // Default icon for others
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey), // Border color
        borderRadius: BorderRadius.circular(5), // Rounded corners
      ),
      width: 80, // Set a fixed width for the card
      height: 50, // Set a fixed height for the card
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular icon with green background
            Container(
              decoration: BoxDecoration(
                color: ColorUtils.primarycolor(), // Green background
                shape: BoxShape.circle, // Circular shape
              ),
              padding: const EdgeInsets.all(4), // Padding around the icon
              child: Icon(
                iconData,
                size: 12,
                color: Colors.white, // White icon color
              ),
            ),
            const SizedBox(height: 2),
            Text(
              charge.type,
              style: GoogleFonts.poppins(
                fontSize: 7,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹ ${charge.amount}',
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
  final url = Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AmenitiesAndParking.fromJson(data);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  } catch (e) {
    // print('Error: $e');
    throw Exception('Error fetching data: $e');
  }
}
class AmenitiesAndParking {
  final List<String> amenities; // Change to List<String>
  final List<Services> services;

  AmenitiesAndParking({required this.amenities, required this.services});

  factory AmenitiesAndParking.fromJson(Map<String, dynamic> json) {
    return AmenitiesAndParking(
      amenities: List<String>.from(
        json['AmenitiesData']['amenities'].map((item) => item.toString()), // Convert to List<String>
      ),
      services: List<Services>.from(
        json['AmenitiesData']['parkingEntries'].map((item) => Services.fromJson(item)),
      ),
    );
  }

}
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
class Vendor {
  final String id;
  final String vendorId;
  final List<Charge> charges;

  Vendor({
    required this.id,
    required this.vendorId,
    required this.charges,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['_id'],
      vendorId: json['vendorid'],
      charges: List<Charge>.from(
        json['charges'].map((x) => Charge.fromJson(x)),
      ),
    );
  }
}
class ApiService {
  // Method to get parking charges for a specific vendor
  Future<Vendor> getParkingCharges(String vendorId) async {
    final String baseUrl = '${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId';
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      return Vendor.fromJson(jsonDecode(response.body)['vendor']);
    } else {
      throw Exception('Failed to load data');
    }
  }
}