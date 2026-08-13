import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/config/authconfig.dart';

import 'package:mywheels/config/colorcode.dart'; // Ensure this points to your ColorUtils
import 'package:http/http.dart' as http;
class CustomerRegister extends StatefulWidget {
  const CustomerRegister({super.key});

  @override
  _CustomerRegisterState createState() => _CustomerRegisterState();
}

class _CustomerRegisterState extends State<CustomerRegister> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _mobileNumberFocusNode = FocusNode();
  bool _isLoading = false; // Loading state
  bool _isPasswordVisible = false;
  Future<void> _registerUser() async {
    print("Register button clicked");

    // Check for empty fields
    if (_nameController.text.isEmpty) {
      print("Name is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Name')),
      );
      return;
    }

    if (_mobileNumberController.text.isEmpty) {
      print("Mobile Number is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Mobile Number')),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      print("Password is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Password')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // Show loading animation
    });

    try {
      print("Making API call to register user...");

      // Print request data
      print("Request Body: ${jsonEncode(<String, String>{
        'userName': _nameController.text,
        'userMobile': _mobileNumberController.text,
        'userEmail': _emailController.text,
        'userPassword': _passwordController.text,
      })}");

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}signup'),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'userName': _nameController.text,
          'userMobile': _mobileNumberController.text,
          'userEmail': _emailController.text,
          'userPassword': _passwordController.text,
        }),
      );

      print("Response received with status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print("Registration Successful: ${responseData['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        Navigator.pop(context);
      } else {
        final responseData = json.decode(response.body);
        print("Registration Failed: ${responseData['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
      }
    } catch (e) {
      print("Error occurred during registration: $e");
    } finally {
      setState(() {
        _isLoading = false; // Hide loading animation
      });
      print("API call completed");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text(
          'New Registration',
          style: GoogleFonts.poppins(color: Colors.black), // Set text color to white
        ),
        iconTheme: const IconThemeData(color: Colors.black), // Set icon color to white
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0,right: 16.0),
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 25.0,right: 25.0,top: 0),
                child: SizedBox(
                  height: 60,

                  child: Image.asset("assets/login.png"),
                ),
              ),
              const SizedBox(height: 16.0),

              // Name Field
              CustomTextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                keyboard: TextInputType.text,
                obscure: false,
                textInputAction: TextInputAction.next,
                inputFormatter: const [],
                label: 'Name',
                hint: 'Please enter your Name',
                onSubmitted: (value) {
                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                },
              ),

              const SizedBox(height: 16.0),

              // Email Field
              CustomTextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboard: TextInputType.emailAddress,
                obscure: false,
                textInputAction: TextInputAction.next,
                inputFormatter: const [],
                label: 'Email',
                hint: 'Please enter your Email',
                onSubmitted: (value) {
                  FocusScope.of(context).requestFocus(_mobileNumberFocusNode);
                },
              ),
              const SizedBox(height: 16.0),

              // Mobile Number Field
              CustomTextField(
                controller: _mobileNumberController,
                focusNode: _mobileNumberFocusNode,
                keyboard: TextInputType.phone,
                obscure: false,
                textInputAction: TextInputAction.done,
                inputFormatter: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                label: 'Mobile Number',
                hint: 'Please enter your 10-digit number',
                onSubmitted: (value) {
                  // Handle submission logic if needed
                  FocusScope.of(context).unfocus(); // Dismiss the keyboard
                },
              ),
              const SizedBox(height: 16.0),


              // Password Field
          CustomTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            keyboard: TextInputType.text,
            obscure: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            inputFormatter: const [],
            suffix: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            label: 'Password',
            hint: 'Please enter your Password',

                onSubmitted: (value) {
                  FocusScope.of(context).requestFocus(_emailFocusNode);
                },
              ),
              const SizedBox(height: 16.0),
              // Signup Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 35,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser ,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primarycolor(),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Adjust padding to reduce height
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 10,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min, // Use min size to avoid extra space
                        children: [
                          const Icon(Icons.person_add,color: Colors.white, size: 18), // Icon for signup
                          const SizedBox(width: 8), // Space between icon and text
                         Text(
                            'Signup',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person, // You can change this icon
                        size: 18, // Adjust the size as needed
                        color: Colors.black,
                      ),
                      const SizedBox(width: 0),
                      Text(
                        ' Already have an Account? Login here',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ColorUtils.primarycolor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
      ),  );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _mobileNumberController.dispose();

    _nameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailFocusNode.dispose();
    _mobileNumberFocusNode.dispose();

    super.dispose();
  }
}
