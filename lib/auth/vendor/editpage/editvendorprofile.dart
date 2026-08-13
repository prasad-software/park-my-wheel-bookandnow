import 'dart:convert';
import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mywheels/auth/vendor/editpage/editslots.dart'
    show ParkingEntry;
import 'package:mywheels/config/authconfig.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import '../../../config/colorcode.dart';

class editvendorprofile extends StatefulWidget {
  final String vendorid;
  final Function() onEditSuccess;
  const editvendorprofile({
    super.key,
    required this.vendorid,
    required this.onEditSuccess,
  });

  @override
  _editvendorprofileState createState() => _editvendorprofileState();
}

class _editvendorprofileState extends State<editvendorprofile> {
  bool _hasAddedContact = false;
  Vendor? _vendor;
  final bool _isEditing = false;
  bool _isLoading = false;
  List<Map<String, String>> vendor = [];
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;
  late TextEditingController _addresscontroller;
  late TextEditingController _landmarkcontroller;
  late TextEditingController _upiIdController;
  final TextEditingController noofparking = TextEditingController();
  late FocusNode _landmarkFocusNode;
  late FocusNode _addressFocusNode;
  late FocusNode _upiIdFocusNode;
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  File? _selectedImage;
  String? selectedParkingType;
  final List<String> parkingTypes = ['Bikes', 'Cars', 'Others'];
  List<Map<String, String>> parkingEntries = [];
  final FocusNode _contactPersonFocusNode = FocusNode();
  final FocusNode _contactNumberFocusNode = FocusNode();
  late List<Widget> _pagess;
  late Future<Map<String, dynamic>> vendorData;

  bool isLoading = true;
  List<Map<String, dynamic>> businessHours = List.generate(7, (index) {
    return {
      'day': getDayOfWeek(index),
      'openTime': '09:00',
      'closeTime': '21:00',
      'is24Hours': false,
      'isClosed': false,
    };
  });
  bool _hasError = false;
  List<String> hours = List.generate(24, (index) {
    return index < 10 ? '0$index:00' : '$index:00';
  });
  Future<Map<String, dynamic>> fetchVendor(String vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId'),
      );

