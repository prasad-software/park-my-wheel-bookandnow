import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import '../../../explorebooknow.dart';
import '../../../pageloader.dart';
import 'explore.dart';
import 'filter.dart';
import 'listexplore.dart';

class SearchScreen extends StatefulWidget {
  final String userid;
  final String title;

  const SearchScreen({super.key, required this.userid, required this.title});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  double distance = 0.0;
  bool isFetchingParkingCharges = false;
  late Position _currentPosition;
  bool isLoading = false;
  List<Map<String, dynamic>> vendors = [];
  String? selectedVehicle;
  String? selectedBookingType;
  String? sortBy;
  late TextEditingController _searchController;
  List<Map<String, dynamic>> filteredVendors = [];
  final List<String> vehicles = ['Car', 'Bike'];
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _itemAnimations = [];
    _requestLocationPermission();
    fetchVendors().then((value) {
      setState(() {
        vendors = value;
        filteredVendors = vendors;
        _initializeItemAnimations(filteredVendors.length);
      });
      _getCurrentLocation();

      for (var vendor in vendors) {
        if (vendor['id'] != null) {
          fetchParkingCharges(vendor['id']).then((charges) {
            setState(() {
              vendor['parkingCharges'] = charges;
            });
          });
        }
      }
    });
  }

  void _initializeItemAnimations(int count) {
    print('Initializing animations for $count vendors');
    _itemAnimations = List.generate(count, (index) {
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
    });
    print('_itemAnimations length: ${_itemAnimations.length}');
    if (count > 0) {
      _animationController.reset(); // Reset before starting
      _animationController.forward();
    }
  }

  void _filterVendors(String query) {
    setState(() {
      filteredVendors = vendors.where((vendor) {
        final name = vendor['name'].toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();

      filteredVendors.sort((a, b) {
        int aIndex = a['name'].toLowerCase().indexOf(query.toLowerCase());
        int bIndex = b['name'].toLowerCase().indexOf(query.toLowerCase());
        return aIndex.compareTo(bIndex);
      });

      // Reinitialize animations for the updated filteredVendors list
      _initializeItemAnimations(filteredVendors.length);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isGranted) {
        _getCurrentLocation();
      } else {
        print('Location permission denied');
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<List<ParkingCharge>> fetchParkingCharges(String vendorId) async {
    setState(() {
      isFetchingParkingCharges = true;
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
        isFetchingParkingCharges = false;
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
        vendor['distance'] = distance;
      }
      setState(() {});
    } catch (e) {
      print('Error fetching location: $e');
    }
  }
  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  String apiUrl = '${ApiConfig.baseUrl}vendor/fetchvisible';

  Future<List<Map<String, dynamic>>> fetchVendors() async {
    setState(() {
      isLoading = true;
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
              'parkingEntries': vendor['parkingEntries'] ?? [],
              'charges': vendor['charges'] ?? {},
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
        isLoading = false;
      });
    }
  }

  void _showFilterScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterScreen(
        vendors: vendors,
        onApply: (filtered, filters) {
          setState(() {
            filteredVendors = filtered;
            selectedVehicle = filters['vehicle'];
            selectedBookingType = filters['bookingType'];
            sortBy = filters['sortBy'];
            _initializeItemAnimations(filteredVendors.length); // Reinitialize animations
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(titleSpacing: 0,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExplorePage(userid: widget.userid),
                ),
              );
              print('Search clicked');
            },
            child: Container(
              width: 35.0,
              height: 35.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Image.asset(
                    'assets/map.gif',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
        ],
        title: Text(
          widget.title,
          style: GoogleFonts.lato(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        // backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 5,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10), // Removed right padding
                      child: TextFormField(
                        controller: _searchController,
                        onChanged: _filterVendors,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                          ),
                          suffixIcon: Icon(
                            Icons.search,
                            color: ColorUtils.primarycolor(),
                          ),
                          constraints: const BoxConstraints(
                            maxHeight: 36,
                            maxWidth: double.infinity,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          hintText: 'Search Parking Locations...',
                          hintStyle: const TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5,),
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0), // No left padding
                    child: SizedBox(
                      height: 35.0,
                      child: TextButton(
                        onPressed: _showFilterScreen,
                        style: TextButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: ColorUtils.primarycolor()),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8), // optional fine-tuning
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.filter_list, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Filter'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),


              const SizedBox(height: 10,),
              isLoading
                  ? const LoadingGif() // Show loading GIF before the Scaffold
                  : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredVendors.length,
                  itemBuilder: (context, index) {
                    final animation = index < _itemAnimations.length
                        ? _itemAnimations[index]
                        : const AlwaysStoppedAnimation<double>(1.0);
                    final vendor = filteredVendors[index];
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5), // Slide from bottom
                          end: Offset.zero,
                        ).animate(animation),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MallDetailPage(vendor: vendor, userid: widget.userid),
                                ),
                              );
                            },
                            child: Container(
                              height: 123,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black, // border color
                                  width: 0.5,           // border width
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 10, top: 10.0, bottom: 0.0, right: 0),
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
                                            const SizedBox(height: 9),
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
                                                    'Rs. ${vendor['parkingCharges'][0]
                                                        .amount} / ${vendor['parkingCharges'][0]
                                                        .type}',
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
                                                    'Rs. ${vendor['parkingCharges'][1]
                                                        .amount} / ${vendor['parkingCharges'][1]
                                                        .type}',
                                                    style: GoogleFonts.poppins(fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            const SizedBox(height: 9),
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
                                                overflow: TextOverflow.ellipsis, // or TextOverflow.fade, clip
                                                maxLines: 1, // Optional, restrict to one line
                                              ),

                                              const SizedBox(height: 0),
                                              LayoutBuilder(
                                                builder: (context, constraints) {
                                                  final TextPainter textPainter = TextPainter(
                                                    text: TextSpan(
                                                      text: vendor['address'],
                                                      style: GoogleFonts.poppins(fontSize: 11,
                                                          color: Colors.grey[800]),
                                                    ),
                                                    maxLines: 2,
                                                    textDirection: TextDirection.ltr,
                                                  )
                                                    ..layout(maxWidth: constraints.maxWidth);

                                                  bool isMultiline = textPainter
                                                      .didExceedMaxLines;

                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      Text(
                                                        vendor['address'] != null &&
                                                            vendor['address'].length > 50
                                                            ? vendor['address'].substring(
                                                            0, 45) + '...'
                                                            : vendor['address'],
                                                        style: GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            color: Colors.grey[800]),
                                                      ),
                                                      SizedBox(height: isMultiline ? 5 : 0),
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
                                    bottom: -2,
                                    right: 6,

                                    child: Row(
                                      children: [
                                        Container(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ExploreBook(
                                                        vendorId: vendor['id'],
                                                        userId: widget.userid,
                                                        vendorName: vendor['name'],
                                                      ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: ColorUtils.primarycolor(),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(5.0),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 4, horizontal: 10),
                                              minimumSize: const Size(80, 30),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Book Now',
                                                  style: GoogleFonts.poppins(fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 3),
                                                const Icon(Icons.check_circle, size: 18.0,
                                                    color: Colors.white),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            final double latitude = vendor['latitude'];
                                            final double longitude = vendor['longitude'];
                                            final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

                                            if (await canLaunchUrl(
                                                Uri.parse(googleMapsUrl))) {
                                              await launchUrl(Uri.parse(googleMapsUrl));
                                            } else {
                                              debugPrint("Could not launch $googleMapsUrl");
                                            }
                                          },
                                          child: Container(
                                            height: 30,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(5),
                                              // border: Border.all(
                                              //     color: Colors.black, width: 1.2),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${vendor['distance'] != null
                                                      ? vendor['distance'].toStringAsFixed(2)
                                                      : 'N/A'} km',
                                                  style: GoogleFonts.poppins(fontSize: 11,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 3),
                                                const Icon(Icons.telegram, size: 18.0,
                                                    color: Colors.white),
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
                        ),
                      ),
                    );
                  }),
            ]),

      ),),
    );
  }
}

class ParkingCharge {
  final String vehicleType;
  final String type;
  final double amount;

  ParkingCharge({required this.vehicleType, required this.type, required this.amount});

  factory ParkingCharge.fromJson(Map<String, dynamic> json) {
    return ParkingCharge(
      vehicleType: json['vehicleType'] ?? '',
      type: json['type'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
    );
  }
}