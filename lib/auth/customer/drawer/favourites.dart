import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/authconfig.dart';

import '../../../explorebooknow.dart';
import 'listexplore.dart';

class favourites extends StatefulWidget {

  final String userid;

  const favourites({
    super.key,
    required this.userid,
  });
  @override
  _favouritesState createState() => _favouritesState();
}

class _favouritesState extends State<favourites> {
  final _formKey = GlobalKey<FormState>();
  double distance = 0.0;
  bool isLoading = false; // New variable for parking charges loading state
  late Position _currentPosition; // Declare the variable to hold the current position

  List<Map<String, String>> parkingCharges = [];
  // Sample list of vendors with latitude, longitude, and vendor name
  List<Map<String, dynamic>> vendors = [];
  String? selectedVehicle;
  String? selectedBookingType;
  String? selectedPriceRange;
  late String apiUrl;
  final List<String> vehicles = ['Car', 'Bike'];

  @override
  void initState() {
    super.initState();
    apiUrl = '${ApiConfig.baseUrl}getfavlist?userId=${widget.userid}';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. Request location permission first
      await _requestLocationPermission();

      // 2. Fetch favorite vendor IDs
      final favoriteVendorIds = await fetchFavoriteVendorIds();

      // 3. Fetch vendors based on favorite IDs
      final vendorsList = await fetchVendors(favoriteVendorIds);

      // 4. Get current location
      await _getCurrentLocation();

      // 5. Fetch parking charges for each vendor
      for (var vendor in vendorsList) {
        if (vendor['id'] != null) {
          final charges = await fetchParkingCharges(vendor['id']);
          vendor['parkingCharges'] = charges;
        }
      }

      setState(() {
        vendors = vendorsList;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Modified fetchVendors to accept favoriteVendorIds
  Future<List<Map<String, dynamic>>> fetchVendors(List<String> favoriteVendorIds) async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] != null) {
          return (jsonResponse['data'] as List).map((vendor) {
            double? latitude;
            double? longitude;

            try {
              latitude = double.tryParse(vendor['latitude'] ?? '0.0');
              longitude = double.tryParse(vendor['longitude'] ?? '0.0');
            } catch (e) {
              print('Error parsing latitude/longitude: $e');
            }

            return {
              'id': vendor['_id'] ?? '',
              'name': vendor['vendorName'] ?? 'Unknown Vendor',
              'latitude': latitude ?? 0.0,
              'longitude': longitude ?? 0.0,
              'image': vendor['image'] ?? '',
              'address': vendor['address'] ?? 'No Address',
              'contactNo': vendor['contactNo'] ?? 'No Contact',
              'landMark': vendor['landMark'] ?? 'No Landmark',
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching vendors: $e');
      return [];
    }
  }

  // Add this method to manually refresh data
  Future<void> refreshData() async {
    await _loadData();
  }

// Function to fetch vendor data

  Future<List<String>> fetchFavoriteVendorIds() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/favorites?userId=${widget.userid}'));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return (jsonResponse['favorites'] as List)
            .map((favorite) => favorite['vendorId'] as String)
            .toList();
      } else {
        print('Failed to load favorite vendors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching favorite vendors: $e');
      return [];
    }
  }
  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      // Permission granted, get current location
      _getCurrentLocation();
    } else if (status.isDenied) {
      // Location permission is denied, show button to request permission
      status = await Permission.location.request();
      if (status.isGranted) {
        // Permission granted, get current location
        _getCurrentLocation();
      } else {
        // Handle the case when permission is denied
        print('Location permission denied');
      }
    } else if (status.isPermanentlyDenied) {
      // Permission is permanently denied, open app settings
      openAppSettings();
    }
  }
  Future<List<ParkingCharge>> fetchParkingCharges(String vendorId) async {
    setState(() {
      isLoading = true; // Start loading
    });

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/explorecharge/$vendorId'));
      print('Fetching parking charges for vendor ID: $vendorId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return (jsonResponse['charges'] as List).map((charge) {
          return ParkingCharge.fromJson(charge);
        }).toList();
      } else {
        print('Failed to load parking charges: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching parking charges: $e');
      return [];
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
      for (var vendor in vendors) {
        double distance = haversineDistance(
          _currentPosition.latitude,
          _currentPosition.longitude,
          vendor['latitude'],
          vendor['longitude'],
        );
        vendor['distance'] = distance; // Store distance in vendor map
      }
      setState(() {}); // Update the UI
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text(
          'My Favourites',
          style: GoogleFonts.lato(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: isLoading
            ? const LoadingGif()
            : vendors.isEmpty
          ? _buildNoFavouritesFound() // Display custom UI when no favorites are found
          :SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10,),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vendors.length,
              itemBuilder: (context, index) {
                final vendor = vendors[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MallDetailPage(vendor: vendor, userid: widget.userid),
                        ),
                      );
                      // Refresh the list when returning from detail page
                      await _loadData();
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10, top: 10.0, bottom: 0.0, right: 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: vendor['image'].startsWith('http')
                                          ? Image.network(
                                        vendor['image'],
                                        width: 120,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                          : Image.asset(
                                        vendor['image'],
                                        width: 120,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (vendor['parkingCharges'] != null &&
                                        vendor['parkingCharges'].isNotEmpty &&
                                        vendor['parkingCharges'][0].amount != 0 &&
                                        vendor['parkingCharges'][0].type != 'N/A')
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: ColorUtils.primarycolor(),
                                            ),
                                            padding: const EdgeInsets.all(4.0),
                                            child: const Icon(
                                              Icons.directions_car,
                                              size: 12.0,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 3.0),
                                          Text(
                                            '₹ ${vendor['parkingCharges'][0].amount} / ${vendor['parkingCharges'][0].type}',
                                            style: GoogleFonts.poppins(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 2),

                                    if (vendor['parkingCharges'] != null &&
                                        vendor['parkingCharges'].length > 1 &&
                                        vendor['parkingCharges'][1].amount != 1 &&
                                        vendor['parkingCharges'][1].type != 'N/A')
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: ColorUtils.primarycolor(),
                                            ),
                                            padding: const EdgeInsets.all(4.0),
                                            child: const Icon(
                                              Icons.pedal_bike_sharp,
                                              size: 12.0,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            '₹ ${vendor['parkingCharges'][1].amount} / ${vendor['parkingCharges'][1].type}',
                                            style: GoogleFonts.poppins(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 9,),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vendor['name'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 0),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          // Create a TextPainter to calculate the required height for the address text
                                          final TextPainter textPainter = TextPainter(
                                            text: TextSpan(
                                              text: vendor['address'],
                                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[800]),
                                            ),
                                            maxLines: 2, // Limit to 2 lines
                                            textDirection: TextDirection.ltr,
                                          )..layout(maxWidth: constraints.maxWidth);

                                          // Check if text overflows (i.e., takes two lines)
                                          bool isMultiline = textPainter.didExceedMaxLines;

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                vendor['address'] != null && vendor['address'].length > 50
                                                    ? vendor['address'].substring(0, 45) + '...'
                                                    : vendor['address'],
                                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[800]),
                                              ),
                                              SizedBox(height: isMultiline ? 5 : 0), // Adjust height based on line count
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            bottom: -9,
                            right: 0,
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ExploreBook(
                                          vendorId: vendor['id'],
                                          userId: widget.userid,
                                          vendorName: vendor['name'],
                                        ),
                                      ),
                                    );
                                    // Refresh the list when returning from explore page
                                    await _loadData();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                    minimumSize: const Size(80, 30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Book Now',
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.check_circle, size: 18.0, color: Colors.white),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final double latitude = vendor['latitude'];
                                    final double longitude = vendor['longitude'];
                                    final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

                                    if (await canLaunch(googleMapsUrl)) {
                                      await launch(googleMapsUrl);
                                    } else {
                                      debugPrint("Could not launch $googleMapsUrl");
                                    }
                                  },
                                  child: Container(
                                    height: 30,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlue,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.lightBlue, width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${vendor['distance'] != null ? vendor['distance'].toStringAsFixed(2) : 'N/A'} km',
                                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.telegram, size: 18.0, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),



          ],
        ),
      ),
      ),
    );
  }
  Widget _buildNoFavouritesFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // const SizedBox(height: 100),
          Icon(
            Icons.favorite_border,
            size: 80,
            color:ColorUtils.primarycolor(),
          ),
          // const SizedBox(height: 20),
          Text(
            'No Favourites Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          // const SizedBox(height: 10),
          Text(
            'Explore now to find and save your favorite locations!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          // ElevatedButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => ListExplore(userid: widget.userid),
          //       ),
          //     );
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: ColorUtils.primarycolor(),
          //     foregroundColor: Colors.white,
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(10),
          //     ),
          //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          //   ),
          //   child: Text(
          //     'Explore Parking Spots',
          //     style: GoogleFonts.poppins(
          //       fontSize: 16,
          //       fontWeight: FontWeight.bold,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

