import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../config/authconfig.dart';
import '../../config/colorcode.dart';
import 'package:http/http.dart' as http;

import '../customer/drawer/listbookin.dart';
class ChoosePlan extends StatefulWidget {
  final String vendorid;
  const ChoosePlan({super.key, required this.vendorid});

  @override
  _ChoosePlanState createState() => _ChoosePlanState();
}

class _ChoosePlanState extends State<ChoosePlan> {
  final ValueNotifier<int> _planTrigger = ValueNotifier(-1); // -1 = nothing selected
  Vendor? _vendor;
  final ValueNotifier<bool> _isYearly = ValueNotifier(false); // Tracks subscription period
  late Razorpay _razorpay;
  List<Plan> _plans = [];
  bool _isLoading = true;
  bool _hasUsedTrial = false;
  String? _vendorName; // Add this
  String? _contactNumber;
  // final int extraDays = plan.validity; // Use the instance variable from the selected plan
  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchPlans();
    _fetchVendorData();
    _fetchTrialStatus();// Fetch plans when the widget is initialized
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }
  Future<void> _fetchVendorData() async {
    try {
      final vendorId = widget.vendorid;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=$vendorId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] == 'Vendor data fetched successfully') {
          final vendorData = data['data'];
          setState(() {
            _vendorName = vendorData['vendorName'];
            _contactNumber = vendorData['contacts']?.isNotEmpty == true
                ? vendorData['contacts'][0]['mobile']
                : null;
          });
        } else {
          print("Error fetching vendor data: ${data['message']}");
        }
      } else {
        print("Error fetching vendor data: ${response.body}");
      }
    } catch (e) {
      print("Exception in fetching vendor data: $e");
    }
  }
  Future<void> _fetchTrialStatus() async {
    try {
      final vendorId = widget.vendorid; // Replace with actual ID
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/fetchtrial/$vendorId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _hasUsedTrial = data['trial'] == 'true';
      } else {
        print("Error fetching trial status: ${response.body}");
      }
    } catch (e) {
      print("Exception in fetching trial status: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }
  Future<void> _activateFreeTrial() async {
    try {
      final url = '${ApiConfig.baseUrl}vendor/freetrial/${widget.vendorid}';
      print("API URL: $url"); // Print the URL to the console for debugging

      // API Call to Add Free Trial
      final response = await http.put(Uri.parse(url));

      if (response.statusCode == 200) {
        // Success: Show SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Free trial added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500)); // optional delay for user to see the snackbar
        Navigator.pop(context); // Navigate back after success
        // Optionally: Navigate to another screen
      } else {
        // Failure: Show Error SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add free trial. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Network or other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _updateVendorSubscription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/freetrial/${widget.vendorid}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subscription': "true",
          'trial': "true",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
        // Optionally navigate back after success
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to update subscription')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _fetchPlans() async {
    try {
      final vendorId = widget.vendorid; // <-- semicolon here, not comma

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}admin/getvendorplan/$vendorId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _plans = (data['plans'] as List).map((plan) => Plan.fromJson(plan)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  void _openCheckout() async {
    print("Opening checkout...");

    // Get the selected plan
    final selectedPlanIndex = _planTrigger.value;
    print("Selected plan index: $selectedPlanIndex");

    if (selectedPlanIndex < 1 || selectedPlanIndex > _plans.length) {
      print("Invalid plan index. Aborting checkout.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a valid plan")),
      );
      return;
    }

    final plan = _plans[selectedPlanIndex - 1];
    print("Selected Plan: ${plan.planName}, Amount: ${plan.amount}, Validity: ${plan.validity}");

    // Check if amount is zero (free plan)
    if (plan.amount == "0" || int.parse(plan.amount) == 0) {
      print("Zero amount plan detected - processing directly");
      try {
        final int extraDays = int.parse(plan.validity);
        await _addExtraDaysToSubscription(widget.vendorid, extraDays);
        await _updateVendorSubscription();
        // Log the "payment" (free activation)
        await _logPaymentEvent(
            'success',
            'free_plan_activation',
            'free_order_${DateTime.now().millisecondsSinceEpoch}',
            null
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plan activated successfully!")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error activating plan: $e")),
        );
      }
      return;
    }

    final amount = int.parse(plan.amount) * 100; // Convert ₹ to paise
    print("Parsed Amount in Paise: $amount");

    try {
      // Step 1: Call backend to create Razorpay order
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': plan.amount, // Send amount in rupees
          'vendor_id': widget.vendorid,
          'plan_id': plan.id,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['order'] != null) {
          final orderId = responseData['order']['id'];
          print("Order created successfully. Order ID: $orderId");

          // Step 2: Configure Razorpay checkout options
          var options = {
            'key': RazorpayConfig.razorpayKey,
            'amount': amount, // Amount in paise
            'currency': 'INR',
            'name': 'Parkmywheels',
            'description': 'Payment for ${plan.planName}',
            'order_id': orderId, // Include the order_id from backend
            'theme': {'color': '#3BA775'},
            'prefill': {
              'contact': _contactNumber,
              'email': _vendorName,
            },
          };

          print("Options passed to Razorpay: $options");

          // Step 3: Open Razorpay checkout
          _razorpay.open(options);
          print("Razorpay checkout opened.");
        } else {
          throw Exception("Failed to create order: ${responseData['error']}");
        }
      }
      else {
        throw Exception("Failed to create order. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred while opening Razorpay: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening payment: $e")),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final planIndex = _planTrigger.value - 1;

      if (planIndex < 0 || planIndex >= _plans.length) {
        print("❌ Invalid plan index: $planIndex");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid plan selected")),
        );
        return;
      }

      final plan = _plans[planIndex];
      final String paymentId = response.paymentId ?? '';
      final String orderId = response.orderId ?? '';
      final String signature = response.signature ?? '';
      final String vendorId = widget.vendorid;
      final String planId = plan.id;
      final String amount = plan.amount.toString();

      print("📦 Preparing data to send to backend...");
      final requestBody = {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
        'vendor_id': vendorId,
        'plan_id': planId,
        'transaction_name': 'Plan Purchase',
        'payment_status': 'success',
        'amount': amount,
      };

      print("🧾 Request Body: $requestBody");

      final url = '${ApiConfig.baseUrl}vendor/sucesspay/$vendorId';
      print("🌐 Sending POST to: $url");

      final verifyResponse = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      print("📥 Response Status Code: ${verifyResponse.statusCode}");
      print("📥 Response Body: ${verifyResponse.body}");

      if (verifyResponse.statusCode == 200) {
        print("✅ Payment verification successful!");

        // Step 4: Add extra days to subscription
        final int extraDays = int.parse(plan.validity); // Convert validity to int
        await _addExtraDaysToSubscription(vendorId, extraDays);

        // Log payment event
        await _logPaymentEvent('success', paymentId, orderId, null);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment successful and subscription updated!")),
        );

        // Optional: Navigate back or to a success screen
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      } else {
        print('❌ Payment verification failed: ${verifyResponse.body}');
        await _logPaymentEvent('error', null, null, verifyResponse.body);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment verification failed")),
        );
      }
    } catch (e) {
      print('🔥 Error verifying payment: $e');
      await _logPaymentEvent('error', null, null, e.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error verifying payment: $e")),
      );
    }
  }
  Future<void> _addExtraDaysToSubscription(String vendorId, int extraDays) async {
    try {
      final url = '${ApiConfig.baseUrl}vendor/addExtraDays/$vendorId';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'extraDays': extraDays}),
      );

      if (response.statusCode == 200) {
        print("✅ Extra days added successfully!");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Extra days added to subscription!")),
        // );
      } else {
        print('❌ Failed to add extra days: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to add extra days")),
        );
      }
    } catch (e) {
      print('🔥 Error adding extra days: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding extra days: $e")),
      );
    }
  }
  void _handlePaymentError(PaymentFailureResponse response) async {
    print("Payment Error Code: ${response.code}");
    print("Payment Error Message: ${response.message}");

    // Log error to the API
    await _logPaymentEvent('error', null, null, response.message);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Failed please try again..")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) async {
    // Log external wallet usage to the API
    await _logPaymentEvent('external_wallet', null, null, response.walletName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet: ${response.walletName}")),
    );
  }
  Future<void> _logPaymentEvent(String status, String? paymentId, String? orderId, String? message) async {
    if (_planTrigger.value <= 0 || _planTrigger.value - 1 >= _plans.length) {
      print("⚠️ Invalid plan index while logging payment. Skipping logging.");
      return;
    }

    final selectedPlan = _plans[_planTrigger.value - 1];

    final logUrl = '${ApiConfig.baseUrl}vendor/log/${widget.vendorid}';

    await http.post(
      Uri.parse(logUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'payment_id': paymentId ?? '',
        'order_id': orderId ?? '',
        'vendor_id': widget.vendorid,
        'plan_id': selectedPlan.id,
        'transaction_name': 'Plan Purchase',
        'payment_status': status,
        'amount': selectedPlan.amount.toString(),
        'message': message ?? '', // Add this if your backend expects error logs
      }),
    );
  }


  @override
  Widget build(BuildContext context) {
    return  _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      body: SafeArea(
        child: Stack(
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
                      "Choose Plan",
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
                            "Switch between monthly and yearly plans.    ",
                            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          // Plan Options with cards
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // if (!_hasUsedTrial)
                                  // GestureDetector(
                                  //   onTap: () => _planTrigger.value = 0,
                                  //   child: PlanCard(
                                  //     notifierValue: _planTrigger,
                                  //     selectedIndex: 0,
                                  //     header: "30 Days Free Trial",
                                  //     subHeader: "Days left: 30",
                                  //     isYearly: false,
                                  //     monthlyPrice: "0",
                                  //     yearlyPrice: "0",
                                  //     imageUrl: null, // No image for free trial
                                  //   ),
                                  // ),
                                const SizedBox(width: 10),
                                ..._plans.asMap().entries.map((entry) {
                                  int index = entry.key + 1;
                                  Plan plan = entry.value;
                                  return GestureDetector(
                                    onTap: () {
                                      if (index >= 0 && index <= _plans.length) {
                                        _planTrigger.value = index;
                                      }
                                    },
                                    child: PlanCard(
                                      notifierValue: _planTrigger,
                                      selectedIndex: index,
                                      header: plan.planName,
                                      subHeader: "Validity: ${plan.validity} days",
                                      isYearly: false,
                                      monthlyPrice: plan.amount,
                                      yearlyPrice: "0",
                                      // imageUrl: plan.image, // Pass the plan's image URL
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          ValueListenableBuilder<int>(
                            valueListenable: _planTrigger,
                            builder: (context, selectedPlan, _) {
                              // Safeguard: Ensure selectedPlan is within valid range
                              if (selectedPlan < 0 || selectedPlan >= _plans.length + 1) {
                                return const SizedBox.shrink(); // Return an empty widget if invalid
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Features:",
                                    style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  if (selectedPlan == 0) ...const [
                                    FeatureItem(icon: Icons.check, text: "Unlimited bookings"),
                                    FeatureItem(icon: Icons.check, text: "24/7 customer support"),
                                    FeatureItem(icon: Icons.check, text: "Access to premium spots"),
                                  ] else if (_plans.isNotEmpty && selectedPlan - 1 < _plans.length) ...[
                                    ..._plans[selectedPlan - 1].features.map(
                                          (feature) => FeatureItem(icon: Icons.check, text: feature),
                                    )
                                  ] else ...const [
                                    FeatureItem(icon: Icons.close, text: "No features available"),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          ValueListenableBuilder<int>(
                            valueListenable: _planTrigger,
                            builder: (context, selectedPlan, _) {
                              // If no plan selected, don't show any button
                              if (selectedPlan == -1) return const SizedBox.shrink();

                              return Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: selectedPlan == 0
                                      ? _activateFreeTrial
                                      : () => _openCheckout(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    selectedPlan == 0 ? "Proceed" : "Pay Now",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),


                          const SizedBox(height: 40),

                          // Features Section


                          // Payment Button

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
      ),);
  }
}


class PlanCard extends StatelessWidget {
  final ValueNotifier<int> notifierValue;
  final int selectedIndex;
  final String header;
  final String subHeader;
  final bool isYearly;
  final String monthlyPrice;
  final String yearlyPrice;
  final String? imageUrl; // Optional image URL from the Plan model

  const PlanCard({
    required this.notifierValue,
    required this.selectedIndex,
    required this.header,
    required this.subHeader,
    required this.isYearly,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.imageUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 600 ? screenWidth * 0.4 : 180.0; // Responsive width

    return ValueListenableBuilder<int>(
      valueListenable: notifierValue,
      builder: (context, value, _) {
        final bool isSelected = value == selectedIndex;

        return GestureDetector(
          onTap: () => notifierValue.value = selectedIndex,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: cardWidth,
            constraints: const BoxConstraints(
              minHeight: 200,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                colors: [
                  ColorUtils.primarycolor(),
                  ColorUtils.secondarycolor(),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: isSelected
                  ? null
                  : Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isSelected ? 0.2 : 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Plan Image or Icon
                  // ClipRRect(
                  //   borderRadius: BorderRadius.circular(8),
                  //   child: imageUrl != null && imageUrl!.isNotEmpty
                  //       ? Image.network(
                  //     imageUrl!,
                  //     height: 60,
                  //     width: 60,
                  //     fit: BoxFit.cover,
                  //     errorBuilder: (context, error, stackTrace) => Icon(
                  //       Icons.local_offer,
                  //       size: 60,
                  //       color: isSelected
                  //           ? Colors.white
                  //           : ColorUtils.primarycolor(),
                  //     ),
                  //   )
                  //       : Icon(
                  //     Icons.local_offer,
                  //     size: 60,
                  //     color: isSelected
                  //         ? Colors.white
                  //         : ColorUtils.primarycolor(),
                  //   ),
                  // ),
                  const SizedBox(height: 12),
                  // Plan Name
                  Text(
                    header,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 8),
                  // Plan Subheader (e.g., Validity)
                  Text(
                    subHeader,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 12),
                  // Plan Price
                  Text(
                    "₹${isYearly ? yearlyPrice : monthlyPrice}",
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : ColorUtils.primarycolor(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Selected Indicator
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
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
class Plan {
  final String id;
  final String planName;
  final String validity;
  final String amount;
  final List<String> features;
  final String image;

  Plan({
    required this.id,
    required this.planName,
    required this.validity,
    required this.amount,
    required this.features,
    required this.image,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['_id'],
      planName: json['planName'],
      validity: json['validity'],
      amount: json['amount'],
      features: List<String>.from(json['features']),
      image: json['image'],
    );
  }
}