import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/config/authconfig.dart';

import 'package:mywheels/config/colorcode.dart';
import 'package:pinput/pinput.dart';
import 'dart:convert';

class ForgotForm extends StatefulWidget {
  const ForgotForm({super.key});

  @override
  _ForgotFormState createState() => _ForgotFormState();
}

class _ForgotFormState extends State<ForgotForm> {
  final TextEditingController _amobileNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool isOtpSent = false;
  int timerSeconds = 10;
  Timer? _timer;

  // Start OTP timer
  void startOtpTimer() {
    setState(() {
      timerSeconds = 10;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timerSeconds > 0) {
          timerSeconds--;
        } else {
          timer.cancel();
          isOtpSent = false; // Reset to allow resend
        }
      });
    });
  }

  // Call the API to send OTP
  Future<void> sendOtp(String mobileNumber) async {
    final url = Uri.parse('${ApiConfig.baseUrl}forgotpassword');
    try {
      print("Sending OTP to: $mobileNumber");
      final response = await http.post(
        url,
        body: json.encode({'contactNo': mobileNumber}),
        headers: {'Content-Type': 'application/json'},
      );
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          isOtpSent = true;
        });
        startOtpTimer();
        print("enter this otp: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.body),
            duration: const Duration(seconds: 30), // Display SnackBar for 30 seconds
          ),
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP. Please try again.')),
        );
      }
    } catch (error) {
      print("Error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  // Call the API to verify OTP
  Future<void> verifyOtp(String mobileNumber, String otp) async {
    final url = Uri.parse('${ApiConfig.baseUrl}verify-otp');
    try {
      print("Verifying OTP for: $mobileNumber with OTP: $otp");
      final response = await http.post(
        url,
        body: json.encode({'contactNo': mobileNumber, 'otp': otp}),
        headers: {'Content-Type': 'application/json'},
      );
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        // Display success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Verified successfully.')),
        );

        // Navigate to the Reset Password screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(mobileNumber: mobileNumber),
          ),
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Please try again.')),
        );
      }
    } catch (error) {
      print("Error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amobileNumberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text('Forgot Password',   style: GoogleFonts.poppins(color: Colors.black), // Set text color to white
    ),
    iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
          child: Column(
            children: [
              // const SizedBox(height: 50.0),
              Padding(
                padding: const EdgeInsets.only(left: 25.0,right: 25.0,top: 0),
                child: SizedBox(
                  height: 80,

                  child: Image.asset("assets/login.png"),
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(height:40 ,
                      child: TextFormField(
                        controller: _amobileNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          fillColor: Colors.white,
                          filled: true,
                          prefixIcon: const Icon(Icons.phone),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(     topLeft: Radius.circular(5),
                              bottomLeft: Radius.circular(5),),
                            borderSide: BorderSide(color: Colors.grey,), // Enabled border color
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            borderSide: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                          hintText: "Enter Mobile Number",
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          counterText: "",

                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isOtpSent && timerSeconds > 0
                        ? null
                        : () {
                      if (_amobileNumberController.text.length == 10) {
                        sendOtp(_amobileNumberController.text); // Send OTP
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a 10-digit mobile number.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: ColorUtils.primarycolor(),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                    child: Text(
                      isOtpSent
                          ? (timerSeconds > 0 ? 'Wait ${timerSeconds}s' : 'Resend OTP')
                          : 'Send OTP',  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              Pinput(
                controller: _otpController,
                length: 5,
                keyboardType: TextInputType.number,
                mainAxisAlignment: MainAxisAlignment.center,
                defaultPinTheme: PinTheme(
                  width: 50,
                  height: 50,
                  textStyle: const TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorUtils.primarycolor()),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 50,
                  height: 50,
                  textStyle: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColorUtils.primarycolor(), width: 2),
                  ),
                ),
                onCompleted: (otp) {
                  // Call verify OTP function when OTP is entered completely
                  verifyOtp(_amobileNumberController.text, otp);
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: () {
                    if (_otpController.text.length == 5) {
                      verifyOtp(_amobileNumberController.text, _otpController.text); // Verify OTP
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a 6-digit OTP.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text('Verify OTP',  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),),
                ),
              ),
              const SizedBox(height: 10),

            ],
          ),
        ),
      ),
      ),    );
  }
}



class ResetPasswordPage extends StatefulWidget {
  final String mobileNumber;

  const ResetPasswordPage({super.key, required this.mobileNumber});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> changePassword() async {
    if (_passwordController.text == _confirmPasswordController.text) {
      final url = Uri.parse('${ApiConfig.baseUrl}change-password');
      final body = json.encode({
        'contactNo': widget.mobileNumber,
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
      });

      try {
        final response = await http.post(
          url,
          body: body,
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully!')),
          );
          // Navigate to login or another screen if needed
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const splashlogin()), // Replace LoginScreen with your actual login page widget
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to change password. Please try again.')),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        title: const Text("Reset Password",style: TextStyle(color: Colors.black),),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 25.0,right: 25.0,top: 0),
                child: SizedBox(
                  height: 80,

                  child: Image.asset("assets/login.png"),
                ),
              ),
const SizedBox(height: 40,),
              CustomTextField(
                inputFormatter: const [],
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                keyboard: TextInputType.text,
                obscure: !_isPasswordVisible,
                textInputAction: TextInputAction.next,
                label: 'Password',
                hint: 'Please enter New Password',
                suffix: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                onSubmitted: (value) {
                  FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                },
              ),
              const SizedBox(height: 15),
              CustomTextField(
                inputFormatter: const [],
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                keyboard: TextInputType.text,
                obscure: !_isConfirmPasswordVisible,
                textInputAction: TextInputAction.done,
                label: 'Confirm Password',
                hint: 'Please enter Confirm Password',
                suffix: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Change Password', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}
