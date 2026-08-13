import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const SizedBox verticalMargin16 = SizedBox(height: 16);
const SizedBox verticalMargin8 = SizedBox(height: 8);

class AppImages {
  static const String logo = 'assets/logo.png'; // Example path
}

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});



  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        // backgroundColor: ColorUtils.primarycolor(),
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'About Us',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18, // Adjust size as needed
            // fontWeight: FontWeight.w600, // Adjust weight if needed
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10,left: 10,right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 80,

                child: Image.asset("assets/login.png"),
              ),
              // SizedBox(height: 10,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        AppStrings.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(fontSize: 20),
                      ),
                    ),
                    verticalMargin16,
                    Text(
                      "Park My Wheels is a convenient parking solution designed to make parking easier for everyone. We aim to provide you with a hassle-free parking experience by offering various parking options across the city. Whether you need short-term or long-term parking, our app helps you find the best spots available near you.",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    verticalMargin16,
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(AppImages.logo, height: 100, width: 100),
                    ),
                    verticalMargin16,
                    Text(
                      'Why Choose Park My Wheels?',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    verticalMargin8,
                    Text(
                      "Our app offers a user-friendly interface to easily find parking spaces, book in advance, and manage your parking history. We prioritize your safety and convenience, ensuring that your vehicle is secure while you go about your day. Experience the future of parking with Park My Wheels!",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    verticalMargin16,
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      ),  );
  }
}

abstract class AppStrings {
  AppStrings._();

  static const String appName = 'Park My Wheels';
}
