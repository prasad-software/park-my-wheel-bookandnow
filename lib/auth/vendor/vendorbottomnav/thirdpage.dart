import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/auth/vendor/bookings.dart';

import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdbottom.dart';

import 'package:mywheels/auth/vendor/vendordash.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import '../menusscreen.dart';


class Third extends StatefulWidget {
  final String vendorid;
  // final int initialTabIndex;
  const Third({super.key,
    required this.vendorid,
    // this.initialTabIndex = 0
    // required this.userName
  });

  @override
  State<Third> createState() => _ThirdState();
}


  class _ThirdState extends State<Third>with TickerProviderStateMixin {
    // late TabController _chargesController; // Remove the nullable type
    TabController? _chargesController;
  final bool _isSlotListingExpanded = false;
  late final TabController _controller = TabController(length: 3, vsync: this);

  int _selecteddIndex = 3;//botom nav
  int selectedTabIndex = 0;
  int selecedIndex = 0;

  // Vendor? _vendor;
  final bool _isEditing = false;
  bool _isLoading = false;


  File? _selectedImage;

  late List<Widget> _pagess;

    final TextEditingController _passwordController = TextEditingController();
    final FocusNode _passwordFocusNode = FocusNode();
    // bool _isLoading = false;
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
        const String apiUrl = '${ApiConfig.baseUrl}vendor/profilepass';
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
          // Use Navigator.push instead of pushReplacement to allow back navigation
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
                child: manageparkingarea(vendorid: widget.vendorid),
              ),
            ),
          );
        } else {
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




  // late List<Widget> _pagess;
  String? _menuImageUrl;

  void _navigateToPage(int index) {
    setState(() {
      _selecteddIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pagess[index]),
    );
  }



    @override
    void initState() {
      super.initState();

      selectedTabIndex = 0;
      selecedIndex = 0;
      _pagess = [
        vendordashScreen(vendorid: widget.vendorid),
        Bookings(vendorid: widget.vendorid),
        qrcodeallowpark(vendorid: widget.vendorid),
        Third(vendorid: widget.vendorid),
        menu(vendorid: widget.vendorid),
      ];



      _controller.addListener(() {
        setState(() {
          selectedTabIndex = _controller.index;
        });

      });

      selecedIndex = 0;
    }
    @override
    void dispose() {
      _controller.dispose();
      _chargesController?.dispose(); // No need for null check since it's not nullable
      super.dispose();
    }
    @override
  Widget build(BuildContext context) {

    return Scaffold(backgroundColor: ColorUtils.secondarycolor(),
      appBar: AppBar(automaticallyImplyLeading: false,
        title:  Text("Manage Parking Area", style:   GoogleFonts.poppins(color: Colors.black,
          fontSize: 18
        ),

        ),

        backgroundColor: ColorUtils.secondarycolor(),

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





  void _onTabChange(int index) {
    _navigateToPage(index);
  }



}

