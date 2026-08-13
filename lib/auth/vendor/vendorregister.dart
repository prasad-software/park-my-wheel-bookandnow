import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mywheels/config/authconfig.dart';

import 'package:mywheels/auth/vendor/map.dart';
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/privacypolicydataprivacy.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../config/colorcode.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../customer/splashregister/register.dart';

class VendorRegister extends StatefulWidget {
  const VendorRegister({super.key});

  @override
  _VendorRegisterState createState() => _VendorRegisterState();
}

class _VendorRegisterState extends State<VendorRegister> {
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

  bool isChecked = false;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController noofparking = TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmpasswordFocusNode = FocusNode();
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
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
      return "Please enter vendor name";
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
    } else if (passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      return "Please enter both password and confirm password";
    } else if (passwordController.text != confirmPasswordController.text) {
      return "Passwords do not match";
    }
    return null; // All validations passed
  }

  Future<void> _pickImage() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('Take Photo', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      // Check permissions for iOS
      if (Platform.isIOS) {
        if (source == ImageSource.camera) {
          final status = await Permission.camera.request();
          if (!status.isGranted) return;
        } else {
          final status = await Permission.photos.request();
          if (!status.isGranted) return;
        }
      }

      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        // Compress the image
        final compressedFile = await _compressImage(File(pickedFile.path));

        setState(() {
          _bannerPicture = XFile(compressedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<File> _compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.absolute.path}_compressed.jpg', // Output file path
      quality: 85, // Quality (0-100)
      minWidth: 1024, // Optional: set max width
      minHeight: 1024, // Optional: set max height
    );

    // Check if compression was successful
    if (result != null) {
      final compressedFile = File(result.path);
      final length = await compressedFile.length();

      // If still larger than 2MB, compress further
      if (length > 2000000) { // 2MB in bytes
        return await _compressImage(compressedFile);
      }

      return compressedFile;
    } else {
      throw Exception('Image compression failed');
    }
  }
  void _addContactField() {
    contacts.add({
      'name': TextEditingController(),
      'mobile': TextEditingController(),
    });
    setState(() {});
  }

  void _removeLastContactField() {
    if (contacts.isNotEmpty) {
      contacts.removeLast();
      setState(() {});
    }
  }

  Future<void> _registerVendor() async {
    print('Starting vendor registration...'); // Debug print
    setState(() => isLoading = true);

    // Validate vendor name
    if (_vendorController.text.isEmpty) {
      print('Validation failed: Vendor name empty'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the vendor name")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Validate contacts
    List<Map<String, String>> contactsList = contacts
        .map((contact) {
      return {
        'name': contact['name']?.text ?? '',
        'mobile': contact['mobile']?.text ?? '',
      };
    })
        .where((contact) =>
    contact['name']!.isNotEmpty && contact['mobile']!.isNotEmpty)
        .toList();

    if (contactsList.isEmpty) {
      print('Validation failed: No valid contacts'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one valid contact with name and mobile.")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Validate address
    if (_addressController.text.isEmpty) {
      print('Validation failed: Address empty'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select the Address")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Validate parking entries
    if (parkingEntries.isEmpty) {
      print('Validation failed: No parking entries'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select parking type and no of parking")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Validate banner picture
    if (_bannerPicture == null) {
      print('Validation failed: No banner picture'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a vendor banner")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Validate passwords
    if (passwordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
      print('Validation failed: Password fields empty'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both password and confirm password")),
      );
      setState(() => isLoading = false);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      print('Validation failed: Passwords don\'t match'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      setState(() => isLoading = false);
      return;
    }

    if (!isChecked) {
      print('Validation failed: Terms not accepted'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the terms and conditions.")),
      );
      setState(() => isLoading = false);
      return;
    }

    // Prepare the request
    try {
      print('Preparing request data...'); // Debug print
      print('Vendor Name: ${_vendorController.text}');
      print('Address: ${_addressController.text}');
      print('Landmark: ${_landmarkController.text}');
      print('Latitude: ${_latitudeController.text}');
      print('Longitude: ${_longitudeController.text}');
      print('Contacts: ${jsonEncode(contactsList)}');
      print('Parking Entries: ${jsonEncode(parkingEntries)}');
      print('Banner Picture Path: ${_bannerPicture!.path}');
      print('Banner Picture Size: ${File(_bannerPicture!.path).lengthSync()} bytes');

      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}vendor/signup'));
      print('API URL: ${request.url}'); // Debug print

      request.fields['vendorName'] = _vendorController.text;
      request.fields['address'] = _addressController.text;
      request.fields['landmark'] = _landmarkController.text;
      request.fields['latitude'] = _latitudeController.text;
      request.fields['longitude'] = _longitudeController.text;
      request.fields['password'] = passwordController.text;
      request.fields['contacts'] = jsonEncode(contactsList);
      request.fields['parkingEntries'] = jsonEncode(parkingEntries.isNotEmpty ? parkingEntries : []);

      print('Adding image file...'); // Debug print
      request.files.add(await http.MultipartFile.fromPath(
          'image',
          _bannerPicture!.path
      ));

      print('Sending request...'); // Debug print
      var response = await request.send();
      print('Request sent, status code: ${response.statusCode}'); // Debug print

      final responseBody = await response.stream.bytesToString();
      print('Response body: $responseBody'); // Debug print

      if (response.statusCode == 201) {
        var responseData = json.decode(responseBody);
        String message = responseData['message'] ?? '';
        print('Registration successful: $message'); // Debug print
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const splashlogin()),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } else {
        var responseData = json.decode(responseBody);
        String message = responseData['message'] ?? 'Something went wrong';
        print('Registration failed: $message'); // Debug print
        print('Status code: ${response.statusCode}'); // Debug print
        print('Response: $responseData'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e, stackTrace) {
      print('Error occurred during registration:'); // Debug print
      print('Error: $e'); // Debug print
      print('Stack trace: $stackTrace'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending data')),
      );
    } finally {
      print('Registration process completed'); // Debug print
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

    return  isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text(
          'New Vendor Registration',
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Primary color for icons
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Column(
            children: [
            Padding(
              padding: const EdgeInsets.only(left: 25.0, right: 25.0, top: 0),
              child: SizedBox(
                height: 70,
                child: Image.asset("assets/login.png"),
              ),
            ), // Use a suitable image asset
            const SizedBox(height: 16.0),
            CustomTextField(
              inputFormatter: const [],
              controller: _vendorController,
              focusNode: _vendorFocusNode,
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              label: 'Vendor Name',
              hint: 'Enter your Vendor name',
              onSubmitted: (value) =>
                  FocusScope.of(context).requestFocus(_vendorFocusNode),
            ),

            const SizedBox(height: 16.0),

            // const SizedBox(height: 2.0),
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
                  children: [
                    ...contacts.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, TextEditingController> contact = entry.value;

                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              height: 40,
                              margin: const EdgeInsets.only(right: 2, bottom: 5),
                              child: TextFormField(
                                controller: contact['name'],
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  hintText: 'Contact Person',
                                  labelText: 'Contact Person',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                  hintStyle: GoogleFonts.poppins(
                                    color: ColorUtils.primarycolor(),
                                    fontSize: 11,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 5.0, horizontal: 10.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:  BorderSide(color: ColorUtils.primarycolor(),),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:
                                     BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:
                                     BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                  ),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Expanded(
                            child: Container(
                              color: Colors.white,
                              height: 40,
                              margin: const EdgeInsets.only(right: 2, bottom: 5),
                              child: TextFormField(
                                controller: contact['mobile'],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Contact Number',
                                  labelText: 'Contact Number',
                                  labelStyle: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    // fontWeight: FontWeight.bold,
                                  ),
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 5.0, horizontal: 10.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:  BorderSide(color: ColorUtils.primarycolor(),),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:
                                     BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                    borderSide:
                                     BorderSide(color:ColorUtils.primarycolor(),width: 0.5),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a contact number';
                                  }
                                  if (value.length != 10) {
                                    return 'Please enter a valid 10-digit number';
                                  }
                                  return null;
                                },
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 1.5),
                        ],
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _removeLastContactField,
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(5),
                                bottomRight: Radius.circular(5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete, size: 18, color: Colors.black),
                                const SizedBox(width: 4),
                                Text(
                                  "Delete",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: ColorUtils.primarycolor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 5.0),
                          child: GestureDetector(
                            onTap: _addContactField,
                            child: Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(5),
                                  bottomRight: Radius.circular(5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_circle_rounded,
                                      size: 18, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Add More",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: ColorUtils.primarycolor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
const SizedBox(height: 16,),
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
                  enabled: false, // Ensures the field can't be edited directly
                ),
              ),
            ),






            const SizedBox(height: 16.0),
            Align(
              alignment: Alignment.center,
              child: Text(
                "Upload Vendor Banner",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: SizedBox(
                  height: 120,
                  width: 140,
                  // color: Colors.white,
                  child: _bannerPicture == null
                      ? SvgPicture.asset('assets/svg/vendorbanner.svg',
                      fit: BoxFit.contain)
                      : Image.file(File(_bannerPicture!.path),
                      fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: CustomTextField(
                      focusNode: _passwordFocusNode,
                      inputFormatter: const [],
                      controller: passwordController,
                      keyboard: TextInputType.text,
                      obscure: !_isPasswordVisible, // Use this field's variable
                      suffix: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 14,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      textInputAction: TextInputAction.next,
                      label: 'Password',
                      hint: 'Enter your password',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Expanded(
                  child: CustomTextField(
                    focusNode: _confirmpasswordFocusNode,
                    inputFormatter: const [],
                    controller: confirmPasswordController,
                    keyboard: TextInputType.text,
                    obscure:
                    !_isConfirmPasswordVisible, // Use this field's variable
                    suffix: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 14,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    textInputAction: TextInputAction.done,
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                  ),
                ),
              ],
            ),
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
                          style:GoogleFonts.poppins(fontSize: 16.0, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // const SizedBox(height: 18),
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
                      'Register Vendor',
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
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_business, // You can change this icon
                      size: 18, // Adjust the size as needed
                      color: Colors.black,
                    ),
                    const SizedBox(width: 0),
                    Text(
                      ' Already have an Account? Login here',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ColorUtils.primarycolor(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),            const SizedBox(height: 16.0),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
      ),  );
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