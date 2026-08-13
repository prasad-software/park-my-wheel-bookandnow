import 'dart:convert';
import 'dart:io';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/vendor/meetings/meetinglist.dart';

import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';

import 'package:mywheels/config/authconfig.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';

import '../../../../config/colorcode.dart';



class schedulemeeting extends StatefulWidget {
  final String vendorid;
  const schedulemeeting({super.key,

    required this.vendorid,
    // required this.userName
  });

  @override
  _schedulemeetingState createState() => _schedulemeetingState();
}



class _schedulemeetingState extends State<schedulemeeting> {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDateTime;
  String? _department;
  final bool _isSlotListingExpanded = false;
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Regular expression for validating email
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null; // Return null if the email is valid
  }
  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number';
    }
    if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  // Vendor? _vendor;
  final bool _isEditing = false;
  bool _issLoading = false;
  // final TextEditingController _department = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _besttimeController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _mobileNumberFocusNode = FocusNode();
  final FocusNode _websiteFocusNode = FocusNode();
  final FocusNode _besttimeFocusNode = FocusNode();


  File? _selectedImage;
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Prevent multiple submissions
      if (_issLoading) return;

      setState(() {
        _issLoading = true; // Show loading indicator
      });

      // Collecting data from the form fields
      final String name = _nameController.text;
      final String email = _emailController.text;
      final String mobile = _mobileNumberController.text;
      final String website = _websiteController.text;
      final String bestTime = _besttimeController.text;
      final String department = _department ?? '';

      // Creating the request body
      final Map<String, dynamic> requestBody = {
        'vendorId': widget.vendorid,
        'name': name,
        'email': email,
        'mobile': mobile,
        'businessURL': website.isNotEmpty ? website : null,
        'callbackTime': bestTime,
        'department': department,
      };

      try {
        // Sending the POST request
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}vendor/createmeeting"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          // Handle success
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => meetinglist(vendorid: widget.vendorid)),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Callback arranged successfully!')),
          );
        } else {
          // Handle error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.body}')),
          );
        }
      } catch (e) {
        // Handle exceptions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        setState(() {
          _issLoading = false; // Hide loading indicator after submission
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
    }

  }
  late List<Widget> _pagess;

  @override
  void initState() {
    super.initState();



    final now = DateTime.now();
    dateTimeController.text = _formatDateTime(now);
    selectedDateTime = now;
  }
  void _showDateTimePicker() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(now.year, now.month, now.day), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                DateTime currentNow = DateTime.now(); // Refresh the current time
                if (dateTime.year == currentNow.year &&
                    dateTime.month == currentNow.month &&
                    dateTime.day == currentNow.day &&
                    dateTime.isBefore(currentNow)) {
                  // Restrict past times only on the current day
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot select a past time today!")),
                  );
                  return;
                }
                setState(() {
                  selectedDateTime = dateTime;
                  // Update the controller text to show formatted date
                  dateTimeController.text = _formatDateTime(dateTime);
                  _besttimeController.text = _formatDateTime(dateTime); // Also update this controller if needed
                });
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat("dd-MM-yyyy hh:mm a").format(dateTime);  // Full date + time with AM/PM
  }



  @override
  Widget build(BuildContext context) {
    // final height = MediaQuery.of(context).size.height;
    // final width = MediaQuery.of(context).size.width;
    return  _issLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      backgroundColor: ColorUtils.secondarycolor(),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),

        title:  Text(
          'Schedule meeting',
          style:   GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Container(
                //   decoration: BoxDecoration(
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                //         offset: Offset(0, 4), // Offset in x and y direction
                //         blurRadius: 6, // Blur radius for the shadow
                //       ),
                //     ],
                //   ),
                //   child: ElevatedButton.icon(
                //     onPressed: () {},
                //     icon: Icon(Icons.schedule),
                //     label: Text("Schedule Meeting"),
                //     style: ElevatedButton.styleFrom(
                //       foregroundColor: Colors.white, // Text color
                //       backgroundColor: ColorUtils.primarycolor(), // Button color
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(5), // Circular border radius
                //       ),
                //     ),
                //   ),
                // ),
                //
                // Divider(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.phone_in_talk_rounded),
                        ),

                         Flexible(
                          child: Text(
                            "Let's Talk",
                            style:   GoogleFonts.poppins(fontSize: 18),
                          ),
                        ),
                      ],
                    ),

                     Row(
                      children: [
                        const SizedBox(width: 18), // Align the text properly after the icon
                        Expanded(
                          child: Text(
                            "Schedule a call with our advertising team",
                            style:   GoogleFonts.poppins(fontSize: 16),
                            overflow: TextOverflow.clip, // Adjust text for overflow
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                meetingfield(
                   labelColor: Colors.black,
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  keyboard: TextInputType.text,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  inputFormatter: const [], // You can add any input formatters here
                  label: '*Name',
                  hint: 'Name',
                  prefixIcon: Icon(Icons.person, color: ColorUtils.primarycolor()), // Icon color for parking place

                  selectedColor: ColorUtils.primarycolor(),

                ),

                // Name Field

                const SizedBox(height: 16),


                SizedBox(
                  // width: 200, // Adjust width as needed
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Reduce padding
                      labelText: 'Department',
                      labelStyle:   GoogleFonts.poppins(color: Colors.black),
                      hintText: 'Select Department',
                      filled: true, // Important for setting background color
                      fillColor: Colors.white,
                      hintStyle:  GoogleFonts.poppins(color: ColorUtils.primarycolor()),
                      prefixIcon: Icon(Icons.business, color: ColorUtils.primarycolor()),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'Marketing', child: Text('Marketing')),
                      DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                      DropdownMenuItem(value: 'Product', child: Text('Product')),
                      // Add more options here
                    ],
                    onChanged: (value) {
                      setState(() {
                        _department = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a department';
                      }
                      return null;
                    },
                  ),
                ),


                const SizedBox(height: 16),
                meetingfield(
                  labelColor: Colors.black,
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboard: TextInputType.emailAddress,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  inputFormatter: const [], // You can add any input formatters here
                  label: '*Email',
                  hint: 'Email',
                  prefixIcon: Icon(Icons.email, color: ColorUtils.primarycolor()), // Icon color for parking place
                  validator: _validateEmail,
                  selectedColor: ColorUtils.primarycolor(),

                  onChanged: (value) {
                    // Trigger validation on change
                    setState(() {
                      // This will rebuild the widget and hide the error message if the email is valid
                      _validateEmail(value);
                    });
                  },
                ),


                const SizedBox(height: 16),
                meetingfield(
                  validator: _validateMobile,
                  labelColor: Colors.black,
                  controller: _mobileNumberController,
                  focusNode: _mobileNumberFocusNode,
                  keyboard: TextInputType.phone,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  inputFormatter: [
                    FilteringTextInputFormatter.digitsOnly, // Allow only digits
                    LengthLimitingTextInputFormatter(10),
                  ], // You can add any input formatters here
                  label: '*Mobile',
                  hint: 'Mobile',
                  prefixIcon: Icon(Icons.phone_android, color: ColorUtils.primarycolor()), // Icon color for parking place

                  selectedColor: ColorUtils.primarycolor(),
                  onChanged: (value) {
                    // Trigger validation on change
                    setState(() {
                      // This will rebuild the widget and hide the error message if the email is valid
                      _validateMobile(value);
                    });
                  },
                ),
                // Mobile Field

                const SizedBox(height: 16),
                CusTextField(
                  labelColor: Colors.black,
                  controller: _websiteController,
                  focusNode: _websiteFocusNode,
                  keyboard: TextInputType.text,
                  obscure: false,
                  textInputAction: TextInputAction.next,
                  inputFormatter: const [], // You can add any input formatters here
                  label: 'Business Website Url',
                  hint: 'Business Website Url',
                  prefixIcon: Icon(Icons.web, color: ColorUtils.primarycolor()), // Icon color for parking place

                  selectedColor: ColorUtils.primarycolor(),

                ),
                // Website Field

                const SizedBox(height: 16),

                // Best Time to Contact Field
                meetingfield(
                  labelColor: Colors.black,
                  selectedColor: ColorUtils.primarycolor(),
                  controller: _besttimeController,
                  focusNode: _besttimeFocusNode,
                  keyboard: TextInputType.text,
                  obscure: false,
                  textInputAction: TextInputAction.done,
                  inputFormatter: const [],
                  label: '*Best time for Callback',
                  hint: 'Best time for Callback',
                  prefixIcon: Icon(Icons.calendar_today, color: ColorUtils.primarycolor(),),
                  readOnly: true,
                  onTap: () async {
                    _showDateTimePicker();
                  },
                ),
                const SizedBox(height: 16),

                // Submit Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                          offset: const Offset(0, 4), // Offset in x and y direction
                          blurRadius: 6, // Blur radius for the shadow
                        ),
                      ],
                    ),
                    child: _issLoading
                        ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                        : ElevatedButton.icon(
                      onPressed: _issLoading ? null : _submitForm, // Disable button if loading
                      icon: const Icon(Icons.read_more,color:Colors.white),
                      label: const Text("Arrange Callback"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, // Text color
                        backgroundColor: ColorUtils.primarycolor(), // Button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5), // Circular border radius
                        ),
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
    );
  }
}




class meetingfield extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Widget prefixIcon;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final Function()? onTap;
  final Widget? suffixIcon;
  final Color selectedColor; // For focused border color
  final Color labelColor; // For label text color
  final String? Function(String?)? validator; // Validator function
  final Function(String)? onChanged;
  const meetingfield({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    required this.selectedColor,
    required this.labelColor,
    this.validator, this.onChanged, // Initialize validator
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      obscureText: obscure,
      textInputAction: textInputAction,
      inputFormatters: inputFormatter,
      onChanged: onChanged, // Add this line
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        labelStyle:   GoogleFonts.poppins(color: labelColor),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(color: Colors.red, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(color: Colors.red, width: 0.5),
        ),
      ),
      readOnly: readOnly,
      onTap: onTap,
      onFieldSubmitted: onSubmitted,
      validator: validator, // Use the validator function
    );
  }
}