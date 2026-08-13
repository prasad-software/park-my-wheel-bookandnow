import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:mywheels/pageloader.dart'; // For jsonEncode


class vendorsupport extends StatefulWidget {
  final String vendorid;

  // Constructor with required parameter userId
  const vendorsupport({super.key, required this.vendorid});

  @override
  State<vendorsupport> createState() => _vendorsupportState();
}

class _vendorsupportState extends State<vendorsupport> {
  bool _isLoading = false; // Track the loading state

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true; // Set loading to true when fetching data
    });

    try {
      final userId = widget.vendorid; // Assuming userId is passed to the widget
      final data = await fetchData(userId);
      setState(() {
        _dataList = data;
        _isLoading = false; // Set loading to false once data is fetched
      });
    } catch (e) {
      setState(() {
        _isLoading = false; // Set loading to false if there is an error
      });
      print('Error: $e');
    }
  }


  String? selectedValue;
  TextEditingController description = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void _showFeedbackModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the modal to resize
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea( // Add SafeArea here
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom, // Add both viewInsets and padding
            ),
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Center Image
                    SvgPicture.asset('assets/call.svg', height: 200),

                    // Bold Text with larger font size
                    Text(
                      'Need Assistance?',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Our support team is available 24/7 to help you.',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w100),
                      textAlign: TextAlign.center,
                    ),

                    // Star Rating
                    const SizedBox(height: 5),

                    // Description Field
                    const SizedBox(height: 5),
                    // Update the TextField to use the description controller
                    TextField(
                      controller: description, // Assign the controller here
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorUtils.primarycolor(),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorUtils.primarycolor(),
                          ),
                        ),
                        labelText: 'Description',
                        labelStyle: GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                        ),
                        hintText: 'Enter your description here',
                      ),
                      maxLines: 3,
                      onTap: () {
                        // Remove this line - let the keyboard work normally
                        // FocusScope.of(context).unfocus();
                      },
                    ),

                    // Submit Button
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        print('Submit button clicked');
                        // Handle submit action
                        await _submitFeedback(description.text);
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width - 32, // Subtract padding for full width
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: ColorUtils.primarycolor(),
                        ),
                        child: Center(
                          child: Text(
                            'Submit',
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10), // Extra space at the bottom for safe area
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitFeedback(String feedback) async {
    const url = '${ApiConfig.baseUrl}vendor/createhelpvendor'; // Replace with your API endpoint
    try {
      // Print the entered data before submission
      print('Submitting feedback...');
      print('Description: ${description.text}');  // Use the controller's text
      print('User  ID: ${widget.vendorid}');  // Print the userId
      print('User  Active: true');  // Print the userActive value (boolean)

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': description.text, // Use the controller's text
          'vendorid': widget.vendorid,
          'vendoractive': true,  // Send as a boolean value, not a string
        }),
      );

      print('Response status: ${response.statusCode}');  // Debug: Check the response status

      if (response.statusCode == 201) {
        // Feedback submitted successfully
        print('Data submitted successfully');  // Debug: Success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data submitted successfully!')),
        );
        description.clear(); // Clear the text field
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => vendorsupport(vendorid: widget.vendorid,)),
        );
        // Close the modal
      } else {
        // Handle error
        print('Failed to submit data. Status code: ${response.statusCode}');  // Debug: Show error code
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit data.')),
        );
      }
    } catch (e) {
      // Handle exception
      print('Error occurred: $e');  // Debug: Print the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return  Scaffold(backgroundColor: Colors.white,
      key: _scaffoldKey,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: AppBar(titleSpacing: 0,
          backgroundColor:  ColorUtils.secondarycolor(), // Example app bar background color
          title:  Text(
            "Help & Support",
            style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_rounded,size: 34,color: ColorUtils.primarycolor(),), // Plus icon
              onPressed: () {
                _showFeedbackModal(context);

              },
            ),
            const SizedBox(width: 15,),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif()
            : SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              // If loading, show the CircularProgressIndicator
              _isLoading
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Image.asset('assets/gifload.gif',),
                ),
              )
                  : _dataList.isEmpty
                  ?Column(
                mainAxisAlignment: MainAxisAlignment.center, // This ensures the content is centered vertically
                children: [
                  const SizedBox(height: 300,),
                  Container(
                    child: Text(
                      'No chat data available',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              )

                  : const SizedBox(height: 20), // Add some space between the form and the list

              // Your ListView.builder code here remains unchanged
              ListView.builder(
                itemCount: _dataList.length,
                shrinkWrap: true,
                physics: const ScrollPhysics(),
                itemBuilder: (BuildContext context, int index) {
                  final item = _dataList[index];

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResponseScreen(
                                  docId: item.id,
                                  issue: item.comment,
                                  status: item.status,
                                  userid: widget.vendorid,

                                ),
                              ),
                            );
                          } catch (e) {
                            print('Navigation error: $e');
                          }
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            border: Border.all(
                              color: ColorUtils.primarycolor(),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.grey,
                                offset: Offset(0.0, 1.0),
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.poppins(color: Colors.black),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: "Date: ",
                                              style:GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            TextSpan(
                                              text: item.date != null
                                                  ? DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(item.date))
                                                  : DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),

                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.poppins(color: Colors.black),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: "Description: ",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            TextSpan(
                                              text: item.comment,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.poppins(color: Colors.black),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: "Status: ",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            TextSpan(
                                              text: item.status,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 16,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ResponseScreen(
                                          docId: item.id,
                                          issue: item.comment,
                                          status: item.status,
                                          userid: widget.vendorid,

                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ColorUtils.primarycolor(),
                                      border: Border.all(
                                        color: ColorUtils.primarycolor(),
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.grey,
                                          offset: Offset(0.0, 1.0),
                                          blurRadius: 6.0,
                                        ),
                                      ],
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(20),
                                      ),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 7,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10), // Space between list items
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),



      ),);
  }
}

