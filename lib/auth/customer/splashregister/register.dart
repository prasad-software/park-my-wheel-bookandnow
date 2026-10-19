import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdbottom.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/vendor/vendorforgotpassoword.dart';

import 'package:mywheels/auth/vendor/vendorregister.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tab_container/tab_container.dart';
import '../customerdash.dart';
import 'Fogot password.dart';


import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:fluttertoast/fluttertoast.dart';
import 'customerregister.dart';

String _extractErrorMessage(String responseBody, {int? statusCode}) {
  try {
    final decoded = json.decode(responseBody);
    if (decoded is Map) {
      if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
        return decoded['message'].toString().trim();
      }
      if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
        return decoded['error'].toString().trim();
      }
      if (decoded['msg'] != null && decoded['msg'].toString().trim().isNotEmpty) {
        return decoded['msg'].toString().trim();
      }
    }
  } catch (_) {}

  final trimmed = responseBody.trim();
  if (trimmed.isNotEmpty && !trimmed.startsWith('<') && trimmed.length < 200) {
    return trimmed;
  }
  if (statusCode == 401) {
    return 'Incorrect password';
  }
  return 'Login failed. Please try again.';
}

void _showToast(BuildContext context, String message) {
  try {
    final fToast = FToast().init(context);
    fToast.removeCustomToast();
    fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xDD3A3A3A),
          borderRadius: BorderRadius.circular(25.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      positionedToastBuilder: (context, child, gravity) {
        return Positioned(
          bottom: 110.0,
          left: 20.0,
          right: 20.0,
          child: Center(child: child),
        );
      },
      toastDuration: const Duration(seconds: 2),
    );
  } catch (e) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xCC333333),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}

class splashlogin extends StatefulWidget {
  const splashlogin({super.key});


  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<splashlogin>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  int selectedTabIndex = 0;
  @override
  void initState() {
    super.initState();
    _controller = TabController(vsync: this, length: 2);
    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
        print('Selected Tab Index: $selectedTabIndex');  // Print statement to check the selected tab index
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Set SystemUiOverlayStyle based on theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light, // For iOS
    ));
    return Scaffold(
      resizeToAvoidBottomInset: true,
        backgroundColor: ColorUtils.first(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

            Container(
              // width: 250,
              // height: 150,
              child: Image.asset(
                'assets/t.gif',
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(
              width: 200,
              height: 150,
              child: Image.asset(
                height: 50,
                // width: 300,
                'assets/lights.png',
                fit: BoxFit.contain,
              ),
            ),
            buildTabContainer(),
          ],
        ),
      ),),
    );
  }

  Widget buildTabContainer() {
    return TabContainer(
      controller: _controller,  // Ensure the controller is passed here
      borderRadius: BorderRadius.circular(20),
      tabEdge: TabEdge.top,
      curve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
        return SlideTransition(
          position: Tween(
            begin: const Offset(0.2, 0.0),
            end: const Offset(0.0, 0.0),
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      selectedTextStyle: TextStyle(
        fontSize: 15.0,
        color: ColorUtils.primarycolor(),
      ),
      unselectedTextStyle: const TextStyle(
        fontSize: 13.0,
        color: Colors.white, // Set default unselected color
      ),
      tabs: _getTabs(),
      children: const [
        CustomerRegisterForm(),
        VendorRegisterForm(),
      ],
    );
  }

  List<Widget> _getTabs() {
    return [
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: selectedTabIndex == 0 ?  ColorUtils.primarycolor() : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'User',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 0 ?  ColorUtils.primarycolor() : Colors.white,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store,
            size: 16,
            color: selectedTabIndex == 1 ? ColorUtils.primarycolor() : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Parking Vendor',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? ColorUtils.primarycolor(): Colors.white,
            ),
          ),
        ],
      ),
    ];
  }




}



class CustomerRegisterForm extends StatefulWidget {
  const CustomerRegisterForm({super.key});

  @override
  _CustomerRegisterFormState createState() => _CustomerRegisterFormState();
}

class _CustomerRegisterFormState extends State<CustomerRegisterForm> {
  final TextEditingController _amobileNumberController = TextEditingController();
  final TextEditingController _apasswordController = TextEditingController();
  final FocusNode _apasswordFocusNode = FocusNode();
  final FocusNode _amobileNumberFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  Future<void> login(BuildContext context) async {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    String mobileNumber = _amobileNumberController.text.trim();
    String password = _apasswordController.text.trim();

    // Validate mobile number and password
    if (mobileNumber.length != 10 || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number and password')),
      );
      return;
    }

