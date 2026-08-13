// import 'package:flutter/material.dart';
//
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
//
// import 'package:parkmywheels/config/colorcode.dart';
//
//
// class MapScreen extends StatefulWidget {
//   final LatLng? initialPosition;
//   final Function(LatLng, String, String)? onLocationSelected;
//   final String uid;
//
//   const MapScreen({super.key,
//     required this.initialPosition,
//     required this.onLocationSelected,
//     required this.uid,
//   });
//
//   @override
//   _MapScreenState createState() => _MapScreenState();
// }
//
// class _MapScreenState extends State<MapScreen> {
//
//
//   LatLng _center = const LatLng(12.9716, 77.5946);
//   GoogleMapController? _mapController;
//
//   bool isLoading = false;
//
//
//   @override
//   void initState() {
//     super.initState();
//
//     _requestPermission();
//     _getCurrentLocation();
//   }
//
//
//
//   Future<void> _requestPermission() async {
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         _showPermissionDeniedDialog();
//       }
//     }
//   }
//
//   Future<void> _getCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);
//     setState(() {
//       _center = LatLng(position.latitude, position.longitude);
//       if (_mapController != null) {
//         _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
//
//       }
//     });
//   }
//
//   // void _updateAddress(LatLng position) async {
//   //   setState(() {
//   //     isLoading = true;
//   //     address = 'Fetching address...'; // Temporary message
//   //   });
//   //
//   //   try {
//   //     List<Placemark> placemarks =
//   //     await placemarkFromCoordinates(position.latitude, position.longitude);
//   //     if (placemarks.isNotEmpty) {
//   //       Placemark placemark = placemarks[0];
//   //       setState(() {
//   //         address = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.postalCode ?? ''}';
//   //         // Set text fields with fetched data
//   //         _latitudeController.text = position.latitude.toString();
//   //         _longitudeController.text = position.longitude.toString();
//   //       });
//   //     } else {
//   //       setState(() {
//   //         address = 'Address not found';
//   //       });
//   //     }
//   //   } catch (e) {
//   //     setState(() {
//   //       address = 'Failed to fetch address';
//   //     });
//   //   }
//   //
//   //   setState(() {
//   //     isLoading = false;
//   //   });
//   // }
//
//
//   void _showPermissionDeniedDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Permission Denied'),
//           content: const Text(
//               'Location permission is required for this feature. Please enable it in the app settings.'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Select Location', style: TextStyle(color: Colors.white)),
//         backgroundColor: ColorUtils.primarycolor(),
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             onMapCreated: (GoogleMapController controller) {
//               _mapController = controller;
//               if (widget.initialPosition != null) {
//                 _mapController!.animateCamera(
//                     CameraUpdate.newLatLng(widget.initialPosition!));
//               }
//             },
//             myLocationEnabled: true,
//             initialCameraPosition: CameraPosition(
//               target: _center,
//               zoom: 12.0,
//             ),
//
//           ),
//           Center(
//             child: Icon(Icons.location_pin, size: 50, color: ColorUtils.primarycolor(),),
//           ),
//
//         ],
//       ),
//     );
//   }
//
//
// }
//
//
