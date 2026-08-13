import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'dart:convert';

class Transactionhistory extends StatefulWidget {
  final String userId;
  const Transactionhistory({super.key, required this.userId});

  @override
  _traPageState createState() => _traPageState();
}

class _traPageState extends State<Transactionhistory> {
  List<Map<String, String>> transactions = [];
  List<Map<String, String>> allTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/fetchpay/${widget.userId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['payments'] != null && data['payments'] is List) {
          final List<Map<String, String>> loadedTransactions = (data['payments'] as List).map<Map<String, String>>((tx) {
            final DateTime createdAt = DateTime.parse(tx['createdAt']);
            final formattedDate = "${createdAt.day.toString().padLeft(2, '0')}/"
                "${createdAt.month.toString().padLeft(2, '0')}/"
                "${createdAt.year} - "
                "${TimeOfDay.fromDateTime(createdAt).format(context)}";

            return {
              'title': tx['vendorname']?.toString() ?? 'Parking Payment',
              'date': formattedDate,
              'amount': '₹${tx['amount'].toString()}',
            };
          }).toList();

          setState(() {
            transactions = loadedTransactions;
            allTransactions = loadedTransactions;
          });
        } else {
          print("No payments data available or data format is incorrect.");
        }

        setState(() => isLoading = false);
      } else {
        print('Error: Server responded with status code ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(   titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.black),
        // title: const Text('',style: TextStyle(color: Colors.white),), // AppBar title
        title: Text(
          'Transaction History',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18, // Adjust size as needed
            // fontWeight: FontWeight.w600, // Adjust weight if needed
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      // Optionally open a search filter modal
                    },
                  ),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search Transactions',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onChanged: (value) {
                        final query = value.toLowerCase();

                        final filtered = allTransactions.where((tx) {
                          return tx['title']!.toLowerCase().contains(query) ||
                              tx['date']!.toLowerCase().contains(query) ||
                              tx['amount']!.toLowerCase().contains(query);
                        }).toList();

                        final unmatched = allTransactions.where((tx) => !filtered.contains(tx)).toList();

                        setState(() {
                          transactions = [...filtered, ...unmatched];
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text("No transactions found"))
                : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return TransactionCard(
                  title: transactions[index]['title']!,
                  date: transactions[index]['date']!,
                  amount: transactions[index]['amount']!,
                );
              },
            ),
          ),
        ],
      ),
      ),  );
  }
}

class TransactionCard extends StatelessWidget {
  final String title;
  final String date;
  final String amount;

  const TransactionCard({super.key, required this.title, required this.date, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0), // Add padding around the container
      margin: const EdgeInsets.symmetric(vertical: 2.0), // Space between cards
      decoration: BoxDecoration(
        color: Colors.white, // Background color
        borderRadius: BorderRadius.circular(10), // Rounded corners
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
                color: ColorUtils.primarycolor(), // Replace with ColorUtils.primarycolor() if needed
                width: 2, // Border width
              ),
            ),
            child: CircleAvatar(
              radius: 20, // Avatar radius
              backgroundColor: Colors.white, // Background color of the avatar
              child: Icon(
                Icons.local_parking, // Parking icon
                color: ColorUtils.primarycolor(), // Replace with ColorUtils.primarycolor() if needed
                size: 20, // Icon size
              ),
            ),
          ),
          const SizedBox(width: 8), // Space between the CircleAvatar and the text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align the text to the start
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), // Transaction title style
                  overflow: TextOverflow.ellipsis, // Handle overflow
                ),
                const SizedBox(height: 4), // Space between the title and date
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey), // Date style
                ),
              ],
            ),
          ),
          const SizedBox(width: 8), // Space between the transaction title and amount
          Text(
            amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green), // Amount style
          ),
        ],
      ),
    );
  }
}