      if (response.statusCode == 200) {
        isLoading = false;
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch vendor');
      }
    } catch (e) {
      print('Error: $e');
      isLoading = false;
      return {};
    }
  }
      @override
      void initState() {
  super.initState();
  _isLoading = true;
  _fetchAllData();
  _fetchVendorData();
  vendorData = fetchVendor(widget.vendorid);
  vendorData.then((data) {
  setState(() {
  if (data['businessHours'] != null) {
  businessHours = List<Map<String, dynamic>>.from(data['businessHours']);
  }
  isLoading = false;
  });
  });
  _nameController = TextEditingController();
  _nameFocusNode = FocusNode();
  _addresscontroller = TextEditingController();
  _addressFocusNode = FocusNode();
  _landmarkcontroller = TextEditingController();
  _landmarkFocusNode = FocusNode();
  _upiIdController = TextEditingController();
  _upiIdFocusNode = FocusNode();
  }


  void _addvendor() {
    if (_contactPersonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter contact person name")),
      );
      return;
    }

    if (_contactNumberController.text.isEmpty ||
        _contactNumberController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter a valid 10-digit contact number")),
      );
      return;
    }

    setState(() {
      vendor.add({
        'name': _contactPersonController.text,
        'mobile': _contactNumberController.text,
      });

      _vendor?.contacts.add(Contact(
        name: _contactPersonController.text,
        mobile: _contactNumberController.text,
      ));

      _contactPersonController.clear();
      _contactNumberController.clear();
      _hasAddedContact = true;
    });
  }
  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Fetch both vendor data and business hours concurrently
      final vendorResponse = http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'),
      );
      final businessHoursResponse = http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/${widget.vendorid}'),
      );

      final responses = await Future.wait([vendorResponse, businessHoursResponse]);

      // Process vendor data
      final vendorDataResponse = responses[0];
      if (vendorDataResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(vendorDataResponse.body);
        if (data['data'] != null) {
          _vendor = Vendor.fromJson(data['data']);
          // value = _vendor?.visibility ?? false;
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${vendorDataResponse.statusCode}');
      }

      // Process business hours
      final businessHoursDataResponse = responses[1];
      if (businessHoursDataResponse.statusCode == 200) {
        final data = json.decode(businessHoursDataResponse.body);
        if (data['businessHours'] != null) {
          businessHours = List<Map<String, dynamic>>.from(data['businessHours']);
        }
      } else {
        throw Exception('Failed to fetch business hours, status code: ${businessHoursDataResponse.statusCode}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }
  Future<void> _fetchVendorData() async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _nameController.text = _vendor?.vendorName ?? '';
            _addresscontroller.text = _vendor?.address ?? '';
            _landmarkcontroller.text = _vendor?.landMark ?? '';
            _upiIdController.text = _vendor?.upiId ?? '';
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
            'Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVendorProfile() async {
    if (_nameController.text.isEmpty ||
        _addresscontroller.text.isEmpty ||
        _landmarkcontroller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }

    // Combine entries from both sources
    final allEntries = [
      ...?_vendor?.parkingEntries.map((e) => {'type': e.type, 'count': e.count}),
      ...parkingEntries,
    ];

    // Deduplicate
    final Map<String, String> uniqueEntries = {};
    for (var entry in allEntries) {
      uniqueEntries[entry['type']!] = entry['count']!;
    }

    final Map<String, dynamic> vendorData = {
      'vendorName': _nameController.text,
      'address': _addresscontroller.text,
      'landMark': _landmarkcontroller.text,
      'upiId': _upiIdController.text.trim(),
      'latitude': _vendor?.latitude,
      'longitude': _vendor?.longitude,
      'contacts': _vendor?.contacts
          .map((contact) => {
        'name': contact.name,
        'mobile': contact.mobile,
      })
          .toList(),
      'parkingEntries': uniqueEntries.entries
          .map((e) => {
        'type': e.key,
        'count': e.value,
      })
          .toList(),
    };

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/updatevendor/${widget.vendorid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(vendorData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendor profile updated successfully")),
        );
      } else {
        final responseBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to update vendor profile: ${responseBody['message']}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  List<String> getAvailableParkingTypes() {
    final addedTypes = {
      ...?_vendor?.parkingEntries.map((e) => e.type),
      ...parkingEntries.map((e) => e['type']!)
    };
    return parkingTypes.where((type) => !addedTypes.contains(type)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Edit Vendor Profile',
          style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:  _isLoading
          ? const LoadingGif()
          :SafeArea(
            child: SingleChildScrollView(
                    child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image Section
                Align(
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_vendor?.image.isNotEmpty ?? false
                            ? NetworkImage(_vendor!.image)
                            : null),
                        child: _selectedImage == null &&
                            (_vendor?.image.isEmpty ?? true)
                            ? const Icon(Icons.person,
                            size: 34, color: Colors.black54)
                            : null,
                      ),
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: ColorUtils.primarycolor(),
                        child: IconButton(
                          icon: const Icon(Icons.edit,
                              size: 12, color: Colors.white),
                          onPressed: _selectImage,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
            
                // Name Field
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      profileCustomTextField(
                        inputFormatter: const [],
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        keyboard: TextInputType.text,
                        obscure: false,
                        textInputAction: TextInputAction.next,
                        label: 'Name',
                        hint: 'Please enter your Name',
                      ),
                      const SizedBox(height: 10),
            
                      // Location Section
                      Row(
                        children: [
                          Text(
                            "Location details",
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                              onPressed: () async {
                                final selectedData = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditMapScreen(
                                      initialPosition: LatLng(
                                        double.tryParse(
                                            _vendor?.latitude ?? '0') ??
                                            0.0,
                                        double.tryParse(
                                            _vendor?.longitude ?? '0') ??
                                            0.0,
                                      ),
                                    ),
                                  ),
                                );
            
                                if (selectedData != null) {
                                  setState(() {
                                    _vendor = _vendor?.copyWith(
                                      latitude: selectedData['latitude'],
                                      longitude: selectedData['longitude'],
                                      address: selectedData['address'],
                                      landMark: selectedData['landMark'],
                                    );
                                    _addresscontroller.text =
                                    selectedData['address'];
                                    _landmarkcontroller.text =
                                    selectedData['landMark'];
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorUtils.primarycolor(),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: const Icon(Icons.edit, color: Colors.black, size: 12),
                                    ),
                                    const SizedBox(width: 5.0),
                                    Text(
                                      'Edit Location',
                                      style: GoogleFonts.poppins(
                                        fontSize: MediaQuery.of(context).size.width * 0.03,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
            
            
                        ],
                      ),
                      const SizedBox(height: 10),
            
                      // Map Preview
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ColorUtils.primarycolor(),
                            ),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5.0),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  double.tryParse(
                                      _vendor?.latitude ?? '0') ??
                                      0.0,
                                  double.tryParse(
                                      _vendor?.longitude ?? '0') ??
                                      0.0,
                                ),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('vendor_location'),
                                  position: LatLng(
                                    double.tryParse(
                                        _vendor?.latitude ?? '0') ??
                                        0.0,
                                    double.tryParse(
                                        _vendor?.longitude ?? '0') ??
                                        0.0,
                                  ),
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
            
                      // Address Fields
                      profileCustomTextField(
                        inputFormatter: const [],
                        controller: _addresscontroller,
                        focusNode: _addressFocusNode,
                        keyboard: TextInputType.text,
                        obscure: false,
                        textInputAction: TextInputAction.next,
                        label: 'Address',
                        hint: 'Please enter your Address',
                      ),
                      const SizedBox(height: 15),
                      profileCustomTextField(
                        inputFormatter: const [],
                        controller: _landmarkcontroller,
                        focusNode: _landmarkFocusNode,
                        keyboard: TextInputType.text,
                        obscure: false,
                        textInputAction: TextInputAction.next,
                        label: '*Landmark',
                        hint: 'Please enter your Landmark',
                      ),
                      const SizedBox(height: 15),
                      profileCustomTextField(
                        inputFormatter: const [],
                        controller: _upiIdController,
                        focusNode: _upiIdFocusNode,
                        keyboard: TextInputType.text,
                        obscure: false,
                        textInputAction: TextInputAction.done,
                        label: 'UPI ID',
                        hint: 'Please enter your UPI ID',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
            

                Row(
                  children: [
                    Text(
                      "Operational Timings",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Navigate to BusinessHours and wait for result
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusinessHours(
                                vendorid: widget.vendorid,
                              ),
                            ),
                          );

                          // If result is true, trigger the onEditSuccess callback to refresh vendorProfilePage
                          if (result == true) {
                            widget.onEditSuccess(); // Call the callback to refresh vendorProfilePage
                            setState(() {
                              _isLoading = true; // Show loading indicator
                            });
                            await _fetchAllData(); // Refresh editvendorprofile data
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(Icons.edit, color: Colors.black, size: 12),
                              ),
                              const SizedBox(width: 5.0),
                              Text(
                                'Edit Timings',
                                style: GoogleFonts.poppins(
                                  fontSize: MediaQuery.of(context).size.width * 0.03,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            
                  ],
                ),
                const SizedBox(height: 10),
            
                // Business Hours Display
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('Day',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Expanded(
                                flex: 3,
                                child: Text('Open at',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Expanded(
                                flex: 3,
                                child: Text('Close at',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: businessHours.length,
                        itemBuilder: (context, index) {
                          final dayData = businessHours[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 4.0, vertical: 3.0),
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(dayData['day'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          color: Colors.black87)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: dayData['isClosed']
                                      ? _statusLabel(
                                      'Closed', Colors.red)
                                      : dayData['is24Hours']
                                      ? _statusLabel('24 Hours',
                                      Colors.green)
                                      : _styledBox(
                                      dayData['openTime']),
                                ),
                                if (!dayData['isClosed'] &&
                                    !dayData['is24Hours'])
                                  const SizedBox(width: 8.0),
                                if (!dayData['isClosed'] &&
                                    !dayData['is24Hours'])
                                  Expanded(
                                    flex: 3,
                                    child: _styledBox(dayData['closeTime']),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text("Contact details",
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            
                // Contact List
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _vendor?.contacts.length ?? 0,
                  itemBuilder: (context, index) {
                    final contact = _vendor!.contacts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                initialValue: contact.name,
                                readOnly: true,
                                style: GoogleFonts.poppins(
                                    color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Contact Person',
                                  labelStyle: GoogleFonts.poppins(
                                    color: ColorUtils.primarycolor(),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 12.0),
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                initialValue: contact.mobile,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(
                                    color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Contact Number',
                                  labelStyle: GoogleFonts.poppins(
                                    color: ColorUtils.primarycolor(),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 12.0),
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            height: 40,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(5),
                                  bottomRight: Radius.circular(5)),
                              color: Colors.redAccent,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete),
                              color: Colors.white,
                              onPressed: () {
                                setState(() {
                                  _vendor?.contacts.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            
                // Add Contact Form
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: _contactPersonController,
                          keyboardType: TextInputType.text,
            
                          decoration: InputDecoration(
                            hintText: 'Contact Person',
                            labelText: 'Contact Person',
                            labelStyle: GoogleFonts.poppins(
                              color: ColorUtils.primarycolor(),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 12.0),
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                            border: const OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: ColorUtils.primarycolor(),
                                width: 0.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: ColorUtils.primarycolor(),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextFormField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Contact Number',
                            labelText: 'Contact Number',
                            labelStyle: GoogleFonts.poppins(
                              color: ColorUtils.primarycolor(),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 12.0),
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                            border: const OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: ColorUtils.primarycolor(),
                                width: 0.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: ColorUtils.primarycolor(),
                                width: 0.5,
                              ),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        color: ColorUtils.primarycolor(),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_rounded),
                        color: Colors.white,
                        onPressed: _addvendor,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            
                // My Space Details
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      "My Space details",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Navigate to editvendorslot and wait for result
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => editvendorslot(vendorid: widget.vendorid),
                            ),
                          );
                          // If result is true, refresh vendor data
                          if (result == true) {
                            setState(() {
                              _isLoading = true; // Show loading indicator
                            });
                            await _fetchVendorData(); // Re-fetch vendor data
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(Icons.edit, color: Colors.black, size: 12),
                              ),
                              const SizedBox(width: 5.0),
                              Text(
                                'Edit Slots',
                                style: GoogleFonts.poppins(
                                  fontSize: MediaQuery.of(context).size.width * 0.03,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            
                // Parking Entries List
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: (_vendor?.parkingEntries.length ?? 0) + parkingEntries.length,
                  itemBuilder: (context, index) {
                    // Combine both lists
                    final allEntries = [
                      ...?_vendor?.parkingEntries.map((e) => {'type': e.type, 'count': e.count}),
                      ...parkingEntries,
                    ];
                    final entry = allEntries[index];
            
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                initialValue: entry['type'],
                                readOnly: true,
                                style: GoogleFonts.poppins(
                                    color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Parking Type',
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 12.0),
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.black),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 0.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 40,
                              child: TextFormField(
                                readOnly: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                initialValue: entry['count'],
                                style: GoogleFonts.poppins(
                                    color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'No of Parking',
                                  labelStyle: GoogleFonts.poppins(
                                      color: Colors.black),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 12.0),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 0.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 0.5),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    if (index < (_vendor?.parkingEntries.length ?? 0)) {
                                      _vendor?.parkingEntries[index].count = value;
                                    } else {
                                      parkingEntries[index - (_vendor?.parkingEntries.length ?? 0)]['count'] = value;
                                    }
                                  });
                                  _updateVendorProfile();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          // Container(
                          //   height: 40,
                          //   decoration: const BoxDecoration(
                          //     borderRadius: BorderRadius.only(
                          //       topRight: Radius.circular(5),
                          //       bottomRight: Radius.circular(5),
                          //     ),
                          //     color: Colors.redAccent,
                          //   ),
                          //   child: IconButton(
                          //     icon: const Icon(Icons.delete),
                          //     color: Colors.white,
                          //     onPressed: () {
                          //       setState(() {
                          //         if (index < (_vendor?.parkingEntries.length ?? 0)) {
                          //           _vendor?.parkingEntries.removeAt(index);
                          //         } else {
                          //           parkingEntries.removeAt(index - (_vendor?.parkingEntries.length ?? 0));
                          //         }
                          //       });
                          //       _updateVendorProfile();
                          //     },
                          //   ),
                          // ),
                        ],
                      ),
                    );
                  },
                ),
            
                // Add Parking Entry Form
                const SizedBox(height: 5),
            
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _updateVendorProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primarycolor(),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 18.0),
                      ),
                      child: const Text('Update Profile'),
                    ),
                  ],
                ),
              ],
            ),
                    ),
                  ),
          ),
    );
  }

  // Helper methods
  TextStyle headerStyle(bool isSmallScreen) {
    return const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
  }

  Widget _styledBox(String value) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? 'PM' : 'AM';
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }

  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding:
      EdgeInsets.symmetric(vertical: 4, horizontal: isSmallScreen ? 4 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static String getDayOfWeek(int index) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[index];
  }
}

// Supporting classes and widgets
class profileCustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final bool enabled;
  final Function(String)? onSubmitted;

  const profileCustomTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: textInputAction,
        inputFormatters: inputFormatter,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: Colors.black,
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
              width: 0.5,
            ),
          ),
        ),
        style: GoogleFonts.poppins(
          color: enabled ? Colors.black : Colors.black,
        ),
      ),
    );
  }
}