// import 'dart:convert';
// import 'package:http/http.dart' as http;

Future<List<DataItem>> fetchData(String vendorId) async {
  // Construct the URL
  final url = Uri.parse('${ApiConfig.baseUrl}vendor/gethelpvendor/$vendorId');

  // Debugging: Print the constructed URL
  print('Request URL: $url');

  // Send the GET request
  final response = await http.get(url);

  // Debugging: Print the status code and response body
  print('Response Status Code: ${response.statusCode}');
  print('Response Body: ${response.body}');

  // Check if the response status is OK (200)
  if (response.statusCode == 200) {
    // Parse the JSON response
    final Map<String, dynamic> jsonData = json.decode(response.body);

    // Debugging: Print the parsed JSON data
    print('Parsed JSON Data: $jsonData');

    // Extract the list of help requests
    final List<dynamic> helpRequests = jsonData['helpRequests'] ?? [];

    // Debugging: Print the list of help requests
    print('Help Requests List: $helpRequests');

    // Map the list to DataItem objects
    return helpRequests.map((item) => DataItem.fromJson(item)).toList();
  } else {
    // Throw an exception for non-200 responses
    throw Exception('Failed to fetch data: ${response.statusCode}');
  }
}

// Dummy data list
List<DataItem> _dataList = []; // Initialize the data list

class DataItem {
  final String date;
  final String id;
  final String userid;
  final String comment;
  final String status;

  DataItem({
    required this.date,
    required this.id,
    required this.userid,
    required this.comment,
    required this.status,
  });

