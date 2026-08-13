import 'dart:convert';
import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart' show SvgPicture;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/auth/vendor/Qrcode.dart';

import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import '../editpage/editvendorprofile.dart';
class vendorProfilePage extends StatefulWidget {
  final String vendorid;
  const vendorProfilePage({super.key, required this.vendorid});

  @override
  _vendorProfilePageState createState() => _vendorProfilePageState();
}
class _vendorProfilePageState extends State<vendorProfilePage> {
  Vendor? _vendor;
  bool value = false;

  List<Map<String, dynamic>> businessHours = List.generate(7, (index) {
    return {
      'day': getDayOfWeek(index),
      'openTime': '09:00',
      'closeTime': '21:00',
      'is24Hours': false,
      'isClosed': false,
    };
  });
  bool _isLoading = true;
  bool _hasError = false;
  File? _selectedImage;

  List<String> hours = List.generate(24, (index) {
    return index < 10 ? '0$index:00' : '$index:00';
  });

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    if (_vendor != null) {
      value = _vendor!.visibility;
    }

  }

  Future<bool> _updateVendorVisibility(bool newValue) async {
    try {
      print("=== UPDATE VISIBILITY DEBUG START ===");
      print("Vendor ID: ${widget.vendorid}");
      print("New Value: $newValue");
      print("API URL: ${ApiConfig.baseUrl}vendor/changevisibility");

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/changevisibility'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorId': widget.vendorid,
          'visibility': newValue,
        }),
      );

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Decoded Data: $data");

        final vendorData = data['vendor'];
        final updatedVisibility = vendorData?['visibility'] ?? newValue;

        print("Updated Visibility from server: $updatedVisibility");

        setState(() {
          value = updatedVisibility;
          _vendor = _vendor?.copyWith(visibility: updatedVisibility);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedVisibility
                  ? 'Visibility turned ON successfully'
                  : 'Visibility turned OFF successfully',
            ),
          ),
        );

        print("=== UPDATE VISIBILITY SUCCESS ===");
        return true; // success
      } else {
        print("Failed Response: ${response.body}");
        throw Exception('Failed to update vendor: ${response.body}');
      }
    } catch (e) {
      print("ERROR in _updateVendorVisibility: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('At least one slot (Car, Bike, or Others) must be available and enabled to set visibility')),
      );
      return false; // failed
    }
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
          value = _vendor?.visibility ?? false;
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

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }
  Widget _buildVisibilityConfirmSheet(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Turn On Your Visibility',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SvgPicture.asset('assets/svg/visible.svg', height: 150),
          const SizedBox(height: 10),
          Text(
            'Visibility is set to true and a platform fee will be deducted automatically.',
            style: GoogleFonts.poppins(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildModalButton(context, 'Cancel', Colors.grey, false),
              const SizedBox(width: 10),
              _buildModalButton(context, 'Confirm', ColorUtils.primarycolor(), true),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
  Widget _buildModalButton(BuildContext context, String text, Color color, bool result) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context, result),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }
  void _onVisibilityTurnedOn() {
    // Add your ON logic here
    debugPrint("Vendor is now VISIBLE");
    // Example: Show success Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor is now visible on platform')),
    );
  }

  void _onVisibilityTurnedOff() {
    // Add your OFF logic here
    debugPrint("Vendor is now HIDDEN");
    // Example: Remove vendor from live map or list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor is now hidden from users')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const LoadingGif();
    }

    if (_hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load data.'),
                ElevatedButton(
                  onPressed: _fetchAllData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: [

          IconButton(
            icon: const Icon(Icons.qr_code),
            color: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRPage(vendorid:widget.vendorid,vendorname:_vendor?.vendorName ?? '',)),
              );
            },
          ),
        ],
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          _vendor?.vendorName ?? '',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis, // Shows "..." at the end if too long
          maxLines: 1, // Keeps it to a single line
          softWrap: false, // Prevents wrapping
        ),

        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  Align(
                    alignment: Alignment.bottomRight,
                    child: AnimatedToggleSwitch<bool>.dual(
                      current: _vendor?.visibility ?? false, // Use vendor's visibility directly
                      first: false,
                      second: true,
                      borderWidth: 1.0,
                      height: 24.0,
                      spacing: 15.0,
                      styleBuilder: (val) => ToggleStyle(
                        backgroundColor: Colors.black,
                        borderColor: Colors.grey.shade400,
                        indicatorColor: val ? ColorUtils.primarycolor() : Colors.red,
                      ),
                      onChanged: (val) async {
                        bool? confirmed = val;

                        if (val == true) {
                          confirmed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) => Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: _buildVisibilityConfirmSheet(context),
                            ),
                          );
                        }

                        if (confirmed == val) {
                          bool success = await _updateVendorVisibility(val);
                          if (!success) {
                            // revert the toggle if update failed
                            setState(() {
                              value = !val;
                            });
                          }
                        } else {
                          setState(() {
                            value = !val;
                          });
                        }
                      },

                      iconBuilder: (val) => Icon(
                        val ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      textBuilder: (val) => Text(
                        val ? "VISIBLE" : "HIDDEN", // More descriptive text
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10, // Slightly smaller for longer text
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10,),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: ColorUtils.primarycolor(),
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 12, color: Colors.white),

                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => editvendorprofile(
                                        onEditSuccess: () {
                                          _fetchAllData(); // Refresh vendor data
                                        },
                                        vendorid: widget.vendorid,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _fetchAllData(); // Refresh data when edit is successful
                                    }
                                  });
                                },



                    ),
                  ),

                ],
              ),
        const SizedBox(height: 10,),
              Container(
                padding: const EdgeInsets.only(),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorUtils.primarycolor(), width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: 8),
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
                                child: _selectedImage == null && (_vendor?.image.isEmpty ?? true)
                                    ? const Icon(Icons.person, size: 30, color: Colors.black54)
                                    : null,
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(
                                    'Address:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _vendor?.address ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 5,
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(
                                    'Landmark:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _vendor?.landMark ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Contact details",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _vendor?.contacts.length ?? 0,
                itemBuilder: (context, index) {
                  final contact = _vendor!.contacts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: contact.name,
                            readOnly: true,
                            style: GoogleFonts.poppins(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Contact Person',
                              labelStyle: GoogleFonts.poppins(
                                color: ColorUtils.primarycolor(),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: contact.mobile,
                            readOnly: true,
                            style: GoogleFonts.poppins(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Contact Number',
                              labelStyle: GoogleFonts.poppins(
                                color: ColorUtils.primarycolor(),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                "Location details",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: ColorUtils.primarycolor()),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: _vendor?.latitude == null || _vendor?.longitude == null
                      ? const Center(child: Text("Location data not available"))
                      : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        double.tryParse(_vendor!.latitude.trim()) ?? 0.0,
                        double.tryParse(_vendor!.longitude.trim()) ?? 0.0,
                      ),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('vendor_location'),
                        position: LatLng(
                          double.tryParse(_vendor!.latitude.trim()) ?? 0.0,
                          double.tryParse(_vendor!.longitude.trim()) ?? 0.0,
                        ),
                        infoWindow: InfoWindow(
                          title: 'Vendor Location',
                          snippet: _vendor?.address ?? '',
                        ),
                      ),
                    },
                    onMapCreated: (GoogleMapController controller) {},
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Operational timings",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Open at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Close at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
                        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                dayData['day'],
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: dayData['isClosed']
                                  ? _statusLabel('Closed', Colors.red)
                                  : dayData['is24Hours']
                                  ? _statusLabel('24 Hours', Colors.green)
                                  : _styledBox(dayData['openTime']),
                            ),
                            if (!dayData['isClosed'] && !dayData['is24Hours']) const SizedBox(width: 8.0),
                            if (!dayData['isClosed'] && !dayData['is24Hours'])
                              Expanded(
                                flex: 3,
                                child: _styledBox(dayData['closeTime']),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "My Space details",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _vendor?.parkingEntries.map((entry) {
                  return Container(
                    width: width * 0.25,
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 0.5,
                        color: ColorUtils.primarycolor(),
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          Text(
                            entry.type,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w300,
                              fontSize: 12,
                              color: ColorUtils.primarycolor(),
                            ),
                          ),
                          Text(
                            entry.count,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: ColorUtils.primarycolor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList() ??
                    [],
              ),
            ],
          ),
        ),
      ),
      ),);
  }

  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isSmallScreen ? 4 : 8),
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

  Widget _styledBox(String value) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(":");
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = "${hour12.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")} $period";
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

  static String getDayOfWeek(int index) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[index];
  }
}

