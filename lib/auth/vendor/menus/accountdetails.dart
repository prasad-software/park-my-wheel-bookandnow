import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/pageloader.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';  // For MediaType
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';


  class AccountDetails extends StatefulWidget {
  final String vendorid;
  const AccountDetails({super.key,
  required this.vendorid,
  });
  @override
  _AccountDetailsState createState() => _AccountDetailsState();
  }

  class _AccountDetailsState extends State<AccountDetails> {
  bool _isLoading = false;
  final bool _hasUploadedDocuments = false;


  final TextEditingController _accountnumber = TextEditingController();
  final TextEditingController _confirmaccountnumber = TextEditingController();
  final TextEditingController _accountholdername = TextEditingController();
  final TextEditingController _ifsccode = TextEditingController();


  final FocusNode _accountnumberFocusNode = FocusNode();
  final FocusNode _confirmaccountFocusNode = FocusNode();
  final FocusNode _accountholdernameFocusNode = FocusNode();
  final FocusNode _ifsccodeFocusNode = FocusNode();

  XFile? _bankPassbookPicture;
  String? _bankPassbookImageUrl;

  @override
  void initState() {
  super.initState();
  _fetchExistingData();
  }

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Space evenly between items
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.camera, size: 30), // Adjust size as needed
                      SizedBox(height: 8), // Space between icon and text
                      Text('Camera'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.photo, size: 30), // Adjust size as needed
                      SizedBox(height: 8), // Space between icon and text
                      Text('Gallery'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _bankPassbookPicture = pickedFile;
        print('Picked Bank Passbook Image: ${_bankPassbookPicture!.path}'); // Debugging line
      });
    } else {
      print('No image selected'); // Debugging line
    }
  }

  Future<void> _updatedata() async {
    // Check if required fields are not null and not empty
    if (_accountnumber.text.isEmpty || _ifsccode.text.isEmpty || _accountholdername.text.isEmpty || _confirmaccountnumber.text.isEmpty) {
      print('Validation Failed: Missing required fields.');
      return;
    }
    if (_accountnumber.text != _confirmaccountnumber.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account Number and Confirm Account Number doesnt  match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/bankdetails'); // Use the update endpoint
      print('API URL: $uri');

      var request = http.MultipartRequest('POST', uri); // Use POST for creating/updating

      // Add the form fields to the request
      request.fields['vendorId'] = widget.vendorid; // Ensure widget.vendorid has the correct vendor ID
      request.fields['accountnumber'] = _accountnumber.text;
      request.fields['confirmaccountnumber'] = _confirmaccountnumber.text;
      request.fields['accountholdername'] = _accountholdername.text;
      request.fields['ifsccode'] = _ifsccode.text;

      // Upload Bank Passbook image if a new one is selected
      if (_bankPassbookPicture != null) {
        print('Uploading Bank Passbook Image: ${_bankPassbookPicture!.path}');
        var bankPassbookImage = await http.MultipartFile.fromPath(
          'bankpassbookimage',
          _bankPassbookPicture!.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(bankPassbookImage);
      }

      // Print the request fields before sending
      print('Sending Data:');
      print('vendorId: ${widget.vendorid}');
      print('accountnumber: ${_accountnumber.text}');
      print('confirmaccountnumber: ${_confirmaccountnumber.text}');
      print('accountholdername: ${_accountholdername.text}');
      print('ifsccode: ${_ifsccode.text}');

      var response = await request.send();

      print('Response Status: ${response.statusCode}');
      var responseBody = await response.stream.bytesToString();
      print('Response Body: $responseBody');

      // Check the response status
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successful response (either update or create)
        var responseData = jsonDecode(responseBody);

        // Check if it's an update or create
        if (responseData['message'] == 'Bank detail updated successfully') {
          print('KYC Update Successful');
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: const Text('Bank details updated successfully!'),
              backgroundColor: ColorUtils.primarycolor(),
            ),
          );
        } else if (responseData['message'] == 'Bank detail created successfully') {
          print('KYC Create Successful');
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: const Text('Bank details created successfully!'),
              backgroundColor:ColorUtils.primarycolor(),
            ),
          );
        }
      } else {
        // If the status is not 200 or 201, something went wrong
        print('Error: $responseBody');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update/create bank details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchExistingData() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/getBankDetails/${widget.vendorid}');
      print('Fetching data from: $uri'); // Log the API endpoint being used
      var response = await http.get(uri);

      // Log the response status code and body for debugging
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        if (jsonResponse is Map<String, dynamic> && jsonResponse['data'] != null) {
          List<dynamic> dataList = jsonResponse['data'];

          if (dataList.isNotEmpty) {
            var data = dataList[0]; // Access the first object in the array

            // Log the data fetched from the API to ensure it's correct
            print('Fetched Data: $data');

            setState(() {
              _accountnumber.text = data['accountnumber'] ?? '';
              _confirmaccountnumber.text = data['confirmaccountnumber'] ?? '';
              _ifsccode.text = data['ifsccode'] ?? '';
              _accountholdername.text = data['accountholdername'] ?? '';
              _bankPassbookImageUrl = data['bankpassbookimage']; // Get the bank passbook image URL
            });
          } else {
            print('No data found in the response.');
          }
        } else {
          print('Invalid JSON response format.');
        }
      } else {
        print('Failed to fetch data. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching existing data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(backgroundColor: Colors.white,
  appBar: AppBar( titleSpacing: 0,
  backgroundColor: ColorUtils.secondarycolor(),
  title:  Text(
  'Bank Details',
  style:   GoogleFonts.poppins(color: Colors.black,fontSize: 16),
  ),
  iconTheme: const IconThemeData(
  color: Colors.black, // Set the color of the back icon to white
  ),
  actions: const [

  ],
  ),

  body: SafeArea(
    child: _isLoading
        ? const LoadingGif()
        : SingleChildScrollView(
      child: Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
Center(
  child: Container(
    child:  Text("Enter Bank Account Details",style:   GoogleFonts.poppins(fontWeight: FontWeight.bold),),
  ),
),
    Center(
      child: Container(
        child: const Text("Your Payout will be transferred to this account"),
      ),
    ),
  Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  const SizedBox(height: 16),

  CustomTextField(
  controller: _accountnumber,
  focusNode: _accountnumberFocusNode,
  label: 'Account Number',
  hint: "Enter Your Account Number",
  keyboard: TextInputType.number,
  obscure: false,
  // validator: (value) {
  //   if (value == null || value.isEmpty) {
  //     return 'Please enter your Id proof number';
  //   }
  //   return null;
  // },
  textInputAction: TextInputAction.next,
  inputFormatter: const [],
  onSubmitted: (value) {},
  ),
  const SizedBox(height: 16),

    CustomTextField(
      controller: _confirmaccountnumber,
      focusNode: _confirmaccountFocusNode,
      label: 'Confirm Account Number',
      hint: "Enter Your Confirm Account Number",
      keyboard: TextInputType.number,
      obscure: false,
      // validator: (value) {
      //   if (value == null || value.isEmpty) {
      //     return 'Please enter your Id proof number';
      //   }
      //   return null;
      // },
      textInputAction: TextInputAction.next,
      inputFormatter: const [],
      onSubmitted: (value) {},
    ),

  ],
  ),
  const SizedBox(height: 16),
    CustomTextField(
      focusNode: _accountholdernameFocusNode,
      controller: _accountholdername,
      label: 'Account Holder Number',
      hint: 'Enter your Account Holder Number',
      keyboard: TextInputType.text,
      obscure: false,
      // validator: (value) {
      //   if (value == null || value.isEmpty) {
      //     return 'Please enter your Address proof number';
      //   }
      //   return null;
      // },
      textInputAction: TextInputAction.next,
      inputFormatter: const [],
      onSubmitted: (value) {},
    ),
  const SizedBox(height: 16),
  CustomTextField(
  focusNode: _ifsccodeFocusNode,
  controller: _ifsccode,
  label: 'Ifsc Code',
  hint: 'Enter your Ifsc Code',
  keyboard: TextInputType.text,
  obscure: false,
  // validator: (value) {
  //   if (value == null || value.isEmpty) {
  //     return 'Please enter your Address proof number';
  //   }
  //   return null;
  // },
  textInputAction: TextInputAction.next,
  inputFormatter: const [],
  onSubmitted: (value) {},
  ),
  const SizedBox(height: 16),
  const Text('Bank Account Proof'),
  Center(
    child: GestureDetector(
      onTap: () => _showImageSourceOptions(),
      child: Container(
        height: 150,
        color: Colors.white,
        child: _bankPassbookPicture == null && _bankPassbookImageUrl != null
            ? Image.network(_bankPassbookImageUrl!, fit: BoxFit.contain) // Display the existing image
            : _bankPassbookPicture != null
            ? Image.file(File(_bankPassbookPicture!.path), fit: BoxFit.contain) // Display the newly picked image
            : SvgPicture.asset('assets/image.svg', height: 150), // Placeholder
      ),
    ),
  ),
  const SizedBox(height: 16),


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
    child: _isLoading
    ? const Center(child: CircularProgressIndicator()) // Show loading indicator
        : ElevatedButton.icon(
    onPressed: _hasUploadedDocuments ? _updatedata : _updatedata, // Disable button if loading
    icon: const Icon(Icons.upload,color: Colors.white,),
    label: Text(_hasUploadedDocuments ? "Update" : "Submit"),
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
  ),  );
  }
  }