  factory DataItem.fromJson(Map<String, dynamic> json) {
    return DataItem(
      date: json['date'] ?? '',
      id:json['_id'] ?? '',
      userid: json['userId'] ?? '',
      comment: json['description'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class ResponseScreen extends StatefulWidget {
  final String? docId;
  final String? issue;
  final String?userid;

  final String? status;
  const ResponseScreen({super.key,
    required this.docId,
    required this.issue,
    required this.userid,

    required this.status,
  });

  @override
  _ResponseScreenState createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  TextEditingController responseController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isUploading = false;
  List<dynamic> chatbox = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    fetchChatData();
  }
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  Future<void> fetchChatData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}vendor/fetchchat/${widget.docId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          chatbox = data['chatbox'];
          isLoading = false;
        });
        _scrollToBottom(); // Scroll to bottom after messages are loaded
      } else {
        throw Exception('Failed to load chat');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error fetching chat data')));
    }
  }


  Future<void> sendMessage(String message) async {
    print('sendMessage called with message: $message');
    if (message.trim().isEmpty && _image == null) {
      print('Message is empty and no image, exiting...');
      return;
    }

    setState(() {
      _isUploading = true; // Start uploading
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}vendor/sendchat/${widget.docId}'),
      );

      request.headers["Content-Type"] = "application/json";

      // Add text message
      request.fields['vendorid'] = widget.userid!;
      request.fields['message'] = message;

      // Add image if available
      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      }

      print('Sending request with message: $message');

      final response = await request.send();

      print('Response received with status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Message sent successfully');

        String formattedTime = DateTime.now().toLocal().toString(); // Format time
        setState(() {
          chatbox.add({
            "vendorid": widget.userid,
            "message": message,
            "image": _image?.path,
            "timestamp": formattedTime, // Use 'timestamp' to match UI expectation
          });
        });
        responseController.clear();
        _image = null;
        _scrollToBottom();
      } else {
        print('Failed to send message. Status code: ${response.statusCode}');
        throw Exception('Failed to send message');
      }
    } catch (e) {
      print('Error in sendMessage: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error sending message')));
    } finally {
      setState(() {
        _isUploading = false; // Stop uploading
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Automatically upload the image once it's picked
      if (_image != null) {
        // Call sendMessage with the current text in the responseController
        await sendMessage(responseController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {



    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.6),
                spreadRadius: 12,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: ColorUtils.primarycolor(),
            iconTheme: const IconThemeData(color: Colors.white),
            title:  Text('Support Screen', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
            children: [
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      return chatbox.isEmpty
                          ?  Center(
                        child: Text(
                          'Send response about your issue',
                          style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        controller: _scrollController,
                        itemCount: chatbox.length,
                        itemBuilder: (context, index) {
                          final message = chatbox[index];
                          return Align(
                            alignment: (message['vendorid'] == widget.userid || 
                                        message['userid'] == widget.userid || 
                                        message['userId'] == widget.userid)
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (message['vendorid'] == widget.userid || 
                                        message['userid'] == widget.userid || 
                                        message['userId'] == widget.userid)
                                    ? Colors.green[100]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message['message'], style:GoogleFonts.poppins(fontSize: 16)),
                                  if (message['image'] != null)
                                    message['image'].startsWith('http')
                                        ? Image.network(
                                      message['image'],
                                      width: 200,
                                      height: 200,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                (loadingProgress.expectedTotalBytes ?? 1)
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return  Text(
                                          'Image failed to load',
                                          style: GoogleFonts.poppins(color: Colors.red),
                                        );
                                      },
                                    )
                                        : Image.file(
                                      File(message['image']),
                                      width: 200,
                                      height: 200,
                                      errorBuilder: (context, error, stackTrace) {
                                        return  Text(
                                          'Image not found',
                                          style: GoogleFonts.poppins(color: Colors.red),
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 5),
                                  Text(
                                    message['timestamp'] != null
                                        ? DateFormat('dd/MM/yyyy hh:mm a')
                                        .format(DateTime.parse(message['timestamp']))
                                        : DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),


              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 5.0, right: 5.0, bottom: 5.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: responseController,
                          decoration: InputDecoration(
                            hintText: 'Type your response here...',
                            hintStyle: GoogleFonts.poppins(color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: Colors.white,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: Colors.white,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: Colors.white,
                              ),
                            ),
                            filled: true,
                            fillColor: ColorUtils.primarycolor(),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 8.0, right: 10),
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: const CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.photo,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  sendMessage(responseController.text);
                                },
                                child: const CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Center(
                                    child: Icon(
                                      Icons.send,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                
                          ),
                          enabled: !_isUploading,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),

            ],
          ),
          if (_isUploading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      ),);
  }
}