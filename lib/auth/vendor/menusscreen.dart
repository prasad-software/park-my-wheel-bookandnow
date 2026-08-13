import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/auth/vendor/menulist.dart';
import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdpage.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/colorcode.dart';
import 'bookings.dart';




class menu extends StatefulWidget {
  final String vendorid;
  const menu({super.key,

    required this.vendorid,
    // required this.userName
  });

  @override
  _menuPageState createState() => _menuPageState();
}



class _menuPageState extends State<menu> {
  String? _menuImageUrl;
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  Future<void> _vendorLogin() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const String apiUrl = '${ApiConfig.baseUrl}vendor/profilepass'; // Replace with your actual API endpoint
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorId': widget.vendorid,
          'password': _passwordController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Success: Handle the vendor details
        final vendorDetails = responseData;
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Login successful: Welcome ${vendorDetails['vendorName']}')),
        // );


        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WillPopScope(
              onWillPop: () async {
                // When back is pressed, navigate to home page
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => vendordashScreen(vendorid: widget.vendorid),
                  ),
                );
                return false; // Prevent default back behavior
              },
              child: listmenu(vendorid: widget.vendorid),
            ),
          ),
        );
      } else {
        // Handle errors based on status code
        String errorMessage = responseData['message'] ?? 'An error occurred';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to the server')),
      );
      print('Error during login: $e');
    }
  }
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                Padding(
                  padding: const EdgeInsets.only(left: 25.0, right: 25.0, top: 0),
                  child: SizedBox(
                    height: 80,
                    child: Image.asset("assets/login.png"),
                  ),
                ),
                const SizedBox(height: 20.0),
                const SizedBox(height: 40),
                CustomTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  keyboard: TextInputType.text,
                  obscure: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  inputFormatter: const [],
                  label: 'Password',
                  suffix: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      size: 14,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  onSubmitted: (value) {
                    _vendorLogin(); // Trigger login on submit
                  },
                  hint: 'Please enter your Password',
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _vendorLogin, // Disable button when loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor(),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Verify',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          ),
        ),
    bottomNavigationBar: BottomNavBar(
      selectedIndex: _selecteddIndex,
      onTabChange: _onTabChange,
      menuImageUrl: _menuImageUrl,
    ),
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





