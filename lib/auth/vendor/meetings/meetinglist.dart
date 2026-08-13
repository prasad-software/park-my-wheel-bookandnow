
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/pageloader.dart';

import '../../../config/colorcode.dart';
import '../menus/vendormeeting.dart';



class meetinglist extends StatefulWidget {
  final String vendorid;
  const meetinglist({super.key,

    required this.vendorid,
    // required this.userName
  });

  @override
  _meetinglistState createState() => _meetinglistState();
}



class _meetinglistState extends State<meetinglist> {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDateTime;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    setState(() {
      isLoading = true; // Show the loader when fetching data
    });

    try {
      final response = await http.get(
          Uri.parse(
              "${ApiConfig.baseUrl}vendor/fetchmeeting/${widget.vendorid}")
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Extract the 'meetings' list
        final List<dynamic> meetingsJson = responseData['meetings'];

        setState(() {
          _meetings =
              meetingsJson.map((json) => Meeting.fromJson(json)).toList();
          isLoading = false; // Hide loader after data is fetched
        });

        print('Fetched meetings: $_meetings');
      } else {
        setState(() {
          isLoading = false; // Hide loader if error occurs
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('No meetings found')),
        // );
      }
    } catch (e) {
      setState(() {
        isLoading = false; // Hide loader in case of error
      });
      print('Error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  List<Meeting> _meetings = [];

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height;
    final width = MediaQuery
        .of(context)
        .size
        .width;
    return  Scaffold(
      backgroundColor: ColorUtils.secondarycolor(),
      appBar: AppBar(titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(
          'Advertise with us',
          style:   GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
        actions: const [
        ],
      ),
      body: isLoading
          ? const LoadingGif()
          :
          SafeArea(
            child: SingleChildScrollView(
                    child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  schedulemeeting(vendorid: widget.vendorid),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule, color: Colors.white),
                        label: const Text("Schedule Meeting"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: ColorUtils.primarycolor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Spacer(), // Push the button to the right
                    ],
                  ),
                  _meetings.isEmpty
                      ? Center(
                    child: Container(
                      // This Container ensures the message is centered vertically
                      width: double.infinity, // Take full width
                      height: MediaQuery.of(context).size.height - 170, // Adjust height depending on AppBar and button heights
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20), // Optional padding for visual spacing
                        child: Text(
                          'No meetings scheduled yet.',
                          textAlign: TextAlign.center, // Center align the text
                          style:  GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ), // Style for emphasis
                        ),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = _meetings[index];
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                              color: ColorUtils.primarycolor(), width: 0.5),
                          // Green border line
                          borderRadius: BorderRadius.circular(
                              10), // Optional: Add rounded corners
                        ),
                        child: ListTile(
                          title: Text(
                            meeting.name,
                            style:  GoogleFonts.poppins(color: ColorUtils.primarycolor()),
                          ),
                          subtitle: Text(
                              'Email: ${meeting.email}\nMobile: ${meeting
                                  .mobile}\nTime: ${meeting.callbackTime}'),
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
    );
  }
}


// meeting.dart
class Meeting {
  final String id;
  final String name;
  final String email;
  final String mobile;
  // final String website;
  final String callbackTime;
  final String department;

  Meeting({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    // required this.website,
    required this.callbackTime,
    required this.department,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      mobile: json['mobile'],
      // website: json['businessURL'],
      callbackTime: json['callbackTime'],
      department: json['department'],
    );
  }
}