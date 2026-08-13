import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';

const SizedBox verticalMargin16 = SizedBox(height: 16);
const SizedBox verticalMargin8 = SizedBox(height: 8);

class AppImages {
  static const String logo = 'assets/logo.png'; // Example path
}

class VendorAbout extends StatefulWidget {
  const VendorAbout({super.key});

  @override
  State<VendorAbout> createState() => _VendorAboutState();
}

class _VendorAboutState extends State<VendorAbout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.secondarycolor(),
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        leadingWidth: 40,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          "About Us",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              children: [
          
          
                Card(color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  shadowColor: Colors.grey.shade200,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 80,
          
                          child: Image.asset("assets/login.png"),
                        ),
                        // SizedBox(height: 40,),
          
                        verticalMargin16,
                        Text(
                          " Park My Wheels helps you manage your parking spots, monitor bookings, and keep track of your parking area status. Whether you're managing a single parking spot or multiple locations, our platform provides you with all the tools you need for smooth operations.",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                        verticalMargin16,
                        Align(
                          alignment: Alignment.center,
                          child: Image.asset(AppImages.logo, height: 80, width: 80),
                        ),
                        verticalMargin16,
                        Text(
                          'Why Become a Park My Wheels Vendor?',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        verticalMargin8,
                        Text(
                          "By partnering with Park My Wheels, you can access a larger customer base, increase your revenue, and streamline your parking management process. Our app allows you to manage parking availability, set rates, and receive instant bookings directly through your phone. Join our network of trusted vendors and help make parking more accessible to everyone!",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract class AppStrings {
  AppStrings._();

  static const String appName = 'Park My Wheels';
}
