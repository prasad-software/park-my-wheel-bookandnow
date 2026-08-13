import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:mywheels/auth/customer/drawer/favourites.dart';
import 'package:mywheels/auth/customer/dummypages/coroporatesolution.dart';

import 'package:mywheels/auth/customer/dummypages/premium.dart';
import 'package:mywheels/auth/customer/dummypages/usersubcription.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/config/colorcode.dart';
import '../vendor/vendorregister.dart';
import 'drawer/Searchscreen.dart';
import 'drawer/mylist.dart';
import 'dummypages/commercial.dart';
class moreservice extends StatefulWidget {
  final String userId;
  final LatLng? initialPosition;
  const moreservice({super.key,
    this.initialPosition,
    required this.userId,
  });

  @override
  State<moreservice> createState() => _moreserviceState();
}

class _moreserviceState extends State<moreservice> with TickerProviderStateMixin {






  List<String> bannerList = [];
  void _TabChange(int index) {
    _navigatePage(index);
  }

  final int _selectedIndex = 0;
  int _selecteIndex = 0;
  late List<Widget> _pages;

  void _navigatePage(int index) {
    setState(() {
      _selecteIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }



  final List<Map<String, dynamic>> ramData = [
    {'head': 'Book Parking', 'bottom': '','data': '100', 'icon': 'assets/myspace.svg'},
    {'head': 'My Bookings', 'bottom': '', 'data': '100', 'icon': 'assets/parking.svg' },
    {'head': 'Monthly Subscription', 'bottom': '', 'data': '100', 'icon': 'assets/blockspot.svg' },
    // {'head': 'Monthly','bottom': 'Booking',  'data': '100', 'icon': Icons.business_center},
    {'head': 'Explore','bottom': '', 'data': '100', 'icon': 'assets/explore.svg'},
    // {'head': 'Create Parking', 'data': '100', 'icon': Icons.create},
    {'head': 'Favourite','bottom': 'Parking', 'data': '100', 'icon': 'assets/favourite.svg'},

    {'head': 'My', 'bottom': 'Business','data': '100', 'icon': 'assets/bookparking.svg'},
    {'head': 'Corporate','bottom':'Solutions',  'data': '100', 'icon': 'assets/corporate.svg'},
    {'head': 'Commercial', 'bottom':'Services', 'data': '100', 'icon': 'assets/moreservice.svg'},
    {'head': 'Premium', 'bottom':'Parking', 'data': '100', 'icon': 'assets/premium.svg'},
    {'head': 'NRI Parking', 'bottom':'Services', 'data': '100', 'icon': 'assets/nri.svg'},
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: ColorUtils.primarycolor(),
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        toolbarHeight: 44, // Adjust height to fit the AppBar
        title: const Text(
          "Our Services",
          style: TextStyle(
            color: Colors.black, // Set the text color to white
          ),
        ),
        // leading: const Icon(
        //   Icons.arrow_back, // Example leading icon
        //   color: Colors.white, // Set the leading icon color to white
        // ),
        // Optionally, you can set the actions if needed
        actions: const [
          // Add any action icons here if needed
        ],
      ),




      body: _buildRamScreen(),


    );
  }


