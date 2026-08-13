import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mywheels/config/authconfig.dart';

import 'package:http/http.dart' as http;

import '../../../config/colorcode.dart';
import 'mycars.dart';

class AddMyCar extends StatefulWidget {
  final String userId;





  const AddMyCar({super.key,

    required this.userId,

  });
  @override
  _AddMyCarState createState() => _AddMyCarState();
}

class _AddMyCarState extends State<AddMyCar> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final FocusNode _vehicleNumberFocusNode = FocusNode();
  final List<String> categories = [
    'Two-Wheeler',
    'Four-Wheeler',
    'Others',
  ];
  String? selectedCategory;
  XFile? _idProofPicture;
  bool _isLoading = false;
  // final ImagePicker _picker = ImagePicker();
  Future<void> _pickImage(ImageSource source, bool isIdProof) async {
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      // Compress the image
      File compressedFile = await _compressImage(File(pickedFile.path));

      setState(() {
        _idProofPicture = XFile(compressedFile.path);
        print('Compressed Image Path: ${_idProofPicture!.path}'); // Debugging line
      });
    } else {
      print('No image selected'); // Debugging line
    }
  }

  Future<File> _compressImage(File file) async {
    // Define a temporary path for the compressed image
    final String targetPath = '${file.path}_compressed.jpg';

    // Compress the image
    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70, // Adjust quality (0-100, lower means more compression)
      minWidth: 1024, // Optional: Set maximum width
      minHeight: 1024, // Optional: Set maximum height
      format: CompressFormat.jpeg, // Ensure consistent format
    );

    if (compressedXFile == null) {
      throw Exception('Image compression failed');
    }

    return File(compressedXFile.path);
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
                  child:  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera, size: 30), // Adjust size as needed
                      const SizedBox(height: 8), // Space between icon and text
                      Text(
                        'Camera',
                        style: GoogleFonts.poppins(fontSize: 14,),
                      ),

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
                  child:  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo, size: 30), // Adjust size as needed
                      const SizedBox(height: 8), // Space between icon and text
                      Text('Gallery',              style: GoogleFonts.poppins(fontSize: 14,),),
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

  void _addCar() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      String category = _categoryController.text;
      String make = _makeController.text;
      String model = _modelController.text;
      String color = _colorController.text;
      String vehicleNumber = _vehicleNumberController.text;

      // Validate all mandatory fields
      if (category.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Vehicle category.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // if (make.isEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Please enter the Vehicle make.')),
      //   );
      //   setState(() => _isLoading = false);
      //   return;
      // }
      //
      // if (model.isEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Please enter the Vehicle model.')),
      //   );
      //   setState(() => _isLoading = false);
      //   return;
      // }

      if (vehicleNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a vehicle number.')),
        );
        setState(() => _isLoading = false);
        return;
      }
      //
      // if (_idProofPicture == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Please select an image for the vehicle.')),
      //   );
      //   setState(() => _isLoading = false);
      //   return;
      // }

      // Unfocus the text field
      _vehicleNumberFocusNode.unfocus();

      // Set the type based on the selected category
      String type;
      if (selectedCategory == 'Two-Wheeler') {
        type = "Bike";
      } else if (selectedCategory == 'Four-Wheeler') {
        type = "Car";
      } else {
        type = "Others";
      }

      // Initialize the multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}add-vehicle?id=${widget.userId}'),
      );

      // Add form fields
      request.fields['category'] = category;
      request.fields['type'] = type;
      request.fields['make'] = make;
      request.fields['model'] = model;
      request.fields['color'] = color;
      request.fields['vehicleNo'] = vehicleNumber;

      // Add image file
      if (_idProofPicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _idProofPicture!.path),
        );
      }

      // Send the request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = {};
      try {
        responseJson = jsonDecode(responseData);
      } catch (e) {
        debugPrint('Error decoding response: $e');
      }

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle added successfully!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarPage(userId: widget.userId),
          ),
        );
        _categoryController.clear();
        _makeController.clear();
        _modelController.clear();
        _colorController.clear();
        _vehicleNumberController.clear();
        if (mounted) {
          setState(() {
            _idProofPicture = null;
          });
        }
      } else {
        String message = responseJson['message'] ?? responseData;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding vehicle: $e')),
      );
      debugPrint('Error in _addCar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title:Text('Add Vehicle',style: GoogleFonts.poppins(color: Colors.black),),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            // const SizedBox(height: 16.0),

            Container(color: Colors.white,
              height: 40, // Set your desired height
              child: DropdownButtonFormField<String>(
                value: selectedCategory,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCategory = newValue;
                    _categoryController.text = newValue ?? '';  // Update controller text
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'Select Vehicle category',
                  hintStyle: GoogleFonts.poppins(color: ColorUtils.primarycolor()),
                  labelStyle: GoogleFonts.poppins(color: ColorUtils.primarycolor()), // Set label color
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0), // Set padding
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5), // Set outline color
                    borderRadius: BorderRadius.circular(5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5), // Set focused border color
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.black), // Set the text style for the selected item
                items: categories.map<DropdownMenuItem<String>>((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      style: GoogleFonts.poppins(), // Set the text style for dropdown items
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16.0),
            CarField(
              controller: _typeController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Type',
              onSubmitted: (value) {},
              hint: 'Enter Vehicle type',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _makeController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Make',
              onSubmitted: (value) {},
              hint: 'Enter Vehicle make',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _modelController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Model',
              onSubmitted: (value) {},
              hint: 'Enter Vehicle model',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _colorController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Color',
              onSubmitted: (value) {},
              hint: 'Enter Vehicle color',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _vehicleNumberController,
              focusNode: _vehicleNumberFocusNode,
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: [UpperCaseTextInputFormatter()], // Apply the uppercase formatter
              label: 'Vehicle Number',
              onSubmitted: (value) {},
              hint: 'Enter vehicle number',
            ),
            const SizedBox(height: 16),
            Container(
              alignment: Alignment.centerLeft, // Aligns text to the left
              child:  Text(
                '  Upload Vehicle Picture',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, // Make the text bold
                  fontSize: 16, // Adjust the font size as needed
                ),
              ),
            ),

            GestureDetector(
              onTap: () => _showImageSourceOptions(true),
              child: SizedBox(
                height: 150,
                width: 140,
                // decoration: BoxDecoration(
                //   border: Border.all(color: ColorUtils.primarycolor(), width: 1),
                //   borderRadius: BorderRadius.circular(5),
                // ),
                child: _idProofPicture != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.file(
                    File(_idProofPicture!.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Center(
                        child: Text(
                          'Error loading image',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      );
                    },
                  ),
                )
                    : Center(
                  child: SvgPicture.asset(
                    'assets/svg/upload.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // ID Proof Picture

            // if (_idProofPicture != null) Image.file(File(_idProofPicture!.path)),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addCar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text('Add Vehicle', style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ),
          ],
        ),
        ), ),
    );
  }
  @override
  void dispose() {
    _categoryController.dispose();
    _typeController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }
}

