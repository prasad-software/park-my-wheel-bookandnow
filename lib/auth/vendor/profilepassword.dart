import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/vendorprofile.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'dart:convert';

class profilepassword extends StatefulWidget {
  final String vendorid;
  final VoidCallback? onEditSuccess; // <-- Add this

  const profilepassword({super.key, required this.vendorid,  this.onEditSuccess,});

  @override
  _profilepasswordState createState() => _profilepasswordState();
}

class _profilepasswordState extends State<profilepassword> {
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
            builder: (context) => vendorProfilePage(vendorid: widget.vendorid),
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

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Function to handle vendor login API call

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Profile Password',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
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
      ),);
  }
}