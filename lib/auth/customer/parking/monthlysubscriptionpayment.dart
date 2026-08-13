import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/dummypages/usersubcription.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/model/user.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http; // Add this for API calls

class monthlysub extends StatefulWidget {
  final String userId;
  final String place;
  final String vehicleNumber;
  final String vendorName;
  final String time;
  final String vendorId;
  final String bookingDate;
  final String parkingDate;
  final String carType;
  final String personName;
  final String mobileNumber;
  final String sts;
  final String amount;
  final String hour;
  final String subscriptionType;
  final String status;
  final String vehicleType;
  final String parkingTime;
  final String bookingTime;
  final String cancelledStatus;
  final String bookType;
  final String totalamount;
  final String gstPercentage; // New parameter
  final String handlingFee; // New parameter
  final String totalAmountWithTaxes;
  final String subsctiptionenddate; // New parameter
  const monthlysub({
    super.key,
    required this.userId,
    required this.totalamount,
    required this.place,
    required this.vehicleNumber,
    required this.vendorName,
    required this.time,
    required this.vendorId,
    required this.bookingDate,
    required this.parkingDate,
    required this.carType,
    required this.personName,
    required this.mobileNumber,
    required this.sts,
    required this.amount,
    required this.hour,
    required this.subscriptionType,
    required this.status,
    required this.vehicleType,
    required this.parkingTime,
    required this.bookingTime,
    required this.cancelledStatus,
    required this.bookType, required this.gstPercentage, required this.handlingFee, required this.totalAmountWithTaxes,
    required this.subsctiptionenddate, // Initialize parameter
  });

  @override
  State<StatefulWidget> createState() => _monthlysubState();
}

