import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mywheels/config/authconfig.dart';

import 'package:mywheels/auth/vendor/map.dart';
import 'package:mywheels/privacypolicydataprivacy.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../config/colorcode.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../customer/splashregister/register.dart';
import 'dummypages/drawermyspace.dart';


class addmyspace extends StatefulWidget {
  final String vendorid;
  const addmyspace({super.key, required this.vendorid});

  @override
  _myspaceState createState() => _myspaceState();
}

class _myspaceState extends State<addmyspace> {
  List<Map<String, TextEditingController>> contacts = [
    {
      'name': TextEditingController(),
      'mobile': TextEditingController(),
    }
  ];
  final TextEditingController _vendorController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _bannerPicture; // Variable to hold picked image
  String? selectedParkingType;
  final List<String> parkingTypes = ['Cars', 'Bikes', 'Others'];
  List<Map<String, String>> parkingEntries = [];
  Future<void> _terms(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(
        headers: <String, String>{'my_header_key': 'my_header_value'},
      ),
    )) {
      throw Exception('Could not launch $url');
    }
  }

  String? _selectedOption = 'Apartment';
  bool isChecked = false;
  String? selectedType;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController noofparking = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool isLoading = false;

  void _showParkingModalSheet(BuildContext context) {
    String? selectedType;
    TextEditingController parkingController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add Parking Details",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        color: Colors.white,
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Parking Type',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 5.0, horizontal: 10.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:     ColorUtils.primarycolor(), ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:     ColorUtils.primarycolor(),  width: 0.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:      ColorUtils.primarycolor(), width: 0.5),
                            ),
                          ),
                          value: selectedType,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedType = newValue;
                            });
                          },
                          items: parkingTypes
                              .where((type) => !parkingEntries.any((entry) => entry['type'] == type))
                              .map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item,
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 40,
                        color: Colors.white,
                        child: TextFormField(
                          controller: parkingController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                            labelText: 'No of Parking',
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 5.0, horizontal: 10.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:  ColorUtils.primarycolor(), ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:     ColorUtils.primarycolor(),  width: 0.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0),
                              borderSide:  BorderSide(color:      ColorUtils.primarycolor(),  width: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                    SizedBox(
                      height: 25,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(), // Button background color
                          foregroundColor: Colors.white, // Button text color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        onPressed: () {
                          if (selectedType != null && parkingController.text.isNotEmpty) {
                            Navigator.pop(context);
                            setState(() {
                              parkingEntries.add({'type': selectedType!, 'count': parkingController.text});
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please select type & enter count")),
                            );
                          }
                        },
                        child: const Text("Add"),
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? validateFields() {
    if (_vendorController.text.isEmpty) {
      return "Please enter Place  name";
    } else if (_contactNumberController.text.isEmpty ||
        _contactNumberController.text.length != 10) {
      return "Please enter the contact person and valid 10-digit contact number";
    } else if (_addressController.text.isEmpty) {
      return "Please enter the address"; // This should trigger if the address is empty
    } else if (_landmarkController.text.isEmpty) {
      return "Please enter the landmark";
    } else if (parkingEntries.isEmpty) {
      return "Please add at least one parking entry";
    } else if (_bannerPicture == null) {
      return "Please upload a vendor banner";
    }
    return null; // All validations passed
  }

  /// Compresses image to avoid 413 Request Entity Too Large from server.
  Future<File> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.absolute.path}_compressed.jpg',
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result != null) {
      final compressedFile = File(result.path);
      final length = await compressedFile.length();
      if (length > 2000000) {
        return await _compressImage(compressedFile);
      }
      return compressedFile;
    } else {
      throw Exception('Image compression failed');
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context, // Use the context from the widget tree
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    try {
                      final compressedFile =
                          await _compressImage(File(pickedFile.path));
                      setState(() {
                        _bannerPicture = XFile(compressedFile.path);
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to process image: $e')),
                        );
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? pickedFile =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    try {
                      final compressedFile =
                          await _compressImage(File(pickedFile.path));
                      setState(() {
                        _bannerPicture = XFile(compressedFile.path);
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to process image: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registerVendor() async {
    setState(() => isLoading = true);

    if (parkingEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select parking type and no of parking")),
      );
      setState(() => isLoading = false);
      return;
    }

    if (_bannerPicture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a vendor banner")),
      );
      setState(() => isLoading = false);
      return;
    }

    if (!isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please agree to the terms and conditions.")),
      );
      setState(() => isLoading = false);
      return;
    }

    var request = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}vendor/spaceregister'));

    request.fields['placetype'] = _selectedOption ?? 'DefaultType';
    request.fields['spaceid'] = widget.vendorid;
    request.fields['vendorName'] = _vendorController.text;
    request.fields['address'] = _addressController.text;
    request.fields['landmark'] = _landmarkController.text;
    request.fields['latitude'] = _latitudeController.text;
    request.fields['longitude'] = _longitudeController.text;
    request.fields['password'] = '';
    request.fields['parkingEntries'] =
        jsonEncode(parkingEntries.isNotEmpty ? parkingEntries : []);

    request.files.add(await http.MultipartFile.fromPath(
      'image',
      _bannerPicture!.path,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    // Debug: Print request details
    print("Sending request to: ${ApiConfig.baseUrl}vendor/spaceregister");
    print("Request Fields: ${request.fields}");
    print("File: ${_bannerPicture!.path}");

    try {
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Debug: Print response status and body
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: $responseBody");

      if (response.statusCode == 201) {
        try {
          var responseData = json.decode(responseBody);
          String message = responseData['message'] ?? '';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => myownspaces(
                      vendorId: widget.vendorid,
                    )),
          );
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        } catch (e) {
          print("JSON Parsing Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid response from server")),
          );
        }
      } else {
        try {
          var responseData = json.decode(responseBody);
          String message = responseData['message'] ?? 'Something went wrong';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        } catch (e) {
          print("Error parsing error response: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Server error: Unable to parse response")),
          );
        }
      }
    } catch (e) {
      print("Request Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending data')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _removeParkingField() {
    if (parkingEntries.isNotEmpty) {
      print("Before removal: $parkingEntries");
      setState(() {
        parkingEntries.removeLast(); // Remove the last parking entry
      });
      print("After removal: $parkingEntries");
    }
  }

  List<Map<String, String>> vendor = [];
  final FocusNode _vendorFocusNode = FocusNode();

  final FocusNode _addressFocusNode = FocusNode();

  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {


    // Ensure selectedParkingType is valid
    if (!parkingTypes.contains(selectedParkingType)) {
      selectedParkingType = null;
    }

    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text(
          'Add My Space',
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Primary color for icons
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: Column(
          children: [
            // Padding(
            //   padding: const EdgeInsets.only(left: 25.0, right: 25.0, top: 0),
            //   child: SizedBox(
            //     height: 70,
            //     child: Image.asset("assets/login.png"),
            //   ),
            // ), // Use a suitable image asset
            // const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Instant Option

                // Schedule Option
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 'Apartment';
                      });
                    },
                    child: Container(
                      height: 35,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'Apartment'
                            ? ColorUtils.primarycolor()
                            : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _selectedOption == 'Apartment' ? Colors.grey : Colors.green,
                          width: 0.5,
                        ),

                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: _selectedOption == 'Apartment'
                                ? Colors.white
                                : Colors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Apartment',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedOption == 'Apartment'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: _selectedOption == 'Apartment'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),
                // Subscription Option
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 'Individual';
                      });
                    },
                    child: Container(
                      height: 35,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedOption == 'Individual'
                            ? ColorUtils.primarycolor()
                            : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _selectedOption == 'Individual' ? Colors.grey : Colors.green,
                          width: 0.5,
                        ),

                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person,
                            color: _selectedOption == 'Individual'
                                ? Colors.white
                                : Colors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Individual',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedOption == 'Individual'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: _selectedOption == 'Individual'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            CustomTextField(
              inputFormatter: const [],
              controller: _vendorController,
              focusNode: _vendorFocusNode,
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              label: 'Place Name',
              hint: 'Enter your Place name',
              onSubmitted: (value) =>
                  FocusScope.of(context).requestFocus(_vendorFocusNode),
            ),

            const SizedBox(height: 15),
            GestureDetector(
              onTap: () async {
                final selectedData = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapsScreen(
                      initialPosition:
                          LatLng(12.9716, 77.5946), // Default location
                    ),
                  ),
                );

                // If data is returned, update the address and other fields in the controller
                if (selectedData != null) {
                  setState(() {
                    _addressController.text = selectedData['address'];
                    _landmarkController.text = selectedData['landmark'];
                    _latitudeController.text = selectedData['latitude'];
                    _longitudeController.text = selectedData['longitude'];
                  });
                }
              },
              child: AbsorbPointer(
                child: Container(
                  color: Colors.white,
                  child: addressfiled(
                    inputFormatter: const [], // Pass an empty list for no formatting
                    onSubmitted: (value) {
                      // Handle submission if needed
                    },
                    controller: _addressController,
                    focusNode: _addressFocusNode,
                    keyboard: TextInputType.text,
                    obscure: false,
                    textInputAction: TextInputAction.next,
                    label: 'Address',
                    enabled:
                        false, // Ensures the field can't be edited directly
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16.0),

            Container(
              decoration: BoxDecoration(
                color: Colors.white, // Set the background color to white
                border: Border.all(
                  color:Colors.grey,
                  width: 0.5, // Adjust the width as needed
                ),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0,right: 8.0,left: 8.0,top: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parkingEntries.isEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              color: Colors.white,
                              child: GestureDetector(
                                onTap: () => _showParkingModalSheet(context),
                                child: AbsorbPointer( // Prevents TextFormField from being interactive
                                  child: TextFormField(
                                    readOnly: true, // Ensures keyboard doesn't open
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        // fontWeight: FontWeight.bold,
                                      ),
                                      hintStyle: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                      labelText: 'Parking type',
                                      hintText: 'Parking type',
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 5.0, horizontal: 10.0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color:      ColorUtils.primarycolor(), ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color:      ColorUtils.primarycolor(), width: 0.5),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color:      ColorUtils.primarycolor(),  width: 0.5),
                                      ),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    onChanged: (value) {
                                      // Handle input change
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 40,
                              color: Colors.white,
                              child: GestureDetector(
                                onTap: () => _showParkingModalSheet(context), // Function to open modal
                                child: AbsorbPointer( // Prevents TextFormField from being interactive
                                  child: TextFormField(
                                    readOnly: true,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        // fontWeight: FontWeight.bold,
                                      ),
                                      hintStyle: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                      labelText: 'No of Parking',
                                      hintText: 'No of Parking',
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 5.0, horizontal: 10.0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color:      ColorUtils.primarycolor(), ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color:      ColorUtils.primarycolor(),width: 0.5),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5.0),
                                        borderSide:  BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                      ),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          ),


                        ],
                      )
                    else
                      Column(
                        children: [
                          ...parkingEntries.map((entry) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 40,
                                        color: Colors.white,
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Parking Type',
                                            labelStyle: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            hintStyle: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                                vertical: 5.0, horizontal: 10.0),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color: ColorUtils.primarycolor(),) ,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color:ColorUtils.primarycolor(), width: 0.5),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color: ColorUtils.primarycolor(),  width: 0.5),
                                            ),
                                          ),
                                          value: entry['type'],
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              entry['type'] = newValue!;
                                            });
                                          },
                                          items: parkingTypes
                                              .map((String item) {
                                            return DropdownMenuItem<String>(
                                              value: item,
                                              child: Text(item),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        height: 40,
                                        color: Colors.white,
                                        child: TextFormField(
                                          initialValue: entry['count'],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelStyle: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            hintStyle: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                            labelText: 'No of Parking',
                                            contentPadding: const EdgeInsets.symmetric(
                                                vertical: 5.0, horizontal: 10.0),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color: ColorUtils.primarycolor(), ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color:ColorUtils.primarycolor(), width: 0.5),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(5.0),
                                              borderSide:  BorderSide(color: ColorUtils.primarycolor(),  width: 0.5),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              entry['count'] = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5), // Add spacing between rows
                              ],
                            );
                          }),
                        ],
                      ),


                    Row(
                      mainAxisAlignment: parkingEntries.isEmpty ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                      children: [
                        if (parkingEntries.isNotEmpty)
                          GestureDetector(
                            onTap: _removeParkingField,

                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.delete,
                                  size: 16, // Slightly smaller icon
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 2), // Reduced space between icon and text
                                Text(
                                  "Delete",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, // Slightly smaller font size
                                    color: ColorUtils.primarycolor(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.only(right: 5.0),
                          child: GestureDetector(
                            onTap: () => _showParkingModalSheet(context),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add_circle,
                                  size: 16, // Slightly smaller icon
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 2), // Reduced space between icon and text
                                Text(
                                  "Add More",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, // Slightly smaller font size
                                    color: ColorUtils.primarycolor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),


                    // const SizedBox(height: 20),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Align(
              alignment: Alignment.center,
              child: Text(
                "Upload Place Image",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            Center(
              child: GestureDetector(
                onTap: _pickImage, // No need to pass context here
                child: SizedBox(
                  height: 120,
                  width: 140,
                  child: _bannerPicture == null
                      ? SvgPicture.asset('assets/svg/vendorbanner.svg',
                          fit: BoxFit.contain)
                      : Image.file(File(_bannerPicture!.path),
                          fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            // Row(
            //   children: [
            //     Expanded(
            //       child: Padding(
            //         padding: const EdgeInsets.all(0.0),
            //         child: CustomTextField(
            //           focusNode: _passwordFocusNode,
            //           inputFormatter: const [],
            //           controller: passwordController,
            //           keyboard: TextInputType.text,
            //           obscure: !_isPasswordVisible, // Use this field's variable
            //           suffix: IconButton(
            //             icon: Icon(
            //               _isPasswordVisible
            //                   ? Icons.visibility
            //                   : Icons.visibility_off,
            //               size: 14,
            //             ),
            //             onPressed: () {
            //               setState(() {
            //                 _isPasswordVisible = !_isPasswordVisible;
            //               });
            //             },
            //           ),
            //           textInputAction: TextInputAction.next,
            //           label: 'Password',
            //           hint: 'Enter your password',
            //         ),
            //       ),
            //     ),
            //     const SizedBox(
            //       width: 5,
            //     ),
            //     Expanded(
            //       child: CustomTextField(
            //         focusNode: _confirmpasswordFocusNode,
            //         inputFormatter: const [],
            //         controller: confirmPasswordController,
            //         keyboard: TextInputType.text,
            //         obscure:
            //         !_isConfirmPasswordVisible, // Use this field's variable
            //         suffix: IconButton(
            //           icon: Icon(
            //             _isConfirmPasswordVisible
            //                 ? Icons.visibility
            //                 : Icons.visibility_off,
            //             size: 14,
            //           ),
            //           onPressed: () {
            //             setState(() {
            //               _isConfirmPasswordVisible =
            //               !_isConfirmPasswordVisible;
            //             });
            //           },
            //         ),
            //         textInputAction: TextInputAction.done,
            //         label: 'Confirm Password',
            //         hint: 'Re-enter your password',
            //       ),
            //     ),
            //   ],
            // ),
            Row(
              children: [
                Checkbox(
                  value: isChecked,
                  activeColor:
                      ColorUtils.primarycolor(), // Set the tick color to green
                  onChanged: (bool? value) {
                    setState(() {
                      isChecked = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: "I agree to the ",
                      style: GoogleFonts.poppins(
                          fontSize: 15.0, color: Colors.black),
                      children: [
                        TextSpan(
                          text: "terms and conditions",
                          style: GoogleFonts.poppins(
                            fontSize: 15.0,
                            color: ColorUtils.primarycolor(),
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VendorPrivacy(
                                    // Your privacy policy URL
                                  ),
                                ),
                              );
                            },
                        ),
                        TextSpan(
                          text: ".",
                          style: GoogleFonts.poppins(
                              fontSize: 16.0, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Align(
              alignment: Alignment.topRight,
              child: ElevatedButton(
                onPressed: isLoading ? null : _registerVendor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : Row(
                        mainAxisSize:
                            MainAxisSize.min, // Keeps button size minimal
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 18), // Vendor icon
                          const SizedBox(
                              width: 5), // Spacing between icon and text
                          Text(
                            'Register Space',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold, // Bold text
                              fontSize: 14, // Adjust font size if needed
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16.0),

            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose of the controllers that you have created
    _vendorController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vendorFocusNode.dispose();
    _addressFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    // Dispose of all TextEditingControllers in contacts
    for (var entry in contacts) {
      entry['name']?.dispose();
      entry['mobile']?.dispose();
    }

    super.dispose();
  }
}