class EditMapScreen extends StatefulWidget {
  final LatLng initialPosition;

  const EditMapScreen({super.key, required this.initialPosition});

  @override
  _EditMapScreenState createState() => _EditMapScreenState();
}

class _EditMapScreenState extends State<EditMapScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressController;
  late TextEditingController _landmarkController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late LatLng _center;
  GoogleMapController? _mapController;
  String address = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition;
    _initializeControllers();
    _updateAddress(_center);
  }

  void _initializeControllers() {
    _addressController = TextEditingController();
    _landmarkController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    _latitudeController.text = _center.latitude.toString();
    _longitudeController.text = _center.longitude.toString();
  }

  void _updateAddress(LatLng position) async {
    setState(() {
      isLoading = true;
      address = 'Fetching address...';
    });

    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          address =
          '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.postalCode ?? ''}';
          _addressController.text = address;
          _latitudeController.text = position.latitude.toString();
          _longitudeController.text = position.longitude.toString();
        });
      } else {
        setState(() {
          address = 'Address not found';
        });
      }
    } catch (e) {
      setState(() {
        address = 'Failed to fetch address';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Edit Location',
          style: GoogleFonts.poppins(
            fontSize: 18,
            // fontWeight: FontWeight.w500, // optional
          ),
        ),

        backgroundColor: ColorUtils.secondarycolor(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
            },
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 12.0,
            ),
            onCameraMove: (CameraPosition position) {
              _updateAddress(position.target);
            },
          ),
          Center(
            child: Icon(
              Icons.location_pin,
              size: 50,
              color: ColorUtils.primarycolor(),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_addressController, 'Address'),
                    isLoading
                        ? LoadingAnimationWidget.waveDots(
                        color: Colors.black, size: 50)
                        : Text(
                      'Address: $address',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(_landmarkController, '*Landmark'),
                    ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.primarycolor(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: Text(
                        'Confirm Location',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),);
  }

  Widget _buildTextField(
      TextEditingController controller,
      String labelText, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        String hintText = '',
        Function(String)? onSubmitted,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ColorUtils.primarycolor(),
            ),
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  void _saveAddress() {
    final selectedData = {
      'latitude': _latitudeController.text,
      'longitude': _longitudeController.text,
      'address': _addressController.text,
      'landMark': _landmarkController.text,
    };

    Navigator.pop(context, selectedData);
  }
}

