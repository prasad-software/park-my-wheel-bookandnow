import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'package:mywheels/auth/vendor/vendorsubscriptionapply.dart';
import 'package:mywheels/config/colorcode.dart';

import '../../../config/authconfig.dart';
class viewplan extends StatefulWidget {
  final String vendorid;
  const viewplan({super.key, required this.vendorid});

  @override
  _viewplanState createState() => _viewplanState();
}

class _viewplanState extends State<viewplan> {
  final ValueNotifier<int> _planTrigger = ValueNotifier(0); // Tracks selected plan
  String daysLeft = "days left...";
  @override
  void initState() {
    super.initState();
    fetchSubscriptionLeft(); // Fetch subscription days left when the widget is initialized
  }

  Future<void> fetchSubscriptionLeft() async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchsubscriptionleft/${widget.vendorid}')
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final subLeft = data['subscriptionleft'];

      setState(() {
        daysLeft = (subLeft == 0 || subLeft == "0") ? "Ended" : "$subLeft days left";
      });
    } else {
      setState(() {
        daysLeft = "Error fetching data";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Design with Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ColorUtils.primarycolor(), ColorUtils.secondarycolor()],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      "Current Plan",
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toggle for Monthly/Yearly
                          Text(
                            "upgrade your plan to get more bookings.",
                            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),

                          // Plan Options with cards
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 450, // Dynamically adjust width
                           // Change height based on selection
                            decoration: BoxDecoration(
                              color:  ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Current Plan Header
                                  Container(
                                    child: Text(
                                      "Your Current Plan",
                                      style: GoogleFonts.lato(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color:  Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Days Left Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        child: Text(
                                          daysLeft, // Replace with dynamic data if needed
                                          style: GoogleFonts.lato(
                                            fontSize: 16,
                                            color:   Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10), // Space between texts

                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // Monthly Price
                                  Container(
                                    child: Text(
                                      "Upgrade your plan", // Replace with dynamic data if needed
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        color: Colors.white ,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const SizedBox(height: 40),

                          // Features Section
                          Text(
                            "Features:",
                            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const FeatureItem(icon: Icons.check, text: "Unlimited bookings"),
                          const FeatureItem(icon: Icons.check, text: "24/7 customer support"),
                          const FeatureItem(icon: Icons.check, text: "Access to premium spots"),
                          const SizedBox(height: 10),

                          // Payment Button
                          ValueListenableBuilder<int>(
                            valueListenable: _planTrigger,
                            builder: (context, selectedPlan, _) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => ChoosePlan(vendorid: widget.vendorid,)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 5,
                                    shadowColor: Colors.black.withOpacity(0.2),
                                  ),
                                  child:  Text(
                                    "Upgrade Now",
                                    style:   GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  final ValueNotifier<int> notifierValue;
  final int selectedIndex;
  final String header;
  final String subHeader;

  final String monthlyPrice;
  final String yearlyPrice;

  const PlanCard({
    required this.notifierValue,
    required this.selectedIndex,
    required this.header,
    required this.subHeader,
    required this.monthlyPrice,
    required this.yearlyPrice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifierValue,
      builder: (context, value, _) {
        final bool isSelected = value == selectedIndex;

        return GestureDetector(
          onTap: () => notifierValue.value = selectedIndex,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double maxWidth = constraints.maxWidth;

              return Container(
                padding: const EdgeInsets.all(5), // Space for outermost border
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(5), // Ensure smooth corners
                  color: Colors.white, // Outermost layer (white)
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(1), // Space for second border
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(5), // Secondary border
                    color: ColorUtils.primarycolor(), // Second layer (primary color)
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3), // Space for inner border
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(5), // Inner border radius
                      color: Colors.white, // Inner layer (white background)
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: maxWidth * 0.9, // Dynamically adjust width
                      height: 100,
                      decoration: BoxDecoration(
                        color: isSelected ? ColorUtils.primarycolor() : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              header,
                              style: GoogleFonts.lato(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subHeader,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.recursive(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              monthlyPrice,
                              style: GoogleFonts.recursive(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeatureItem({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ColorUtils.primarycolor(), size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