    String userfcmToken = 'dummy_token_12345678901234567890';
    try {
      userfcmToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 2)) ?? 'dummy_token_12345678901234567890';
    } catch (e) {
      print('[LOGIN] Warning: Failed to retrieve FCM token: $e');
    }

    print("Mobile Number: $mobileNumber");
    print("Password: $password");

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobile': mobileNumber,
          'password': password,
          'userfcmToken': userfcmToken,
        }),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String userId = data['id'] ?? '';

        if (userId.isNotEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('id', userId);
          await prefs.setInt('login_status', 1);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => customdashScreen(userId: userId),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID not found in response.')),
          );
        }
      } else {
        _showToast(context, _extractErrorMessage(response.body, statusCode: response.statusCode));
      }
    } catch (error) {
      print('[LOGIN] API call failed: $error');
      _showToast(context, 'Login error. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0,right: 16.0),

      child: SingleChildScrollView(
        child: Column(
          children: [
            // Container(
            //   child: Image.asset("assets/login.png"),
            // ),
            const SizedBox(height: 30.0),
            Container(
              child: Text("Login to Continue",  style: GoogleFonts.poppins(fontWeight: FontWeight.bold,color:Colors.black ),),

            ),
            Container(
                child: Text(" Quick, secure access to parking",  style: GoogleFonts.poppins(fontSize: 10),),

            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _amobileNumberController,
                    focusNode: _amobileNumberFocusNode,
                    keyboard: TextInputType.phone,
                    obscure: false,
                    textInputAction: TextInputAction.next,
                    inputFormatter: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    label: 'Mobile Number',
                    hint: 'Enter your 10-digit number',
                  ),
                ),
                const SizedBox(width: 10), // Add spacing between fields
                Expanded(
                  child: CustomTextField(
                    controller: _apasswordController,
                    focusNode: _apasswordFocusNode,
                    keyboard: TextInputType.text,
                    obscure: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    inputFormatter: const [],
                    label: 'Password',
                    hint: 'Please enter your password',
                    onSubmitted: (value) {
                      FocusScope.of(context).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                      login(context);
                    },
                    suffix: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,size: 14,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible; // Toggle visibility
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
                    : GestureDetector(
                  onTap: () {
                    // Call the login function when the icon is tapped
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    login(context);
                  },
                  child: Container(
                    width: 36, // Width of the square
                    height: 36, // Height of the square
                    decoration: BoxDecoration(
                      color: ColorUtils.primarycolor(), // Background color of the square
                      borderRadius: BorderRadius.circular(4), // Optional: Rounded corners
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Adjust the padding value as needed
                      child: ClipRect( // Clip the image to fit the container
                        child: Image.asset(
                          'assets/checked.png', // Replace with your image path
                          width: 10, // Width of the image
                          height: 10, // Height of the image
                          fit: BoxFit.cover, // Ensure the image covers the square
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 5.0),

            // const SizedBox(height: 5.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align to the left
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerRegister()), // Navigate to Registration Page
                    );
                  },
                  child: Container(
                    // Optional, for spacing around the container
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Ensures that the Row takes up only as much space as needed
                      children: [
                        // Image.asset(
                        //   'assets/user.png', // Replace with the correct path to your asset
                        //   color: Colors.black, // You can change the color as needed
                        //   width: 24, // Set the desired size
                        //   height: 24, // Set the desired size
                        // ),
                   // Optional, adds some space between the icon and text
                        Text(
                          ' New User? Signup ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ColorUtils.primarycolor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5,),
                GestureDetector(
                  onTap: () {
                    // Navigate to ForgotForm page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotForm()),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.poppins(fontSize: 14, color: ColorUtils.primarycolor()),
                  ),
                ),
              ],
            ),




            Padding(
              padding: const EdgeInsets.only(left: 70.0,right: 70.0),
              child: Container(
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Left Divider
                    // Expanded(
                    //   child: Divider(
                    //     color: Colors.black,  // Set the divider color
                    //     thickness: 0.5,         // Set the thickness of the divider
                    //   ),
                    // ),

                    // Text
                    // Text(
                    //   " or signin with ",
                    //   style: TextStyle(
                    //     fontFamily: "Poppins-Medium",
                    //     color: Colors.black,
                    //   ),
                    // ),
                    //
                    // // Right Divider
                    // Expanded(
                    //   child: Divider(
                    //     color: Colors.black,  // Set the divider color
                    //     thickness: 0.5,         // Set the thickness of the divider
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),


          ],
        ),
      ),
    );
  }
}


class VendorRegisterForm extends StatefulWidget {
  const VendorRegisterForm({super.key});

  @override
  _VendorRegisterFormState createState() => _VendorRegisterFormState();
}

class _VendorRegisterFormState extends State<VendorRegisterForm> {
  final TextEditingController _vendormobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _vendormobileFocusNode = FocusNode();
  bool _isLoading = false; // Define the _isLoading variable
  bool _isPasswordVisible = false;
  Future<void> vendorlogin(BuildContext context) async {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    String mobileNumber = _vendormobileController.text.trim();
    String password = _passwordController.text.trim();

    // Validate mobile number and password
    if (mobileNumber.length != 10 || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number and password'),
        ),
      );
      return;
    }

    // Get FCM token
    String userfcmToken = 'dummy_token_12345678901234567890';
    try {
      userfcmToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 2)) ?? 'dummy_token_12345678901234567890';
    } catch (e) {
      print('[LOGIN] Warning: Failed to retrieve FCM token: $e');
    }
    if (userfcmToken.isEmpty) {
      print('[LOGIN] Warning: Failed to retrieve FCM token');
    }

    print('[LOGIN] Mobile Number: $mobileNumber');
    print('[LOGIN] Password: $password');
    print('[LOGIN] FCM Token: $userfcmToken');
    print('[LOGIN] Sending login request to ${ApiConfig.baseUrl}vendor/login');

    setState(() {
      _isLoading = true;
    });

    try {
      // Login API call
      final loginResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobile': mobileNumber,
          'password': password,
          'fcmToken': userfcmToken,
        }),
      );

      print('[LOGIN] Response status: ${loginResponse.statusCode}');
      print('[LOGIN] Response body: ${loginResponse.body}');

      if (loginResponse.statusCode == 200) {
        try {
          var loginData = json.decode(loginResponse.body);
          print('[LOGIN] Response keys: ${loginData.keys}');

          String vendorId = loginData['vendorId']?.toString() ?? '';
          String newUser = loginData['newuser']?.toString().toLowerCase() ?? 'false';

          print('[LOGIN] Vendor ID: $vendorId');
          print('[LOGIN] Raw newUser from server: ${loginData['newuser']}');
          print('[LOGIN] Initial newUser: $newUser');

          if (vendorId.isNotEmpty) {
            // 🔹 Update vendor status
            final updateResponse = await http.put(
              Uri.parse('${ApiConfig.baseUrl}vendor/newuser'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'vendorId': vendorId,
              }),
            );
            print('[LOGIN] Update Response: ${updateResponse.statusCode}');

            // Save login data
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('vendorId', vendorId);
            await prefs.setInt('login_status', 1);
            print('[LOGIN] Saved to SharedPreferences: vendorId=$vendorId, login_status=1');

            // ✅ Navigation
            print('[NAVIGATION] Final newUser value: $newUser');
            if (newUser == 'true') {
              print('[NAVIGATION] Navigating to vendordashScreen with vendorId: $vendorId');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => vendordashScreen(vendorid: vendorId),
                ),
              );
            } else {
              print('[NAVIGATION] Navigating to manageparkingarea with vendorId: $vendorId');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => manageparkingarea(vendorid: vendorId),
                ),
              );
            }
          } else {
            print('[LOGIN] Vendor ID is empty');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vendor not found in response.')),
            );
          }
        } catch (parseError) {
          print('[LOGIN] JSON parsing error in login response: $parseError');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid response format from server')),
          );
        }
      } else {
        _showToast(context, _extractErrorMessage(loginResponse.body, statusCode: loginResponse.statusCode));
      }
    } catch (error) {
      print('[LOGIN] API call failed: $error');
      _showToast(context, 'Login error. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 15.0),
            Container(
              child:  Text("Login to Continue",  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
            Container(
              child: Text(" Quick, secure access to parking",  style: GoogleFonts.poppins(fontSize: 10),),

            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _vendormobileController,
                    focusNode: _vendormobileFocusNode,
                    keyboard: TextInputType.phone,
                    obscure: false,
                    textInputAction: TextInputAction.next,
                    inputFormatter: [
                      FilteringTextInputFormatter.digitsOnly, // Allow only digits
                      LengthLimitingTextInputFormatter(10),  // Limit to 10 digits
                    ],
                    label: ' Mobile Number',
                    onSubmitted: (value) {},
                    hint: 'Please enter your Mobile Number',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    keyboard: TextInputType.text,
                    obscure: !_isPasswordVisible,
                    // obscure: true,
                    textInputAction: TextInputAction.done,
                    inputFormatter: const [],
                    label: 'Password',
                    suffix: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,size: 14,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    onSubmitted: (value) {
                      FocusScope.of(context).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                      vendorlogin(context);
                    },
                    hint: 'Please enter your Password',
                  ),
                ),
                const SizedBox(width: 5),
                _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
                    : GestureDetector(
                  onTap: () {
                    // Call the login function when the icon is tapped
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    vendorlogin(context);
                  },
                  child: Container(
                    width: 36, // Width of the square
                    height: 36, // Height of the square
                    decoration: BoxDecoration(
                      color: ColorUtils.primarycolor(), // Background color of the square
                      borderRadius: BorderRadius.circular(4), // Optional: Rounded corners
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Adjust the padding value as needed
                      child: ClipRect( // Clip the image to fit the container
                        child: Image.asset(
                          'assets/checked.png', // Replace with your image path
                          width: 10, // Width of the image
                          height: 10, // Height of the image
                          fit: BoxFit.cover, // Ensure the image covers the square
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const vendorForgotForm()),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.poppins(fontSize: 14, color: ColorUtils.primarycolor()),
                  ),
                ),
              ],
            ),
            // Row(
            //   children: [
            //     const Spacer(),
            //     ElevatedButton(
            //       onPressed: () {
            //         vendorlogin(context);
            //       },
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: ColorUtils.primarycolor(),
            //         foregroundColor: Colors.black,
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(5),
            //         ),
            //       ),
            //       child: _isLoading
            //           ? const CircularProgressIndicator() // Show loading indicator
            //           : Row(
            //         mainAxisSize: MainAxisSize.min,
            //         children: [
            //           Image.asset(
            //             'assets/checked.png',color: Colors.white,
            //             width: 20,
            //             height: 20,
            //           ), // Login icon
            //           const SizedBox(width: 8),
            //            Text('Login',  style: GoogleFonts.poppins(color: Colors.white),),
            //         ],
            //       ),
            //     ),
            //     const SizedBox(width: 5), // Extra space if needed
            //   ],
            // ),
            const SizedBox(height: 20.0),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  const VendorRegister()), // Navigate to Vendor Register Page
                );
              },
              child: Container(
                padding: const EdgeInsets.all(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_business, // You can change this icon
                      size: 18, // Adjust the size as needed
                      color: Colors.black,
                    ),
                    const SizedBox(width: 0),
                    Text(
                      ' New Vendor? Register here',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ColorUtils.primarycolor(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2, // 20% of screen height
            ),
          ],
        ),
      ),
    );
  }
}