class _monthlysubState extends State<monthlysub> {
  Razorpay? _razorpay;
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccessResponse);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentErrorResponse);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);
    bool isLoading = false;
    // Automatically create order and open Razorpay on page load
    Future.delayed(const Duration(milliseconds: 500), () {
      createOrderAndOpenCheckout();
    });
  }
  User? _user;
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 0)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            _nameController.text = _user?.username ?? '';
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
        _isLoading = false; // Stop loading
      });
    }
  }
  Future<void> createOrderAndOpenCheckout() async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/create-order');

    try {
      final amount = double.parse(widget.totalamount); // e.g., ₹1012.44
      final roundedAmount = amount.ceilToDouble(); // Round up to ₹1013.00
      final adjustmentAmount = roundedAmount - amount; // e.g., ₹1013.00 - ₹1012.44 = ₹0.56
      final amountInPaise = (roundedAmount * 100).toInt(); // 101300 paise
      print('🔍 Original Amount (INR): $amount');
      print('🔍 Adjustment Amount (INR): $adjustmentAmount');
      print('🔍 Rounded Amount (INR): $roundedAmount');
      print('🔍 Sending Amount to Backend (Paise): $amountInPaise');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': (amountInPaise / 100).toStringAsFixed(2),
          'vendor_id': widget.userId,
          'plan_id':  'default_plan', // Replace with actual plan ID
          'user_id': widget.userId,
          'transaction_name': 'UserBooking',
        }),
      );

      print('📥 Create Order Response Status: ${response.statusCode}');
      print('📥 Create Order Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          openCheckout(responseData['order']['id']);
        } else {
          Fluttertoast.showToast(msg: "Failed to create order: ${responseData['error']}");
        }
      } else {
        Fluttertoast.showToast(msg: "Failed to create order: ${response.body}");
      }
    } catch (e) {
      print('🚨 Error creating order: ${e.toString()}');
      Fluttertoast.showToast(msg: "Error creating order: ${e.toString()}");
    }
  }

  void openCheckout(String orderId) async {
    try {
      print('🔍 Total Amount (Raw): ${widget.totalamount}');
      final amount = double.parse(widget.totalamount); // e.g., ₹1012.44
      final roundedAmount = amount.ceilToDouble(); // Round up to ₹1013.00
      final adjustmentAmount = roundedAmount - amount; // e.g., ₹0.56
      final amountInPaise = (roundedAmount * 100).toInt(); // 101300 paise
      print('🔍 Adjustment Amount: $adjustmentAmount');
      print('🔍 Rounded Amount: $roundedAmount');
      print('🔍 Amount in Paise: $amountInPaise');
      var options = {

        'key': RazorpayConfig.razorpayKey,
        'order_id': orderId, // Use the order ID from the backend
        'amount': amountInPaise, // Convert to paise
        'name': 'ParkmyWheels',
        'description': 'Vehicle Parking Payment',
        'prefill': {
          'contact': _mobileNumberController.text,
          'email': _emailController.text, // Add email from controller
          'name': _nameController.text,  // Add name from controller
        },
        'theme': {
          'color': '#3BA775',
        },
      };
      _razorpay!.open(options);
    } catch (e) {
      print('Error: $e');
      Fluttertoast.showToast(msg: "Error initiating payment: ${e.toString()}");
    }
  }

  Future<void> sucesspay({
    required String paymentId,
    required String userid,
    required String orderId,
    required double amount,
    required String vendorname,
    required String transactionName,
    required String paymentStatus,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/usersucesspay/${widget.userId}');

    print('⏳ Starting payment success process...');
    print('🔗 URL: $url');
    print('📦 Request Data:');
    print('  - Payment ID: $paymentId');
    print('  - User ID: $userid');
    print('  - Order ID: $orderId');
    print('  - Amount: $amount');
    print('  - Vendor ID: ${widget.vendorId}');
    print('  - Transaction Name: $transactionName');
    print('  - Payment Status: $paymentStatus');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'payment_id': paymentId,
          'order_id': orderId,
          'amount': widget.totalamount,
          'userid': userid,
          'vendorname': widget.vendorName,
          'vendorid': widget.vendorId,
          'transaction_name': transactionName,
          'payment_status': paymentStatus,
        }),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "✅ Payment verified successfully");
        print('✅ Navigating to ParkingPage...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BlockSpot(userId: widget.userId),
          ),
        );
      } else {
        throw Exception('❌ Failed to store payment data: ${response.body}');
      }
    } catch (e) {
      print('🚨 Error occurred: ${e.toString()}');
      Fluttertoast.showToast(msg: "Error saving payment details: ${e.toString()}");
    }
  }

  Future<void> _logPaymentEvent(String status, String? paymentId, String? orderId, String? message) async {
    final logUrl = Uri.parse('${ApiConfig.baseUrl}vendor/userlog/${widget.userId}');

    await http.post(
      Uri.parse(logUrl as String),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'payment_id': paymentId ?? '',
        'order_id': orderId ?? '',
        'vendor_id': widget.vendorId ?? '',
        'plan_id': widget.userId ?? '',
        'transaction_name': 'UserBooking',
        'payment_status': status,
        'amount': widget.totalamount,
        'message': message ?? '',
      }),
    );
  }

  void handlePaymentSuccessResponse(PaymentSuccessResponse response) async {
    Fluttertoast.showToast(
      msg: "Payment Success: ${response.paymentId}",
      toastLength: Toast.LENGTH_SHORT,
    );
    print('Payment Success: ${response.paymentId}');

    // Call sucesspay and wait for it to complete
    await sucesspay(
      vendorname: widget.vendorName,
      paymentId: response.paymentId!,
      userid: widget.userId,
      orderId: response.orderId!,
      amount: double.parse(widget.totalamount),
      transactionName: 'UserBooking',
      paymentStatus: 'verified',
    );

    // Call _registerParking and wait for it to complete
    await _registerParking(paymentId: response.paymentId!);
  }

  void handlePaymentErrorResponse(PaymentFailureResponse response) async {
    print("Payment Error Code: ${response.code}");
    print("Payment Error Message: ${response.message}");

    // Log error to the API
    await _logPaymentEvent('error', null, null, response.message);
    Fluttertoast.showToast(
      msg: "Payment Failed: ${response.message}",
      toastLength: Toast.LENGTH_SHORT,
    );
    print('Payment Failed: ${response.message}');

    // Show retry option
    _showRetryDialog();
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('Payment Failed'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'There was an issue with the payment. Would you like to try again?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Icon(Icons.payment, size: 50, color: Colors.grey),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                createOrderAndOpenCheckout(); // Retry by creating a new order
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                backgroundColor: Colors.blue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParkingPage(userId: widget.userId),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                backgroundColor: Colors.grey.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void handleExternalWallet(ExternalWalletResponse response) async {
    await _logPaymentEvent('external_wallet', null, null, response.walletName);
    Fluttertoast.showToast(
      msg: "External Wallet: ${response.walletName}",
      toastLength: Toast.LENGTH_SHORT,
    );
    print('External Wallet: ${response.walletName}');
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }


  Future<void> _registerParking({required String paymentId}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String formattedDate = widget.parkingDate;
      String formattedTime = widget.parkingTime;
      DateTime now = DateTime.now();

      // Prepare data for the booking
      var data = {
        'userid': widget.userId,
        'place': widget.vendorName,
        'vehicleNumber': widget.vehicleNumber,
        'vendorName': widget.vendorName,
        'time': formattedTime,
        'vendorId': widget.vendorId,
        'bookingDate': DateFormat("dd-MM-yyyy").format(now),
        'parkingDate': formattedDate,
        'carType': widget.carType,
        'personName': _user?.username ?? '',
        'mobileNumber': _user?.mobileNumber ?? '',
        'sts': widget.sts,
        'amount': widget.amount,
        'hour': '', // For subscription, hour is empty
        'subscriptionType': widget.subscriptionType,
        'status': "PARKED",
        'vehicleType': widget.vehicleType,
        'parkingTime': formattedTime,
        'parkedDate': formattedDate,
        'parkedTime': formattedTime,
        'approvedDate': formattedDate,
        'approvedTime': formattedTime,
        'bookingTime': DateFormat("hh:mm a").format(now),
        'cancelledStatus': "",
        'bookType': widget.bookType,
        'invoice':paymentId,
        'subsctiptionenddate': widget.subsctiptionenddate, // Include end date
      };

      print('Sending data to server: ${jsonEncode(data)}');
      print('Requesting URL: ${ApiConfig.baseUrl}vendor/createbooking');

      var response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/createbooking'),
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );

      print('Response status: ${response.statusCode}');
      try {
        var decodedBody = jsonDecode(response.body);
        print('Response body: ${jsonEncode(decodedBody)}');
      } catch (e) {
        print('Response body (raw): ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Success: ${responseData['success']}, OTP: ${responseData['otp']}, Booking ID: ${responseData['bookingId']}');
        if (responseData['success'] == true) {
          final String otp = responseData['otp'].toString();
          final String bookingId = responseData['bookingId'];
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parking registered successfully!')),
          );
          // Navigate to BlockSpot only after successful booking
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BlockSpot(userId: widget.userId),
            ),
          );
        } else {
          throw Exception('Server error: ${responseData['message']}');
        }
      } else {
        throw Exception('Failed to create booking: ${response.body}');
      }
    } catch (e) {
      print('Error: $e\nStack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register parking: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing Payment')),
      body: SafeArea(
        child: const Center(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Processing payment, please wait..."),
          ],
        ),
      ),
      ),);
  }
}