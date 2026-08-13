import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../config/authconfig.dart';
import '../../model/user.dart';

class MySpacePlan extends StatefulWidget {
  final String vendorid;
  final String userid;
  const MySpacePlan({super.key, required this.vendorid, required this.userid});

  @override
  _ViewPlanState createState() => _ViewPlanState();
}

class _ViewPlanState extends State<MySpacePlan> {
  final ValueNotifier<int> _planTrigger = ValueNotifier(0);
  String daysLeft = "days left...";

  @override
  void initState() {
    super.initState();
    fetchSubscriptionLeft();
  }

  Future<void> fetchSubscriptionLeft() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetchsubscriptionleft/${widget.vendorid}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final subLeft = data['subscriptionleft'];
          daysLeft = (subLeft == 0 || subLeft == "0") ? "Ended" : "$subLeft days left";
        });
      } else {
        setState(() {
          daysLeft = "Error fetching data";
        });
      }
    } catch (e) {
      setState(() {
        daysLeft = "Connection error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background Design with Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ColorUtils.primarycolor(), ColorUtils.secondarycolor()],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Main Content
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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

                // Content Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Container(
                      width: double.infinity,
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
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Upgrade your plan to get more bookings.",
                                style: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 20),

                              // Current Plan Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: ColorUtils.primarycolor(),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "Your Current Plan",
                                      style: GoogleFonts.lato(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      daysLeft,
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Upgrade your plan",
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Features Section
                              Text(
                                "Features:",
                                style: GoogleFonts.lato(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              const SizedBox(height: 15),
                              const FeatureItem(icon: Icons.check, text: "Unlimited bookings"),
                              const FeatureItem(icon: Icons.check, text: "24/7 customer support"),
                              const FeatureItem(icon: Icons.check, text: "Access to premium spots"),
                              const SizedBox(height: 30),

                              // Upgrade Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => spaceplan(vendorid: widget.vendorid,userid:widget.userid),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    "Upgrade Now",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class spaceplan extends StatefulWidget {
  final String vendorid;
  final String userid;
  const spaceplan({super.key, required this.vendorid, required this.userid});

  @override
  _ChoosePlanState createState() => _ChoosePlanState();
}

class _ChoosePlanState extends State<spaceplan> {
  final ValueNotifier<int> _planTrigger = ValueNotifier(-1);
  final ValueNotifier<bool> _isYearly = ValueNotifier(false);

  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();


  late Razorpay _razorpay;
  User? _user;
  List<Plan> _plans = [];
  bool _isLoading = true;
  bool _hasUsedTrial = false;
  final bool _hasError = false;
  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchPlans();

    _fetchUserData();
  }
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userid}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);

            _mobileNumberController.text = _user?.mobileNumber ?? '';
            _emailController.text = _user?.email ?? '';

          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
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
        Uri.parse('${ApiConfig.baseUrl}admin/getuserplan/$vendorId'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pack added to subscription!")),
        );
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

    // Proceed with normal payment flow for non-zero amounts
    final amount = int.parse(plan.amount) * 100; // Convert ₹ to paise
    print("Parsed Amount in Paise: $amount");

    try {
      // Rest of your existing payment flow...
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': plan.amount,
          'vendor_id': widget.vendorid,
          'plan_id': plan.id,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['order'] != null) {
          final orderId = responseData['order']['id'];
          print("Order created successfully. Order ID: $orderId");

          var options = {
            'key': RazorpayConfig.razorpayKey,
            'amount': amount,
            'currency': 'INR',
            'name': 'Parkmywheels',
            'description': 'Payment for ${plan.planName}',
            'order_id': orderId,
            'theme': {'color': '#3BA775'},
            'prefill': {
              'contact': _user?.mobileNumber ?? '',
              'email': _user?.email ?? '',
            },
          };

          print("Options passed to Razorpay: $options");
          _razorpay.open(options);
          print("Razorpay checkout opened.");
        } else {
          throw Exception("Failed to create order: ${responseData['error']}");
        }
      } else {
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
  Future<void> _activateFreeTrial() async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/freetrial/${widget.vendorid}'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free trial activated successfully!')),
        );
        await Future.delayed(const Duration(milliseconds: 500)); // optional delay for user to see the snackbar
        Navigator.pop(context); // Navigate back after success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to activate free trial.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif()
        : Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ColorUtils.primarycolor(), ColorUtils.secondarycolor()],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Main Content
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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

                // Plans Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Container(
                      width: double.infinity,
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
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(
                              "Switch between monthly and yearly plans.",
                              style: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),

                            // Plan Cards
                            SizedBox(
                              height: 200,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [


                                  ..._plans.map((plan) {
                                    final index = _plans.indexOf(plan) + 1;
                                    return PlanCard(
                                      notifierValue: _planTrigger,
                                      selectedIndex: index,
                                      header: plan.planName,
                                      subHeader: "Validity: ${plan.validity} days",
                                      monthlyPrice: (int.parse(plan.amount)).toString(),
                                      yearlyPrice: "0",
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Features
                            ValueListenableBuilder<int>(
                              valueListenable: _planTrigger,
                              builder: (context, selectedPlan, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Features:",
                                      style: GoogleFonts.lato(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    if (selectedPlan == 0) ...const [
                                      FeatureItem(icon: Icons.check, text: "Unlimited bookings"),
                                      FeatureItem(icon: Icons.check, text: "24/7 customer support"),
                                      FeatureItem(icon: Icons.check, text: "Access to premium spots"),
                                    ] else if (selectedPlan > 0 && _plans.isNotEmpty) ...[
                                      ..._plans[selectedPlan - 1].features.map(
                                            (feature) => FeatureItem(icon: Icons.check, text: feature),
                                      )
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 30),

                            // Payment Button
                            ValueListenableBuilder<int>(
                              valueListenable: _planTrigger,
                              builder: (context, selectedPlan, _) {
                                if (selectedPlan == -1) return const SizedBox();

                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: selectedPlan == 0
                                        ? _activateFreeTrial
                                        : _openCheckout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ColorUtils.primarycolor(),
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      selectedPlan == 0 ? "Proceed" : "Pay Now",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
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
                ),],
            ),
          ],
        ),
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
        final isSelected = value == selectedIndex;
        return GestureDetector(
          onTap: () => notifierValue.value = selectedIndex,
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? ColorUtils.primarycolor() : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  header,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 8),
                Text(
                  subHeader,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 8),
                Text(
                  "₹$monthlyPrice",
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : ColorUtils.primarycolor(),
                  ),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: ColorUtils.primarycolor(), size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
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
  final String role;

  Plan({
    required this.id,
    required this.planName,
    required this.validity,
    required this.amount,
    required this.features,
    required this.image,
    required this.role,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['_id'],
      planName: json['planName'],
      validity: json['validity'],
      amount: json['amount'],
      features: List<String>.from(json['features']),
      image: json['image'],
      role: json['role'],
    );
  }
}