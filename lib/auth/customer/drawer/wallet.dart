import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/authconfig.dart';

class Wallet extends StatefulWidget {
  final String userid; // Accepts a user ID
  const Wallet({super.key, required this.userid}); // Constructor

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<Wallet> {
  late Future<WalletInfo> _walletInfo;

  @override
  void initState() {
    super.initState();
    _walletInfo = fetchWalletInfo(widget.userid); // Pass the user ID to fetch data
  }

  Future<WalletInfo> fetchWalletInfo(String userid) async {
    try {
      // Log the API URL
      final url = '${ApiConfig.baseUrl}getwallet/$userid';
      print('Fetching wallet info from URL: $url');

      // Make the HTTP GET request
      final response = await http.get(Uri.parse(url));

      // Log the status code
      print('Response Status Code: ${response.statusCode}');

      // Log the raw response body
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse and return the WalletInfo object
        return WalletInfo.fromJson(jsonDecode(response.body));
      } else {
        // Log an error message for non-200 status codes
        print('Error: Failed to load wallet info. Status code: ${response.statusCode}');
        throw Exception('Failed to load wallet info');
      }
    } catch (e) {
      // Log the exception message for debugging
      print('Exception in fetchWalletInfo: $e');
      throw Exception('Error occurred while fetching wallet info');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(titleSpacing: 0,
        backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.white),
        // title: const Text('',style: TextStyle(color: Colors.white),), // AppBar title
        title: Text(
          'Wallet ',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18, // Adjust size as needed
            fontWeight: FontWeight.w600, // Adjust weight if needed
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            const SizedBox(height: 10),
            Center(
              child: FutureBuilder<WalletInfo>(
                future: _walletInfo,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.hasData) {
                    final wallet = snapshot.data!;
                    return buildWalletCard(wallet, width, height);
                  } else {
                    return const Text('No data available');
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Displaying the transactions
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),  // To avoid nested scroll issues
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return TransactionRow(
                        title: transaction['title']!,
                        date: transaction['date']!,
                        amount: transaction['amount']!,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),


      ), );
  }

  Widget buildWalletCard(WalletInfo wallet, double width, double height) {
    return Container(
      width: width * 0.9,
      height: height * 0.25,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(10, 10),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(-10, -10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -10,
            left: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: width * 0.2,
                    ),
                    Text(
                      'Wallet Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text(
                      '**** **** **** ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      wallet.cardLastFourDigits,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  wallet.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Wallet Balance: ₹${wallet.walletAmount}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WalletInfo {
  final String name;
  final String walletAmount;
  final String cardLastFourDigits;

  WalletInfo({
    required this.name,
    required this.walletAmount,
    required this.cardLastFourDigits,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      name: json['data']['userName'] ?? 'Unknown User',  // Handling missing name
      walletAmount: json['data']['walletamount'] ?? '0',  // Handling missing wallet amount
      cardLastFourDigits: json['data']['cardLastFourDigits'] ?? '****',  // Default to '****' if missing
    );
  }
}


// TransactionRow Widget for individual transaction items
class TransactionRow extends StatelessWidget {
  final String title;
  final String date;
  final String amount;

  const TransactionRow({super.key, required this.title, required this.date, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0), // Space between rows
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2), // Shadow color
            blurRadius: 6, // Shadow blur radius
            offset: const Offset(0, 2), // Shadow offset
          ),
        ],
      ),
      child: Row(
        children: [
          // CircleAvatar with parking icon
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ColorUtils.primarycolor(), // Border color
                width: 2, // Border width
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.local_parking,
                color: ColorUtils.primarycolor(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8), // Space between the CircleAvatar and the text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

final List<Map<String, String>> transactions = [
  {"title": "Vega City Mall", "date": "17/10/2024", "amount": "₹200"},
  {"title": "City Center", "date": "16/10/2024", "amount": "₹300"},
  {"title": "Market Place", "date": "15/10/2024", "amount": "₹150"},
  {"title": "Super Mall", "date": "14/10/2024", "amount": "₹400"},
  {"title": "Downtown Plaza", "date": "13/10/2024", "amount": "₹250"},
  {"title": "The Outlet", "date": "12/10/2024", "amount": "₹500"},
  {"title": "Shopping Plaza", "date": "11/10/2024", "amount": "₹350"},
  {"title": "Local Market", "date": "10/10/2024", "amount": "₹180"},
  {"title": "City Park", "date": "09/10/2024", "amount": "₹220"},
  {"title": "Beach Mall", "date": "08/10/2024", "amount": "₹300"},
];