enum BusinessHourMode { timeBased, twentyFourHours, closed }

class BusinessHours extends StatefulWidget {
  final String vendorid;

  const BusinessHours({required this.vendorid, super.key});

  @override
  _BusinessHoursState createState() => _BusinessHoursState();
}

class _BusinessHoursState extends State<BusinessHours> {
  late Future<Map<String, dynamic>> vendorData;
  bool isLoading = true;
  bool hasError = false;

  List<Map<String, dynamic>> businessHours = [];

  @override
  void initState() {
    super.initState();
    _initializeDefaultHours();
    loadVendorData();
  }

  void _initializeDefaultHours() {
    businessHours = List.generate(7, (index) {
      return {
        'day': getDayOfWeek(index),
        'openTime': '09:00',
        'closeTime': '21:00',
        'is24Hours': false,
        'isClosed': false,
      };
    });
  }

  Future<void> loadVendorData() async {
    try {
      vendorData = fetchVendor(widget.vendorid);
      final data = await vendorData;

      if (mounted) {
        setState(() {
          if (data['businessHours'] != null && data['businessHours'].isNotEmpty) {
            businessHours = List<Map<String, dynamic>>.from(data['businessHours']);
            // Sanitize openTime and closeTime for empty values
            for (var day in businessHours) {
              if (day['openTime'] == null || day['openTime'].toString().isEmpty) {
                day['openTime'] = '09:00';
              }
              if (day['closeTime'] == null || day['closeTime'].toString().isEmpty) {
                day['closeTime'] = '21:00';
              }
            }
          } else {
            _initializeDefaultHours();
          }
          isLoading = false;
        });
      }
    } catch (e) {
      print("Load error: $e");
      if (mounted) {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    }
  }
  Future<Map<String, dynamic>> fetchVendor(String vendorId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch vendor');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    if (isLoading) return const LoadingGif();

    if (hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: SafeArea(
          child: const Center(
            child: Text("Failed to load business hours. Please try again."),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Operational timings',
            style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16, color: Colors.black)),
        backgroundColor: ColorUtils.secondarycolor(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8.0 : 14.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Day', style: headerStyle(isSmallScreen))),
                  Expanded(
                      flex: 3,
                      child: Text('Open at', style: headerStyle(isSmallScreen))),
                  if (!isSmallScreen)
                    Expanded(
                        flex: 3,
                        child:
                        Text('Close at', style: headerStyle(isSmallScreen))),
                  Expanded(
                      flex: 4,
                      child: Text('Mode', style: headerStyle(isSmallScreen))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: businessHours.length,
                itemBuilder: (context, index) {
                  final dayData = businessHours[index];
        
                  BusinessHourMode getMode() {
                    if (dayData['isClosed']) return BusinessHourMode.closed;
                    if (dayData['is24Hours']) {
                      return BusinessHourMode.twentyFourHours;
                    }
                    return BusinessHourMode.timeBased;
                  }
        
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 6.0, vertical: 4.0),
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 3)
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(dayData['day'],
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: isSmallScreen ? 11 : 12,
                                  color: Colors.black87)),
                        ),
                        Expanded(
                          flex: 3,
                          child: dayData['isClosed']
                              ? _statusLabel('Closed', Colors.red,
                              isSmallScreen: isSmallScreen)
                              : dayData['is24Hours']
                              ? _statusLabel('24 Hours', Colors.green,
                              isSmallScreen: isSmallScreen)
                              : _styledDropdown(dayData['openTime'], (value) {
                            setState(
                                    () => dayData['openTime'] = value!);
                          }, isSmallScreen: isSmallScreen),
                        ),
                        if (!isSmallScreen)
                          Expanded(
                            flex: 3,
                            child: dayData['isClosed'] || dayData['is24Hours']
                                ? const SizedBox()
                                : _styledDropdown(dayData['closeTime'], (value) {
                              setState(() => dayData['closeTime'] = value!);
                            }, isSmallScreen: isSmallScreen),
                          ),
                        Expanded(
                          flex: 6,
                          child: AnimatedToggleSwitch<BusinessHourMode>.rolling(
                            current: getMode(),
                            values: BusinessHourMode.values,
                            height: isSmallScreen ? 28 : 32,
                            spacing: 2.0,
                            style: ToggleStyle(
                              borderRadius: BorderRadius.circular(12.0),
                              backgroundColor: Colors.grey.shade200,
                              indicatorColor: ColorUtils.primarycolor(),
                              borderColor: Colors.grey.shade300,
                              indicatorBorder:
                              Border.all(color: Colors.white, width: 0.5),
                            ),
                            onChanged: (mode) {
                              setState(() {
                                dayData['isClosed'] =
                                    mode == BusinessHourMode.closed;
                                dayData['is24Hours'] =
                                    mode == BusinessHourMode.twentyFourHours;
                                if (mode == BusinessHourMode.timeBased) {
                                  dayData['isClosed'] = false;
                                  dayData['is24Hours'] = false;
                                }
                              });
                            },
                            iconBuilder: (mode, isSelected) {
                              final color = isSelected ? Colors.white : Colors.black54;
        
                              Widget buildIconWithLabel(IconData icon, String label) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      const SizedBox(width: 4),
                                      Icon(icon, color: color),
                                      const SizedBox(width: 2),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 18,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                );
                              }
        
                              Widget buildIconWithLabe(IconData icon, String label) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      const SizedBox(width: 4),
                                      Icon(icon, color: color,size: 14,),
                                      const SizedBox(width: 2),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 18,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                );
                              }
        
                              switch (mode) {
                                case BusinessHourMode.timeBased:
                                  return buildIconWithLabe(Icons.access_time,""); // No label
                                case BusinessHourMode.twentyFourHours:
                                  return buildIconWithLabel(Icons.av_timer, "24 hours ");
                                case BusinessHourMode.closed:
                                  return buildIconWithLabel(Icons.close, "Closed ");
                                default:
                                  return const SizedBox.shrink(); // Fallback
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  bool success = await updateBusinessHours(widget.vendorid, businessHours);
        
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Business hours saved successfully!')),
                    );
        
                    Future.delayed(const Duration(milliseconds: 500), () {
                      Navigator.of(context).pop(true);
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save business hours.')),
                    );
                  }
                },
                icon: Icon(Icons.save,
                    size: isSmallScreen ? 16 : 18, color: Colors.white),
                label: Text('Save Operational Timings',
                    style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(),
                  minimumSize: Size(double.infinity, isSmallScreen ? 40 : 45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle headerStyle(bool isSmallScreen) {
    return TextStyle(
        fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 10 : 12);
  }

  Widget _styledDropdown(String value, ValueChanged<String?> onChanged,
      {required bool isSmallScreen}) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? 'PM' : 'AM';
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    }

    return GestureDetector(
      onTap: () async {
        TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
        if (value.isNotEmpty) {
          final parts = value.split(':');
          if (parts.length >= 2) {
            initialTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
        
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: initialTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: ColorUtils.primarycolor(),
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                  surface: Colors.white,
                  secondary: ColorUtils.primarycolor(),
                  onSecondary: Colors.white,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: ColorUtils.primarycolor(),
                  ),
                ),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                child: child!,
              ),
            );
          },
        );

        if (pickedTime != null) {
          final hourStr = pickedTime.hour.toString().padLeft(2, '0');
          final minStr = pickedTime.minute.toString().padLeft(2, '0');
          onChanged('$hourStr:$minStr');
        }
      },
      child: Container(
        height: 30,
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue,
              style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: Colors.black87),
            ),
            Icon(Icons.arrow_drop_down,
                size: isSmallScreen ? 14 : 16, color: Colors.indigo),
          ],
        ),
      ),
    );
  }

  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding:
      EdgeInsets.symmetric(vertical: 4, horizontal: isSmallScreen ? 4 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static String getDayOfWeek(int index) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[index];
  }

  Future<bool> updateBusinessHours(
      String vendorId, List<Map<String, dynamic>> businessHours) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}vendor/updatehours/$vendorId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'businessHours': businessHours}),
    );
    return response.statusCode == 200;
  }
}

