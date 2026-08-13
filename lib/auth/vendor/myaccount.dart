import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/vendorprofile.dart';


import 'package:mywheels/config/authconfig.dart';

import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';

import '../../../config/colorcode.dart';

import 'menus/accountdetails.dart';
import 'menus/kycdetails.dart';



class Myaccount extends StatefulWidget {
  final String vendorid;
  const Myaccount({super.key,

    required this.vendorid,
    // required this.userName
  });

  @override
  _MyaccountState createState() => _MyaccountState();
}

class _MyaccountState extends State<Myaccount> {
  bool _isLoading = false;
  final bool _hasUploadedDocuments = false;
  Vendor? _vendor;
  String verificationStatus = 'Not Verified'; // Default value

  String? status;
  late List<Widget> _pagess;
  @override
  void initState() {
    super.initState();

    _fetchExistingData();

  }
  Future<void> _fetchExistingData() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/getkyc/${widget.vendorid}');
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        var data = jsonResponse['data'];

        // Print the fetched data
        print('Fetched data: $data');

        setState(() {
          status = data['status'];
          verificationStatus = status == 'Verified' ? 'Verified' : 'Not Verified'; // Update verificationStatus
        });
      } else {
        print('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching existing data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold( backgroundColor: const Color(0xFFF1F2F6) ,
      appBar: AppBar(
        backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(
          'My Account',
          style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
        titleSpacing: 0, // Reduces space between the leading icon and the title
      ),

      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => profilepassword(vendorid: widget.vendorid),
                  //   ),
                  // );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => vendorProfilePage(vendorid: widget.vendorid),
                    ),
                  );
                },
                child: Card(color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  elevation: 4, // Shadow for depth
                  margin: const EdgeInsets.all(5), // Outer margin
                  child: Padding(
                    padding: const EdgeInsets.all(10), // Inner padding for spacing
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
                      children: [
                        // Left Section: Icon and Texts
                        Row(
                          children: [
                            Icon(
                                Icons.person,
                                size: 36,
                                color:  ColorUtils.primarycolor()

                            ),
                            const SizedBox(width: 10), // Spacing between icon and text
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
                              children: [
                                 Row(
                                  children: [
                                    Text(
                                      "Profile",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87, // Darker text for readability
                                      ),
                                    ),
                                    const SizedBox(width: 10,),

                                  ],
                                ),

                                Row(
                                  children: [
                                    Text(
                                      "Update your profile",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[700], // Softer text color
                                      ),
                                    ),
                                  ],
                                ),


                              ],
                            ),
                          ],
                        ),
                        // Right Section: Arrow Icon
                        Icon(
                          Icons.arrow_forward,
                          size: 24,
                          color: ColorUtils.primarycolor(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NextPage(vendorid: widget.vendorid),
                    ),
                  );
                },
                child: Card(color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  elevation: 4, // Shadow for depth
                  margin: const EdgeInsets.all(4), // Outer margin
                  child: Padding(
                    padding: const EdgeInsets.all(8), // Inner padding for spacing
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
                      children: [
                        // Left Section: Icon and Texts
                        Row(
                          children: [
                            Icon(
                                Icons.verified,
                                size: 36,
                                color:  ColorUtils.primarycolor()

                            ),
                            const SizedBox(width: 10), // Spacing between icon and text
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
                              children: [
                                Row(
                                  children: [
                                     Text(
                                      "Onboarding Process",
                                      style:  GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87, // Darker text for readability
                                      ),
                                    ),

                                    Card(
                                      color: verificationStatus == 'Verified' ? Colors.green : Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                        child: Text(
                                          verificationStatus, // This will now display "Verified" or "Not Verified"
                                          style:  GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white, // Change color based on status
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                Row(
                                  children: [
                                    Text(
                                      "Upload government documents and get verified",
                                      style:  GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey[700], // Softer text color
                                      ),
                                    ),
                                  ],
                                ),


                              ],
                            ),
                          ],
                        ),
                        // Right Section: Arrow Icon
                        Icon(
                          Icons.arrow_forward,
                          size: 24,
                          color: ColorUtils.primarycolor(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => managearea(vendorid: widget.vendorid),
              //       ),
              //     );
              //   },
              //   child: Card(color: Colors.white,
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(10), // Rounded corners
              //     ),
              //     elevation: 4, // Shadow for depth
              //     margin: const EdgeInsets.all(5), // Outer margin
              //     child: Padding(
              //       padding: const EdgeInsets.all(10), // Inner padding for spacing
              //       child: Row(
              //         crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
              //         children: [
              //           // Left Section: Icon and Texts
              //           Row(
              //             children: [
              //               Icon(
              //                   Icons.local_parking_sharp,
              //                   size: 36,
              //                   color:  ColorUtils.primarycolor()
              //
              //               ),
              //               const SizedBox(width: 10), // Spacing between icon and text
              //               Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
              //                 children: [
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Parking Slots",
              //                         style:  GoogleFonts.poppins(
              //                           fontSize: 18,
              //                           fontWeight: FontWeight.bold,
              //                           color: Colors.black87, // Darker text for readability
              //                         ),
              //                       ),
              //
              //
              //                     ],
              //                   ),
              //
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Manage your Parking Slot",
              //                         style:  GoogleFonts.poppins(
              //                           fontSize: 10,
              //                           color: Colors.grey[700], // Softer text color
              //                         ),
              //                       ),
              //                     ],
              //                   ),
              //
              //
              //                 ],
              //               ),
              //             ],
              //           ),
              //           // Right Section: Arrow Icon
              //           Icon(
              //             Icons.arrow_forward,
              //             size: 24,
              //             color: ColorUtils.primarycolor(),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => Addamenties(   vendorid: widget.vendorid,
              //           onEditSuccess: () {
              //             setState(() {
              //               _selecteddIndex = 2; // Change to the third tab
              //             });
              //           },),
              //       ),
              //     );
              //   },
              //   child: Card(color: Colors.white,
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(10), // Rounded corners
              //     ),
              //     elevation: 4, // Shadow for depth
              //     margin: const EdgeInsets.all(5), // Outer margin
              //     child: Padding(
              //       padding: const EdgeInsets.all(10), // Inner padding for spacing
              //       child: Row(
              //         crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
              //         children: [
              //           // Left Section: Icon and Texts
              //           Row(
              //             children: [
              //               Icon(
              //                   Icons.local_florist,
              //                   size: 36,
              //                   color:  ColorUtils.primarycolor()
              //
              //               ),
              //               const SizedBox(width: 10), // Spacing between icon and text
              //               Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
              //                 children: [
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Amenities",
              //                         style:  GoogleFonts.poppins(
              //                           fontSize: 18,
              //                           fontWeight: FontWeight.bold,
              //                           color: Colors.black87, // Darker text for readability
              //                         ),
              //                       ),
              //
              //
              //                     ],
              //                   ),
              //
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Manage your Amenities",
              //                         style: TextStyle(
              //                           fontSize: 10,
              //                           color: Colors.grey[700], // Softer text color
              //                         ),
              //                       ),
              //                     ],
              //                   ),
              //
              //
              //                 ],
              //               ),
              //             ],
              //           ),
              //           // Right Section: Arrow Icon
              //           Icon(
              //             Icons.arrow_forward,
              //             size: 24,
              //             color: ColorUtils.primarycolor(),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => listmParkingLotScreen(vendorid: widget.vendorid),
              //       ),
              //     );
              //   },
              //   child: Card(color: Colors.white,
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(10), // Rounded corners
              //     ),
              //     elevation: 4, // Shadow for depth
              //     margin: const EdgeInsets.all(5), // Outer margin
              //     child: Padding(
              //       padding: const EdgeInsets.all(10), // Inner padding for spacing
              //       child: Row(
              //         crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
              //         children: [
              //           // Left Section: Icon and Texts
              //           Row(
              //             children: [
              //               Icon(
              //                   Icons.receipt,
              //                   size: 36,
              //                   color:  ColorUtils.primarycolor()
              //
              //               ),
              //               const SizedBox(width: 10), // Spacing between icon and text
              //               Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
              //                 children: [
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Charge sheet",
              //                         style: TextStyle(
              //                           fontSize: 18,
              //                           fontWeight: FontWeight.bold,
              //                           color: Colors.black87, // Darker text for readability
              //                         ),
              //                       ),
              //
              //
              //                     ],
              //                   ),
              //
              //                   Row(
              //                     children: [
              //                       Text(
              //                         "Manage your Charge sheet",
              //                         style: TextStyle(
              //                           fontSize: 10,
              //                           color: Colors.grey[700], // Softer text color
              //                         ),
              //                       ),
              //                     ],
              //                   ),
              //
              //
              //                 ],
              //               ),
              //             ],
              //           ),
              //           // Right Section: Arrow Icon
              //           Icon(
              //             Icons.arrow_forward,
              //             size: 24,
              //             color: ColorUtils.primarycolor(),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountDetails(vendorid: widget.vendorid),
                    ),
                  );
                },
                child: Card(color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  elevation: 4, // Shadow for depth
                  margin: const EdgeInsets.all(5), // Outer margin
                  child: Padding(
                    padding: const EdgeInsets.all(10), // Inner padding for spacing
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between left and right sections
                      children: [
                        // Left Section: Icon and Texts
                        Row(
                          children: [
                            Icon(
                                Icons.account_balance,
                                size: 36,
                                color:  ColorUtils.primarycolor()

                            ),
                            const SizedBox(width: 10), // Spacing between icon and text
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // Align texts to the start
                              children: [
                                 Row(
                                  children: [
                                    Text(
                                      "Account Details",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87, // Darker text for readability
                                      ),
                                    ),


                                  ],
                                ),

                                Row(
                                  children: [
                                    Text(
                                      "Manage your Settlement Account details",
                                      style:GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[700], // Softer text color
                                      ),
                                    ),
                                  ],
                                ),


                              ],
                            ),
                          ],
                        ),
                        // Right Section: Arrow Icon
                        Icon(
                          Icons.arrow_forward,
                          size: 24,
                          color: ColorUtils.primarycolor(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),



              // Circle Avatar with Person Icon







            ],
          ),
        ),
      ),
      ),

    );
  }

}



