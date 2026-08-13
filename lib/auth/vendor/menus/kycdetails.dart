import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import '../../customer/splashregister/register.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';  // For MediaType



class NextPage extends StatefulWidget {
  final String vendorid;
  const NextPage({super.key,
    required this.vendorid,
  });
  @override
  _NextPageState createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  bool _isLoading = false;
  bool _hasUploadedDocuments = false;
  final List<String> _idProofs = [
    'Passport',
    'Driving License',
    'Phone Bill',
    'Ration Card',
    'Pancard',
    'Latest Bank Statement',
    'Aadhar Card',
    'Bank Passbook Photo',
    'Others'
  ];

  final List<String> _addressProofs = [
    'Driving License',
    'Passport',
    'Ration Card',
    'Aadhar Card'
  ];
  String? _idProofImageUrl;
  String? _addressProofImageUrl;
  String? _idProof;
  String? _addressProof;
  final TextEditingController _idProofNumberController = TextEditingController();
  final TextEditingController _addressProofNumberController = TextEditingController();
  final FocusNode _idProofNumberFocusNode = FocusNode();

  final FocusNode _addressProofNumberFocusNode = FocusNode();
  XFile? _idProofPicture;
  XFile? _addressProofPicture;
  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }
  Future<void> _showImageSourceOptions(bool isIdProof) async {
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
                    _pickImage(ImageSource.camera, isIdProof);
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
                    _pickImage(ImageSource.gallery, isIdProof);
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

  Future<void> _updatedata() async {
    // Check if required fields are not null and not empty
    if (_idProof == null || _addressProof == null || _idProofNumberController.text.isEmpty || _addressProofNumberController.text.isEmpty) {
      print('Validation Failed: Missing required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    try {
      // Determine the API endpoint based on whether we are updating or creating
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/updatekyc/${widget.vendorid}'); // Use the update endpoint

      // Print the URL to ensure correct API endpoint
      print('API URL: $uri');

      var request = http.MultipartRequest('PUT', uri); // Use PUT for updating

      // Add the form fields to the request
      request.fields['vendorId'] = widget.vendorid;
      request.fields['idProof'] = _idProof ?? '';
      request.fields['addressProof'] = _addressProof ?? '';
      request.fields['idProofNumber'] = _idProofNumberController.text;
      request.fields['addressProofNumber'] = _addressProofNumberController.text;
      request.fields['status'] = "Not Verified"; // or "Updated" based on your logic

      // Print form fields to verify the data
      print('Form Data: vendorId=${widget.vendorid}, idProof=$_idProof, addressProof=$_addressProof, idProofNumber=${_idProofNumberController.text}, addressProofNumber=${_addressProofNumberController.text}');

      // Upload ID proof image if a new one is selected
      if (_idProofPicture != null) {
        print('Uploading ID Proof Image: ${_idProofPicture!.path}');
        var idProofImage = await http.MultipartFile.fromPath(
          'idProofImage',
          _idProofPicture!.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(idProofImage);
      }

      // Upload Address proof image if a new one is selected
      if (_addressProofPicture != null) {
        print('Uploading Address Proof Image: ${_addressProofPicture!.path}');
        var addressProofImage = await http.MultipartFile.fromPath(
          'addressProofImage',
          _addressProofPicture!.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(addressProofImage);
      }

      // Send the request and get the response
      var response = await request.send();

      // Print the response status and body for debugging
      print('Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        print('Response Body: $responseBody');
        print('KYC Update Successful');
        // Optionally, show a success message or navigate back
      } else {
        var responseBody = await response.stream.bytesToString();
        print('Update Failed. Status Code: ${response.statusCode}, Response Body: $responseBody');
        // Optionally, show an error message
      }
    } catch (e) {
      print('Error: $e');
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
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/getkyc/${widget.vendorid}');
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        var data = jsonResponse['data'];

        setState(() {
          _idProof = data['idProof'];
          _addressProof = data['addressProof'];
          _idProofNumberController.text = data['idProofNumber'] ?? '';
          _addressProofNumberController.text = data['addressProofNumber'] ?? '';
          _idProofImageUrl = data['idProofImage']; // Get the ID proof image URL
          _addressProofImageUrl = data['addressProofImage']; // Get the address proof image URL
          _hasUploadedDocuments = _idProof != null && _addressProof != null;
        });
      }
    } catch (e) {
      print('Error fetching existing data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
  Future<void> _pickImage(ImageSource source, bool isIdProof) async {
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      if (isIdProof) {
        _idProofPicture = pickedFile;
        print('Picked ID Proof Image: ${_idProofPicture!.path}'); // Debugging line
      } else {
        _addressProofPicture = pickedFile;
        print('Picked Address Proof Image: ${_addressProofPicture!.path}'); // Debugging line
      }
    } else {
      print('No image selected'); // Debugging line
    }
    setState(() {});
  }
  Future<void> _submitData() async {
    // Check if required fields are not null and not empty
    if (_idProof == null || _addressProof == null || _idProofNumberController.text.isEmpty || _addressProofNumberController.text.isEmpty) {
      // Print out a message to check why validation fails
      print('Validation Failed: Missing required fields.');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}vendor/createkyc'); // Replace with your API endpoint

      // Print the URL to ensure correct API endpoint
      print('API URL: $uri');

      var request = http.MultipartRequest('POST', uri);

      // Add the form fields to the request
      request.fields['vendorId'] = widget.vendorid;
      request.fields['idProof'] = _idProof ?? '';
      request.fields['addressProof'] = _addressProof ?? '';
      request.fields['idProofNumber'] = _idProofNumberController.text;
      request.fields['addressProofNumber'] = _addressProofNumberController.text;
      request.fields['status'] = "Not Verified";

      // Print form fields to verify the data
      print('Form Data: vendorId=${widget.vendorid}, idProof=$_idProof, addressProof=$_addressProof, idProofNumber=${_idProofNumberController.text}, addressProofNumber=${_addressProofNumberController.text}');

      // Upload ID proof image
      if (_idProofPicture != null) {
        // Print file path to ensure the image is being found
        print('Uploading ID Proof Image: ${_idProofPicture!.path}');

        var idProofImage = await http.MultipartFile.fromPath(
          'idProofImage',
          _idProofPicture!.path,
          contentType: MediaType('image', 'jpeg'),  // Set to 'image/jpeg' by default
        );
        request.files.add(idProofImage);
      }

      // Upload Address proof image
      if (_addressProofPicture != null) {
        // Print file path to ensure the image is being found
        print('Uploading Address Proof Image: ${_addressProofPicture!.path}');

        var addressProofImage = await http.MultipartFile.fromPath(
          'addressProofImage',
          _addressProofPicture!.path,
          contentType: MediaType('image', 'jpeg'),  // Set to 'image/jpeg' by default
        );
        request.files.add(addressProofImage);
      }

      // Send the request and get the response
      var response = await request.send();

      // Print the response status and body for debugging
      print('Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        // Read and print response body for further debugging
        var responseBody = await response.stream.bytesToString();
        print('Response Body: $responseBody');

        // Success - Handle the response
        print('Upload Successful');
        setState(() {
          _isLoading = false;
        });
      } else {
        // Print error response body if status code is not 200
        var responseBody = await response.stream.bytesToString();
        print('Upload Failed. Status Code: ${response.statusCode}, Response Body: $responseBody');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Print the error to check what went wrong
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(backgroundColor: Colors.white,
      appBar: AppBar( titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(
          'Upload Documents',
          style:   GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
        actions: const [

        ],
      ),

      body: _isLoading
          ? const LoadingGif() // Show loading GIF before the Scaffold
          :SafeArea(
            child: SingleChildScrollView(
                    child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Stack(
            children: [
            Positioned(
            child: DropdownButtonFormField<String>(
              value: _idProof,
              decoration: InputDecoration(
                labelText: 'Owner KYC',
                labelStyle:   GoogleFonts.poppins(color: Colors.black),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 1),
                ),
              ),
              dropdownColor: Colors.white,
              items: _idProofs
                  .map((idProof) => DropdownMenuItem(
                value: idProof,
                child: Text(idProof),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _idProof = value),
              validator: (value) => value == null ? 'Please select Owner KYC' : null,
            ),
                    ),
                    ],
                  ),
            
                    if (_idProof != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _idProofNumberController,
                        focusNode: _idProofNumberFocusNode,
                        label: 'ID Proof Number',
                        hint: "Enter Your ID Proof Number",
                        keyboard: TextInputType.text,
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
            
                      const Text('ID Proof Picture'),
                      Center(
                        child: GestureDetector(
                          onTap: () => _showImageSourceOptions(true),
                          child: Container(
                            height: 150,
                            color: Colors.white,
                            child: _idProofPicture == null && _idProofImageUrl != null
                                ? Image.network(_idProofImageUrl!, fit: BoxFit.contain) // Display the existing image
                                : _idProofPicture != null
                                ? Image.file(File(_idProofPicture!.path), fit: BoxFit.contain) // Display the newly picked image
                                : SvgPicture.asset('assets/image.svg', height: 150), // Placeholder
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Positioned(
                      child: DropdownButtonFormField<String>(
                        value: _addressProof,
                        decoration: InputDecoration(
                          labelText: 'Choose Business Docs',
                          labelStyle:  GoogleFonts.poppins(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 2),
                          ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 1),
                          ),
                        ),
                        items: _addressProofs.map((String addressProof) {
                          return DropdownMenuItem<String>(
                            value: addressProof,
                            child: Text(
                              addressProof,
                              style:   GoogleFonts.poppins(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _addressProof = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select Business Docs' : null,
                        dropdownColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (_addressProof != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      CustomTextField(
                        focusNode: _addressProofNumberFocusNode,
                        controller: _addressProofNumberController,
                        label: 'Address Proof Number',
                        hint: 'Enter your Address Proof Number',
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
                      const Text('Address Proof Picture'),
                      Center(
                        child: GestureDetector(
                          onTap: () => _showImageSourceOptions(false),
                          child: Container(
                            height: 150,
                            color: Colors.white,
                            child: _addressProofPicture != null
                                ? Image.file(File(_addressProofPicture!.path), fit: BoxFit.contain) // Display the newly picked image
                                : _addressProofImageUrl != null
                                ? Image.network(_addressProofImageUrl!, fit: BoxFit.contain) // Display the existing image
                                : SvgPicture.asset('assets/image.svg', height: 150), // Placeholder
                            // Placeholder
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Container(
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
                    onPressed: _hasUploadedDocuments ? _updatedata : _submitData, // Disable button if loading
                    icon: const Icon(Icons.upload,color: Colors.white,),
                    label: Text(_hasUploadedDocuments ? "Update" : "Upload"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ],
            ),
                    ),
                  ),
          ),
    );
  }
}