class Vendor {
  final String vendorName;
  final String address;
  final String landMark;
  final String latitude;
  final String longitude;
  final String image;
  final String upiId;
  final List<Contact> contacts;
  final List<ParkingEntry> parkingEntries;
  final bool visibility;       // ✅ Added
  double? distance;            // ✅ Optional, for location-based sorting

  Vendor({
    required this.vendorName,
    required this.address,
    required this.landMark,
    required this.latitude,
    required this.longitude,
    required this.image,
    required this.upiId,
    required this.contacts,
    required this.parkingEntries,
    required this.visibility,
    this.distance,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      vendorName: json['vendorName'] ?? '',
      address: json['address'] ?? '',
      landMark: json['landMark'] ?? '',
      latitude: json['latitude']?.toString() ?? '0',
      longitude: json['longitude']?.toString() ?? '0',
      image: json['image'] ?? '',
      upiId: json['upiId']?.toString() ?? '',
      contacts: (json['contacts'] as List<dynamic>? ?? [])
          .map((e) => Contact.fromJson(e))
          .toList(),
      parkingEntries: (json['parkingEntries'] as List<dynamic>? ?? [])
          .map((e) => ParkingEntry.fromJson(e))
          .toList(),
      visibility: json['visibility'] ?? false,
      distance: json['distance']?.toDouble(), // optional if provided from backend
    );
  }

