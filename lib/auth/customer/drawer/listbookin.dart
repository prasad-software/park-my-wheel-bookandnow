import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../config/authconfig.dart';








import '../../vendor/editpage/editslots.dart';






class ListBooking extends StatefulWidget {
  final String vendorId;
  const ListBooking({super.key, required this.vendorId}); // ✅ Fixed comma placement


  @override
  _listbookingState createState() => _listbookingState();
}


class _listbookingState extends State<ListBooking> {
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



  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        title: Text(
          'My Slots',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
          ),
        ),

      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Adjust padding as needed
          child: Image.asset('assets/gifload.gif'),
        ),
      )


      ),  );
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
  final String spaceid;
  double? distance;
  final List<ParkingEntry> parkingEntries;

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
    required this.parkingEntries,
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
    List<ParkingEntry>? parkingEntries,
  }) {
    return Vendor(
      spaceid: spaceid ?? this.spaceid,
      id: id ?? this.id,
      vendorid: vendorid ?? this.vendorid,
      vendorName: vendorName ?? this.vendorName,
      address: address ?? this.address,
      landMark: landMark ?? this.landMark,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      parkingEntries: parkingEntries ?? this.parkingEntries,
    );
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      vendorid: json['vendorId'],
      spaceid: json['spaceid'],
      id: json['_id'],
      vendorName: json['vendorName'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      landMark: json['landMark'],
      image: json['image'],
      parkingEntries: (json['parkingEntries'] as List)
          .map((parkingEntryJson) => ParkingEntry.fromJson(parkingEntryJson))
          .toList(),
    );
  }
}

//
// class alllist extends StatefulWidget {
//   final String vendorId;
//   const alllist({super.key, required this.vendorId});
//
//   @override
//   _MyListState createState() => _MyListState();
// }
//
//
// class _MyListState extends State<alllist> with TickerProviderStateMixin {
//   File? _selectedImage;
//   final bool _isSlotListingExpanded = false;
//   final bool _isLoading = false;
//
//   int _selecteddIndex = 2; //botom nav
//   int selectedTabIndex = 0;
//   int selecedIndex = 0;
//   int selectedSegment = 0; // Default selected segment (0 = All Today, 1 = Approved)
//
//   late List<Widget> _pagess;
//
//   final DateTime _selectedDate = DateTime.now(); // Initialize with today's date
//   final TextEditingController _dateController = TextEditingController();
//   late final TabController _controller;
//
//   DateTime selectedDateTime = DateTime.now();  // Initialize with the current date and time
//   void _navigateToPage(int index) {
//     setState(() {
//       _selecteddIndex = index;
//     });
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => _pagess[index]),
//     );
//   }
//   ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
//
//   late final TabController _chargesController;
//
//
//
//   late final TabController _contoller;
//
//   @override
//   void initState() {
//     super.initState();
//     selectedTabIndex = 0; // Initialize to the first tab
//     selecedIndex = 0; // Initialize to the first sub-tab
//
//     _controller = TabController(vsync: this, length: 3);
//     _chargesController = TabController(vsync: this, length: 3);
//
//
//   }
//
//
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     _chargesController.dispose();
//     super.dispose();
//   }
//
//
//
//   Future<List<Bookingdata>> fetchBookingData() async {
//     final url = Uri.parse('${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorId}');
//     final response = await http.get(url);
//
//     print('Response status: ${response.statusCode}');  // Log status code
//     print('Response body: ${response.body}');  // Log response body for debugging
//
//     if (response.statusCode == 200) {
//       try {
//         final Map<String, dynamic> jsonResponse = json.decode(response.body);
//
//         // Check if 'bookings' exists in the response
//         if (!jsonResponse.containsKey('bookings')) {
//           throw Exception('Key "bookings" not found in response');
//         }
//
//         final List<dynamic>? data = jsonResponse['bookings'];
//
//         if (data == null || data.isEmpty) {
//           throw Exception('No bookings found');
//         }
//
//         // Map the data to your Bookingdata model
//         return data.map((item) => Bookingdata.fromJson(item)).toList();
//       } catch (e) {
//         throw Exception('Failed to parse JSON: $e');
//       }
//     } else {
//       throw Exception('${response.body} ');
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar:         AppBar(
//         titleSpacing: 0,
//         backgroundColor: ColorUtils.primarycolor(),
//         title: const Text(
//           'My list',
//           style: TextStyle(color: Colors.white), // Title color white
//         ),
//         iconTheme: const IconThemeData(color: Colors.white), // Icon color white
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
//             child: CustomSlidingSegmentedControl<int>(
//               initialValue: selectedTabIndex,
//               isStretch: true,
//               children: {
//                 0: Text('On Parking', style: GoogleFonts.poppins(fontSize: 14)),
//                 1: Text('Completed', style: GoogleFonts.poppins(fontSize: 14)),
//
//
//               },
//               onValueChanged: (value) {
//                 setState(() {
//                   selectedTabIndex = value;
//                 });
//               },
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               thumbDecoration: BoxDecoration(
//                 color: ColorUtils.secondarycolor(),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               duration: const Duration(milliseconds: 300),
//               curve: Curves.easeInToLinear,
//             ),
//           ),
//
//
//           Expanded(
//             child: IndexedStack(
//               index: selectedTabIndex,
//               children: [
//                 Center(
//                   child: Padding(
//                     padding: const EdgeInsets.only(top: 10.0),
//                     child: ValueListenableBuilder<List<Bookingdata>>(
//                       valueListenable: bookingDataNotifier,
//                       builder: (context, bookingData, child) {
//                         if (bookingData.isEmpty) {
//                           // Show CircularProgressIndicator only if the data is still loading
//                           return  const Column(
//                             children: [
//                               SizedBox(height: 150),
//
//                               Text('No Vehicle Parked'),
//                             ],
//                           );
//                         }
//
//                         // Filter the data
//                         final filteredData = bookingData.where((booking) {
//                           print('Checking Booking ID: ${booking.id}, Status: ${booking.status}');
//
//                           bool isMatchingVendor = booking.Vendorid.toLowerCase() == widget.vendorId.toLowerCase();
//                           bool isParked = booking.status.toLowerCase() == 'parked';
//                           bool isValidVehicle = ['car', 'bike', 'others'].contains(booking.vehicletype.toLowerCase());
//
//                           return isMatchingVendor && isParked && isValidVehicle;
//                         }).toList();
//
//                         if (filteredData.isEmpty) {
//                           // Show "No data available" if filtering results in an empty list
//                           return  const Column(
//                             children: [
//                               SizedBox(height: 150),
//
//                               Text('No Vehicle Parked'),
//                             ],
//                           );
//                         }
//
//                         // Show the filtered data in a ListView
//                         return RefreshIndicator(
//                           onRefresh: () async {
//                             // Call the method to fetch data again
//                             await fetchBookingData();
//                           },
//                           child: Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
//                             child: ListView.builder(
//                               itemCount: filteredData.length,
//                               itemBuilder: (context, index) {
//                                 final vehicle = filteredData[index];
//
//                                 return vendordashleft(vehicle: vehicle);
//
//                               },
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//                 Center(
//                   child: Padding(
//                     padding: const EdgeInsets.only(top: 10.0),
//                     child: FutureBuilder<List<Bookingdata>>(
//                       future: fetchBookingData(),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState == ConnectionState.waiting) {
//                           return Column(
//
//
//                               },
//                             ),
//                           );
//                         }
//                       },
//                     ),
//                   ),
//                 ),
//
//
//
//               ],
//             ),
//           ),
// //         ],
//       ),
//
//     );
//   }
// }