class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Function(String)? onSubmitted;
  final Widget? suffix;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: textInputAction,
        inputFormatters: inputFormatter,
        style: const TextStyle(
          fontSize: 12, // ✅ Reduce input text size
          color: Colors.black, // Adjust color if needed
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.5),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 20),
          suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 20),
          suffixIcon: suffix,
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}
class addressfiled extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final List<TextInputFormatter> inputFormatter;
  final bool obscure;
  final TextInputAction textInputAction;
  final String label;
  final bool enabled;
  final IconData? prefixIcon;
  final Function(String)? onSubmitted;
  final Color borderColor;

  const addressfiled({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    this.inputFormatter = const [],
    this.obscure = false,
    required this.textInputAction,
    required this.label,
    this.enabled = true,
    this.prefixIcon,
    this.onSubmitted,
    this.borderColor = Colors.grey, // Default border color
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: textInputAction,
        inputFormatters: inputFormatter,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: ColorUtils.primarycolor()) : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), // Reduce height
          filled: true, // Enables background color
          fillColor: Colors.white, // White background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(color: borderColor, width: 0.5), // Use borderColor
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(color: borderColor, width: 0.5), // Use borderColor
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(color: borderColor, width: 0.5), // Use borderColor
          ),
          disabledBorder: OutlineInputBorder( // Add disabledBorder
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(color: borderColor, width: 0.5), // Use borderColor
          ),
        ),
        style: GoogleFonts.poppins(
          color: enabled ? ColorUtils.primarycolor() : Colors.grey, // Disabled color for text
        ),
      ),
    );
  }
}