import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mywheels/config/colorcode.dart';

class MapsScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapsScreen({super.key, this.initialPosition});

  @override
  _MapScreenState createState() => _MapScreenState();
}
class _MapScreenState extends State<MapsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _landmarkController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  LatLng _center = const LatLng(12.9716, 77.5946);
  GoogleMapController? _mapController;
  String address = 'Fetching';
  bool isLoading = false;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _requestPermission();
    _getCurrentLocation();
  }

  void _initializeControllers() {
    _addressController = TextEditingController();
    _landmarkController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
  }
  void _onCameraMoveEnd(LatLng position) {
    // Cancel any previous debounce timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new debounce timer
    _debounce = Timer(const Duration(seconds: 1), () {
      _updateAddress(position);
    });
  }
  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _center = LatLng(position.latitude, position.longitude);
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
        _updateAddress(_center);
      }
    });
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
          // Construct the address string
          address = ' ${placemark.subLocality ?? ''}, ${placemark.locality ?? ''}, '
              '${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}, ${placemark.postalCode ?? ''}';

          // Update the text controllers with the new address
          _addressController.text = address.trim(); // Use trim to remove any leading/trailing spaces
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
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: const Text(
              'Location permission is required for this feature. Please enable it in the app settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (widget.initialPosition != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(widget.initialPosition!));
                }
              },
              myLocationEnabled: true,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 18.0,
              ),
              onCameraMove: (CameraPosition position) {
                _updateAddress(position.target); // Update the address when camera moves
              },
            ),
            Center(
              child: Icon(Icons.location_pin, size: 50, color:ColorUtils.primarycolor(),),
            ),
            Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_addressController, 'Door No,Street'),
                    // isLoading
                    //     ?Text("Fetching ....")
                    //     : Text(
                    //   'Address: $address ',
                    //   overflow: TextOverflow.ellipsis,
                    //   maxLines: 2,
                    //   style: const TextStyle(color: Colors.black),
                    // ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                         Text(
                          'Address:',
                          style:  GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
              
                        Expanded(
                          child: _buildText(_addressController, 'Enter Address'), // Make TextField take full width
                        ),
                      ],
                    ),
              
              
                    _buildTextField(_landmarkController, 'Landmark'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        GestureDetector(
                          onTap: _saveAddress, // Function to execute on tap
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            // decoration: BoxDecoration(
                            //   color: ColorUtils.primarycolor(), // Primary color background
                            //   borderRadius: BorderRadius.circular(5),
                            // ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 5), // Spacing
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration:  BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ColorUtils.primarycolor(), // Green background for icon
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
              
              
                      ],
                    ),
              
                  ],
                ),
              ),
            ),
          ),
        ],
      ),),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String labelText, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        String hintText = '',
        Function(String)? onSubmitted,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style:  GoogleFonts.poppins(fontSize: 14), // Reduce text size if needed
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12), // Reduce height
        labelText: labelText,
        hintText: hintText,
        labelStyle:  GoogleFonts.poppins(
          fontSize: 14, // Reduce label font size
          color: ColorUtils.primarycolor(),
        ),
        // border: OutlineInputBorder(
        //   borderRadius: BorderRadius.circular(8), // Reduce border radius
        //   borderSide: BorderSide(
        //     color: ColorUtils.primarycolor(),
        //   ),
        // ),
        // focusedBorder: OutlineInputBorder(
        //   borderRadius: BorderRadius.circular(8),
        //   borderSide: BorderSide(
        //     color: ColorUtils.primarycolor(),
        //   ),
        // ),
        // enabledBorder: OutlineInputBorder(
        //   borderRadius: BorderRadius.circular(8),
        //   borderSide: BorderSide(
        //     color: ColorUtils.primarycolor(),
        //   ),
        // ),
      ),
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildText(
      TextEditingController controller,
      String labelText, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
        String hintText = '',
        Function(String)? onSubmitted,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style:  GoogleFonts.poppins(fontSize: 14), // Reduce text size if needed
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2), // Reduce height
        border: InputBorder.none, // Remove underline
        hintText: hintText, // Optional placeholder
      ),
      onSubmitted: onSubmitted,
    );
  }

  void _saveAddress() {
    // Create a map to hold the selected data
    final selectedData = {
      'latitude': _latitudeController.text,
      'longitude': _longitudeController.text,
      'address': ' ${_addressController.text}',
      'landmark': _landmarkController.text,
    };

    // Print the entered data to the console
    print('Entered Data:');
    print('Latitude: ${_latitudeController.text}');
    print('Longitude: ${_longitudeController.text}');
    print('Address: ${_addressController.text}');
    print('Landmark: ${_landmarkController.text}');

    // Pop the MapsScreen and return the selected data
    Navigator.pop(context, selectedData);
  }
}