class CarField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Function(String)? onSubmitted;
  final Widget? suffix;

  const CarField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: textInputAction,
        inputFormatters: inputFormatter,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14.0, // Input text font size (kept from previous adjustment)
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
              width: 0.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
              width: 0.5,
            ),
          ),
          labelStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 14.0, // Further reduced font size for label
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 14.0, // Further reduced font size for hint
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          suffixIcon: suffix,
        ),
        onFieldSubmitted: onSubmitted,
      ),
    );
  }
}



class EditMyCar extends StatefulWidget {
  final String userId;
  final String vehicleId; // Add vehicle ID for editing
  final String category;
  final String type;
  final String make;
  final String model;
  final String color;
  final String vehicleNumber;
  final String imagePath; // Path to the existing image

  const EditMyCar({
    super.key,
    required this.userId,
    required this.vehicleId,
    required this.category,
    required this.type,
    required this.make,
    required this.model,
    required this.color,
    required this.vehicleNumber,
    required this.imagePath,
  });

  @override
  _EditMyCarState createState() => _EditMyCarState();
}

class _EditMyCarState extends State<EditMyCar> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final FocusNode _vehicleNumberFocusNode = FocusNode();
  final List<String> categories = [
    'Two-Wheeler',
    'Four-Wheeler',
    'Others',
  ];
  String? selectedCategory;
  XFile? _idProofPicture;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing vehicle details
    _categoryController.text = widget.category;
    _typeController.text = widget.type;
    _makeController.text = widget.make;
    _modelController.text = widget.model;
    _colorController.text = widget.color;
    _vehicleNumberController.text = widget.vehicleNumber;
    selectedCategory = widget.category; // Set the selected category
  }

  Future<void> _pickImage(ImageSource source) async {
    XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _idProofPicture = pickedFile;
      });
    }
  }

  void _editCar() async {
    String category = _categoryController.text;
    String type = _typeController.text;
    String make = _makeController.text;
    String model = _modelController.text;
    String color = _colorController.text;
    String vehicleNumber = _vehicleNumberController.text;

    // Validate all fields
    if (category.isEmpty || type.isEmpty || make.isEmpty || model.isEmpty || color.isEmpty || vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    // Unfocus the text field to prevent blinking
    _vehicleNumberFocusNode.unfocus();

    try {
      // Initialize the multipart request
      var request = http.MultipartRequest(
        'PUT', // Use PUT for editing
        Uri.parse('${ApiConfig.baseUrl}edit-vehicle?id=${widget.userId}&vehicleId=${widget.vehicleId}'),
      );

      // Add form fields
      request.fields['category'] = category;
      request.fields['type'] = type;
      request.fields['make'] = make;
      request.fields['model'] = model;
      request.fields['color'] = color;
      request.fields['vehicleNo'] = vehicleNumber;

      // Add image file if selected
      if (_idProofPicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _idProofPicture!.path),
        );
      }

      // Send the request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated successfully!')),
        );
        Navigator.pop(context); // Go back to the previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update Vehicle: $responseData')),
        );
      }
    } catch (e) {
      // print('Error updating Vehicle: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Vehicle', style: TextStyle(color: Colors.white)),
        backgroundColor: ColorUtils.primarycolor(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue;
                  _categoryController.text = newValue ?? '';
                });
              },
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'Select Vehicle category',
                labelStyle: TextStyle(color: ColorUtils.primarycolor()),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              items: categories.map<DropdownMenuItem<String>>((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _typeController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Type',
              hint: 'Enter Vehicle type',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _makeController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Make',
              hint: 'Enter Vehicle make',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _modelController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Model',
              hint: 'Enter Vehicle model',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _colorController,
              focusNode: FocusNode(),
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Color',
              hint: 'Enter Vehicle color',
            ),
            const SizedBox(height: 16),
            CarField(
              controller: _vehicleNumberController,
              focusNode: _vehicleNumberFocusNode,
              keyboard: TextInputType.text,
              obscure: false,
              textInputAction: TextInputAction.next,
              inputFormatter: const [],
              label: 'Vehicle Number',
              hint: 'Enter vehicle number',
            ),
            const SizedBox(height: 16),
            Container(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Vehicle Picture',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                height: 150,
                width: 140,
                color: Colors.white,
                child: _idProofPicture != null
                    ? Image.file(File(_idProofPicture!.path), fit: BoxFit.contain)
                    : (widget.imagePath.isNotEmpty
                    ? Image.file(File(widget.imagePath), fit: BoxFit.contain) // Display existing image
                    : SvgPicture.asset('assets/svg/upload.svg', fit: BoxFit.contain)), // Placeholder
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: _editCar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text('Update'),
              ),
            ),
          ],
        ),
      ),),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _typeController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }
}


class UpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Convert the new value to uppercase
    final newText = newValue.text.toUpperCase();
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length), // Move cursor to the end
    );
  }
}