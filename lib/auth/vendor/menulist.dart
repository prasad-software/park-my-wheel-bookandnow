import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/auth/vendor/menus/managebookings.dart';
import 'package:mywheels/auth/vendor/menus/summaryreport.dart';
import 'package:mywheels/auth/vendor/menus/vendorabout.dart';
import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'package:mywheels/auth/vendor/subscription/addsubscribe.dart';
import 'package:mywheels/auth/vendor/subscription/vendorsubscriptonbooking.dart';
import 'package:mywheels/privacypolicydataprivacy.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdpage.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/vendor/vendorsupport.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/colorcode.dart';
import 'bookings.dart';

import 'meetings/meetinglist.dart';
import 'menus/bookingtransaction.dart';
import 'menus/vendorpayments.dart';
import 'menusscreen.dart';
import 'myaccount.dart';



class listmenu extends StatefulWidget {
  final String vendorid;
  const listmenu({super.key,

    required this.vendorid,
    // required this.userName
  });

  @override
  _menuPageState createState() => _menuPageState();
}



class _menuPageState extends State<listmenu> {
  String? _menuImageUrl;

  int _selecteddIndex = 4;
  File? _selectedImage;
  Future<void> _terms(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(
        headers: <String, String>{'my_header_key': 'my_header_value'},
      ),
    )) {
      throw Exception('Could not launch $url');
    }
  }
  void _navigateToPage(int index) {
    setState(() {
      _selecteddIndex = index;
    });
    Navigator.pushReplacement(
      context,
      RightToLeftPageRoute(page: _pagess[index]), // Use the custom route here
    );
  }
  late List<Widget> _pagess;
  void _onTabChange(int index) {
    _navigateToPage(index);
  }
  @override
  void initState() {
    super.initState();
    _fetchVendorData();

    _pagess = [
      vendordashScreen(vendorid: widget.vendorid),
      Bookings(vendorid: widget.vendorid),
      qrcodeallowpark(vendorid: widget.vendorid),
      Third(vendorid: widget.vendorid),
      menu(vendorid: widget.vendorid),
    ];

  }
  _openGoogleDrivePDF() async {
    const url = 'https://drive.google.com/file/d/1j1MX858QE957CnXWXjrRHzY-o6rYn289/view?pli=1';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not open the URL';
    }
  }

  void _showLogoutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                'Are you sure you want to logout?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(
                    width: 90,
                    height: 35,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: ColorUtils.primarycolor(), // <-- Ensure it's a method or remove ()
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();

                        // Try to get vendor ID from widget or SharedPreferences
                        String? vendorId = widget.vendorid ?? prefs.getString('vendorid');

                        print("Logout button clicked. Vendor ID: $vendorId");

                        if (vendorId != null && vendorId.isNotEmpty) {
                          try {
                            final response = await http.post(
                              Uri.parse("${ApiConfig.baseUrl}vendor/vendorlogout"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({"_id": vendorId}),
                            );

                            print("Status Code: ${response.statusCode}");
                            print("Response Body: ${response.body}");

                            final responseData = jsonDecode(response.body);

                            if (response.statusCode == 200) {
                              print("Logout successful: ${responseData['message']}");

                              // Clear SharedPreferences
                              await prefs.clear();

                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const splashlogin()),
                                      (Route<dynamic> route) => false,
                                );
                              }
                            } else {
                              print("Logout failed: ${responseData['message'] ?? 'Unknown error'}");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Logout failed: ${responseData['message']}")),
                              );
                            }
                          } catch (e) {
                            print("Logout API Error: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Logout failed. Please try again.")),
                            );
                          }
                        } else {
                          print("No vendor ID found in widget or SharedPreferences");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Vendor ID not found. Please login again.")),
                          );
                        }
                      },

                      child: Text('Logout', style: GoogleFonts.poppins(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    height: 35,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: ColorUtils.primarycolor(),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Logging out? Help is just a click away —", style: GoogleFonts.poppins()),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            ' check the Support section anytime!',
                            style: GoogleFonts.poppins(),
                            overflow: TextOverflow.visible, // optional
                            softWrap: true, // allows line break
                          ),
                          const SizedBox(width: 5),
                          // Add icon or button if needed
                        ],
                      ),

                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchVendorData() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}')
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _menuImageUrl = data['data']['image']; // Fetch menu image URL
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
        backgroundColor: ColorUtils.secondarycolor(),// A medium grey color

        appBar: AppBar(
          backgroundColor: ColorUtils.secondarycolor(),
          leading:    IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => vendordashScreen(vendorid: widget.vendorid),
                ),
              );
            },
            icon: const Icon(Icons.close_rounded), // Wrap in Icon widget
          ),
          title:  Text(
            'Menu',
            style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
          ),
          actions: [
            IconButton(
              onPressed: () {
                _showLogoutBottomSheet(context); // Call the function with parentheses
              },
              icon: Icon(
                Icons.power_settings_new,
                color: ColorUtils.primarycolor(), // Custom color utility
              ),
            ),

            const SizedBox(width: 10), // Adds spacing between the IconButton and the next widget (if any)
          ],


        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  // Profile Card with Arrow icon and circular right border
                  _buildListTile(
                    context,
                    Icons.person,
                    'My Account',
                    'Personalize your parking profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Myaccount(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),
                  _buildListTile(
                    context,
                    Icons.attach_money_outlined,
                    'Premium Package',
                    'Exclusive benefits, top-tier access',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => viewplan(vendorid: widget.vendorid,),
                        ),
                      );
                    },
                  ),
                  // _buildListTile(
                  //   context,
                  //   Icons.attach_money_outlined,
                  //   'dummy Fee',
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => dummy(vendorid: widget.vendorid,),
                  //       ),
                  //     );
                  //   },
                  // ),
                  _buildListTile(
                    context,
                    Icons.subscriptions_outlined,
                    'Subscription',
                    'Hassle-free monthly parking plans',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => viewsubscriptionamout(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),

                  // Payments Card with Arrow icon and circular right border

                  _buildListTile(
                    context,
                    Icons.book,
                    'Booking Transaction',
                    'Track and manage all reservations',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleBookingListScreen(vendorid: widget.vendorid,),
                        ),
                      );
                    },
                  ),
                  _buildListTile(
                    context,
                    Icons.payment,
                    'Vendor Payouts',
                    'Secure and easy payment processing',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => vendorpayments(vendorid: widget.vendorid,),
                        ),
                      );
                    },
                  ),
                  // Subscription Card with Arrow icon and circular right border


                  // Manage Bookings Card with Arrow icon and circular right border
                  _buildListTile(
                    context,
                    Icons.book,
                    'Manage Bookings',
                    'Track, modify, and cancel reservations',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => managebooking(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),

                  _buildListTile(
                    context,
                    Icons.summarize_outlined,
                    'Summary Report',
                    'Print bookings summary by date range',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SummaryReportScreen(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),


                  // Manage Parking Area Card with Arrow icon and circular right border


                  // Help & Support Card with Arrow icon and circular right border
                  _buildListTile(
                    context,
                    Icons.support_agent,
                    'Help & Support',
                    'Get assistance anytime, anywhere',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => vendorsupport(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),

                  // Schedule Meeting Card with Arrow icon and circular right border
                  _buildListTile(
                    context,
                    Icons.meeting_room,
                    'Advertise with us',
                    'Promote your parking services',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => meetinglist(vendorid: widget.vendorid),
                        ),
                      );
                    },
                  ),
                  _buildListTile(
                    context,
                    Icons.privacy_tip, // Using the privacy tip icon
                    'Privacy & Policy',
                    'Read our terms & conditions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VendorPrivacy(

                          ),
                        ),
                      );
                    },
                  ),
                  // About Card with Arrow icon and circular right border
                  _buildListTile(
                    context,
                    Icons.info_outline,
                    'About ParkMyWheels',
                    'Learn more about our platform',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VendorAbout(),
                        ),
                      );
                    },
                  ),

                  // _buildListTile(
                  //   context,
                  //   Icons.info_outline,
                  //   'Testing',
                  //   'Learn more about our platform',
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) =>  VehicleSwitcherPage(vendorid: widget.vendorid,),
                  //       ),
                  //     );
                  //   },
                  // ),


                ],
              ),
            ),
          ),
        ),

// Helper widget to build each ListTile with a circular right border and an arrow icon at the end


        bottomNavigationBar: BottomNavBar(
          selectedIndex: _selecteddIndex,
          onTabChange: _onTabChange,
          menuImageUrl: _menuImageUrl,
        )

    );

  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String subtitle, {Function()? onTap}) {
    return Card(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), // Reduced padding
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4), // Reduces height further
        leading: Icon(icon, size: 20, color: ColorUtils.primarycolor()), // Smaller icon
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis, // Prevents text overflow
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: ColorUtils.primarycolor()), // Arrow beside title
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }

}





class RightToLeftPageRoute extends PageRouteBuilder {
  final Widget page;

  RightToLeftPageRoute({required this.page})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // Start from the right
      const end = Offset.zero; // End at the original position
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}