  Widget _buildRamScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [



                  const SizedBox(height: 20,),
                  _buildGridView(),

                  const SizedBox(height: 20,),


                  // Container(
                  //   alignment: Alignment.centerLeft, // Aligns the text to the left
                  //   child: Text(
                  //     "Nearby Parking",
                  //     style: TextStyle(
                  //       fontSize: 14, // Set text size to 14
                  //       // You can add more styling options here, such as fontWeight, color, etc.
                  //     ),
                  //   ),
                  // ),
                  // SizedBox(height: 15,),
                  // SizedBox(
                  //   height: 82, // Adjust the height based on your needs
                  //   child: Container(
                  //     decoration: BoxDecoration(
                  //       borderRadius: BorderRadius.circular(5), // Circular border radius
                  //       border: Border.all(
                  //         color: ColorUtils.primarycolor(), // Border color
                  //         width: 1.0, // Border width
                  //       ),
                  //     ),
                  //     child: ClipRRect(
                  //       borderRadius: BorderRadius.circular(5), // Ensure the corners are rounded
                  //       child: GoogleMap(
                  //         onMapCreated: (GoogleMapController controller) {
                  //           _mapController = controller;
                  //           if (widget.initialPosition != null) {
                  //             _mapController!.animateCamera(
                  //                 CameraUpdate.newLatLng(widget.initialPosition!));
                  //           }
                  //         },
                  //         myLocationEnabled: true,
                  //         initialCameraPosition: CameraPosition(
                  //           target: _center,
                  //           zoom: 12.0,
                  //         ),
                  //         zoomControlsEnabled: false,
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  const SizedBox(height: 15,),


                  // Padding(
                  //   padding: const EdgeInsets.symmetric( horizontal: 15),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //     children: [
                  //       Expanded(
                  //         flex: 1,
                  //         child: Container(
                  //           decoration: BoxDecoration(
                  //             borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                  //
                  //             color: ColorUtils.primarycolor(), // Your custom background color (teal)
                  //           ),
                  //           child: SizedBox(
                  //             width: 164, // Adjust width as needed
                  //             height: 50, // Adjust height as needed
                  //             child: ElevatedButton(
                  //               onPressed: () {
                  //                 // Navigator.of(context).pop();
                  //               },
                  //               style: ElevatedButton.styleFrom(
                  //                 backgroundColor: ColorUtils.primarycolor(), // Text color (white)
                  //                 shape: RoundedRectangleBorder(
                  //                   borderRadius: BorderRadius.circular(5), // Adjust the border radius as needed
                  //                 ),
                  //               ),
                  //               child: const Row(
                  //                 mainAxisSize: MainAxisSize.min,
                  //                 children: [
                  //
                  //
                  //                   Text(
                  //                     "Corporate Solutions",
                  //                     style: TextStyle(color: Colors.white,fontSize: 12), // Text color (white)
                  //                   ),
                  //                 ],
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ),
                  //       const SizedBox(width: 1),
                  //       Expanded(
                  //         flex: 1,
                  //         child: Container(
                  //           decoration: BoxDecoration(
                  //             borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)), // Adjust the border radius as needed
                  //             color: ColorUtils.primarycolor(), // Your custom background color (teal)
                  //           ),
                  //           child: SizedBox(
                  //             width: 163, // Adjust width as needed
                  //             height: 50, // Adjust height as needed
                  //             child: ElevatedButton(
                  //               onPressed: () {
                  //                 // Navigator.of(context).pop();
                  //               },
                  //               style: ElevatedButton.styleFrom(
                  //                 backgroundColor: ColorUtils.primarycolor(), // Background color
                  //                 shape: RoundedRectangleBorder(
                  //                   borderRadius: BorderRadius.circular(5), // Adjust the border radius as needed
                  //                 ),
                  //               ),
                  //               child: const Row(
                  //
                  //                 children: [
                  //                   Text(
                  //                     "Commercial Services",
                  //                     style: TextStyle(color: Colors.white,fontSize: 12), // Text color (white)
                  //                   ),
                  //
                  //                 ],
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ),
                  //
                  //     ],
                  //   ),
                  // ),

                  const SizedBox(height: 15,),

                ],
              ),

          );













  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.symmetric( horizontal: 11),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        // Disable GridView's own scrolling
        shrinkWrap: true,
        // Expand to fit content
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Number of items per row
          crossAxisSpacing: 5.0, // Space between items horizontally
          // mainAxisSpacing: 1.0, // Space between items vertically
          childAspectRatio: 1.0, // Aspect ratio of each item
        ),
        itemCount: ramData.length,
        itemBuilder: (context, index) {
          return _buildGridItem(context,index);
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        // Navigate based on the index
        switch (index) {
          case 0: // Book Parking
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChooseParkingPage(userId: widget.userId,)),
            );
            break;
          case 1: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParkingPage(userId: widget.userId,)),
            );
            break;
          case 2: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  BlockSpot( userId: widget.userId,)),
            );
            break;
          case 3: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen(userid: widget.userId,title:"Explore Parking Space(s)")),
            );
            break;
          case 4: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  favourites(
                userid: widget.userId,
              )),
            );
            break;
          case 5: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  mybusiness(
                vendorId: widget.userId,
              )),
            );
            break;
          case 6: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>const commercial()),
            );
            break;
          case 7: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>   const VendorRegister()),
            );
            break;
          case 8: // My Bookings
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const premium()),
          );
            break;
          case 9: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const nri()),
            );
            break;
        // Add more cases for other indices if needed
          default:
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: BoxDecoration(
            // color: Colors.white, // Background color of the item
            borderRadius: BorderRadius.circular(5), // Circular border radius
            border: Border.all(
              color: Colors.white, // Change color based on selection
              width: 0.5, // Border width
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Center align text
            children: [
              Container(
                // decoration: BoxDecoration(
                //   shape: BoxShape.circle,
                //   border: Border.all(  // Circular border (outline)
                //     color:  Colors.blue, // Change color based on selection
                //     width: 0.5, // Border width (you can adjust this)
                //   ),
                // ),
                child: ramData[index]['icon'] is String
                    ? SvgPicture.asset(
                  ramData[index]['icon'], // Path to the SVG
                  height: 40, // Adjust size as needed
                  width: 40,
                )
                    : CircleAvatar(
                  radius: 26,
                  backgroundColor: ColorUtils.primarycolor(),
                  child: Icon(
                    ramData[index]['icon'], // Use icon from ramData
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4), // Space between icon and text
              Column(
                children: [
                  Text(
                    ramData[index]['head']!,
                    style: GoogleFonts.rubik( // You can change "Poppins" to any preferred font
                      fontSize: 11,
                      color: Colors.black,
                      height: 1.2, // Adjust line height (reduce spacing)
                    ),
                  ),
                  Text(
                    ramData[index]['bottom']!,
                    style: GoogleFonts.rubik(
                      fontSize: 12,
                      // fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2, // Adjust line height (reduce spacing)
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }




}