  Vendor copyWith({
    String? vendorName,
    String? address,
    String? landMark,
    String? latitude,
    String? longitude,
    String? image,
    String? upiId,
    List<Contact>? contacts,
    List<ParkingEntry>? parkingEntries,
    bool? visibility,
    double? distance,
  }) {
    return Vendor(
      vendorName: vendorName ?? this.vendorName,
      address: address ?? this.address,
      landMark: landMark ?? this.landMark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      image: image ?? this.image,
      upiId: upiId ?? this.upiId,
      contacts: contacts ?? this.contacts,
      parkingEntries: parkingEntries ?? this.parkingEntries,
      visibility: visibility ?? this.visibility,
      distance: distance ?? this.distance,
    );
  }
}

class Contact {
  final String name;
  final String mobile;

  Contact({required this.name, required this.mobile});

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
    );
  }
}

class editvendorslot extends StatefulWidget {
  final String vendorid;
  const editvendorslot({super.key, required this.vendorid});

  @override
  _EditslotssState createState() => _EditslotssState();
}
class _EditslotssState extends State<editvendorslot> {
  Vendor? _vendor;
  bool _isLoading = false;
  List<Map<String, String>> vendor = [];
  late TextEditingController _nameController;
  final TextEditingController noofparking = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = ['Bikes', 'Cars', 'Others'];
  List<Map<String, String>> parkingEntries = [];
  late List<Widget> _pagess;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _fetchVendorData();
    _nameController = TextEditingController();
  }

  void _addParkingEntry(String type, String count) {
    if (type.isEmpty || count.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select parking type and enter number of parking spots")),
      );
      return;
    }

    bool isTypeAlreadyAdded = parkingEntries.any((entry) => entry['type'] == type);

    if (isTypeAlreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This parking type has already been added")),
      );
      return;
    }

    setState(() {
      parkingEntries.add({
        'type': type,
        'count': count,
      });

      _vendor?.parkingEntries.add(ParkingEntry(type: type, count: count));

      // Clear input fields (handled in modal)
    });

    _updateVendorProfile();
  }

  Future<void> _fetchVendorData() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _nameController.text = _vendor?.vendorName ?? '';
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

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
        return Padding(
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
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                        ),
                        value: selectedType,
                        onChanged: (String? newValue) {
                          selectedType = newValue; // Update local variable
                        },
                        items: getAvailableParkingTypes()
                            .map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item, style: GoogleFonts.poppins(fontSize: 12)),
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
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0),
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
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
                        backgroundColor: ColorUtils.primarycolor(),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () {
                        if (selectedType != null && parkingController.text.isNotEmpty) {
                          Navigator.pop(context);
                          _addParkingEntry(selectedType!, parkingController.text);
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
        );
      },
    );
  }

  Future<void> _updateVendorProfile() async {
    final List<Map<String, String>> mergedParkingEntries = [
      ..._vendor?.parkingEntries.map((entry) => {
        'type': entry.type,
        'count': entry.count,
      }).toList() ??
          [],
      ...parkingEntries.map((entry) => {
        'type': entry['type']!,
        'count': entry['count']!,
      }),
    ];

    final Map<String, String> uniqueParkingEntries = {};
    for (var entry in mergedParkingEntries) {
      final type = entry['type'] ?? 'Unknown Type';
      final count = entry['count'] ?? '0';
      uniqueParkingEntries[type] = count;
    }

    final Map<String, dynamic> vendorData = {
      'parkingEntries': uniqueParkingEntries.entries.map((e) => {
        'type': e.key,
        'count': e.value,
      }).toList(),
    };

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/updatevendor/${widget.vendorid}');
      final headers = {'Content-Type': 'application/json'};
      final body = json.encode(vendorData);

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        _fetchVendorData();
      } else {
        final responseBody = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${responseBody['message']}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  List<String> getAvailableParkingTypes() {
    final addedParkingTypes = _vendor?.parkingEntries.map((entry) => entry.type).toSet() ?? {};
    return parkingTypes.where((type) => !addedParkingTypes.contains(type)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return _isLoading
        ? const LoadingGif()
        : Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Edit Slots',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _vendor?.parkingEntries.length ?? 0,
                itemBuilder: (context, index) {
                  final parkingEntry = _vendor!.parkingEntries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              initialValue: parkingEntry.type,
                              readOnly: true,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Parking Type',
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 12.0),
                                labelStyle: GoogleFonts.poppins(color: Colors.black),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                  BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                  BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              initialValue: parkingEntry.count,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'No of Parking',
                                labelStyle: GoogleFonts.poppins(color: Colors.black),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 12.0),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                  BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                  BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  parkingEntry.count = value;
                                  _vendor?.parkingEntries[index].count = value;
                                });
                                _updateVendorProfile();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          height: 40,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(5),
                              bottomRight: Radius.circular(5),
                            ),
                            color: Colors.redAccent,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                if (_vendor?.parkingEntries.isNotEmpty ?? false &&
                                    index < _vendor!.parkingEntries.length) {
                                  _vendor?.parkingEntries.removeAt(index);
                                  if (index < parkingEntries.length) {
                                    parkingEntries.removeAt(index);
                                  }
                                }
                              });
                              _updateVendorProfile();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor(),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(90, 25),
                    ),
                    child: const Text('Update slots', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}