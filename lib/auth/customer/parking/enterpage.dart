// import 'package:animated_custom_dropdown/custom_dropdown.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
// import 'package:intl/intl.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:mywheels/auth/customer/addcarviewcar/mycars.dart';
// import 'package:mywheels/auth/customer/parking/parking.dart';
// import 'package:mywheels/config/authconfig.dart';
// import 'package:mywheels/config/colorcode.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:async';
// import '../../../model/user.dart';
// import '../../vendor/vendorcreatebooking.dart';
// class enterpage extends StatefulWidget {
//   final String userId;
//   const enterpage({super.key, required this.userId});
//
//   @override
//   _enterpageState createState() => _enterpageState();
// }
//
//
// class _enterpageState extends State<enterpage> {
//   bool isCameraPermissionGranted = false;
//   String qrCodeResult = "No QR code scanned yet";
//   final MobileScannerController cameraController = MobileScannerController();
//   final TextEditingController dateTimeController = TextEditingController();
//   String? selectedCarType;
//   @override
//   void initState() {
//     super.initState();
//     _checkCameraPermission();
//   }
//
//   Future<void> _checkCameraPermission() async {
//     final status = await Permission.camera.status;
//
//     if (status.isGranted) {
//       setState(() => isCameraPermissionGranted = true);
//     } else if (status.isDenied) {
//       final result = await Permission.camera.request();
//       if (result.isGranted) {
//         setState(() => isCameraPermissionGranted = true);
//       } else {
//         _showPermissionDeniedDialog();
//       }
//     } else if (status.isPermanentlyDenied) {
//       _showPermissionDeniedDialog();
//     }
//   }
//
//   void _showPermissionDeniedDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         title: Text(
//           'Camera Permission Required',
//           style: GoogleFonts.poppins(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         content: Text(
//           'This app needs camera access to scan QR codes.',
//           style: GoogleFonts.poppins(fontSize: 14),
//         ),
//         actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         actions: [
//           ElevatedButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               openAppSettings();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: ColorUtils.primarycolor(), // or your preferred color
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(5),
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//             ),
//             child: Text(
//               'Open Settings',
//               style: GoogleFonts.poppins(color: Colors.white),
//             ),
//           ),
//           OutlinedButton(
//             onPressed: () => Navigator.of(context).pop(),
//             style: OutlinedButton.styleFrom(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(5),
//               ),
//               side: BorderSide(color: ColorUtils.primarycolor()),
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//             ),
//             child: Text(
//               'Cancel',
//               style: GoogleFonts.poppins(
//                 color: ColorUtils.primarycolor(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _toggleFlashlight() {
//     cameraController.toggleTorch();
//     setState(() {}); // Refresh to reflect torch status
//   }
//
//   void _onQrCodeDetected(String qrCode) {
//     setState(() {
//       qrCodeResult = qrCode;
//     });
//
//     // Stop the camera before navigating
//     cameraController.stop();
//
//     // Navigate to the next page with the scanned mall name
//     // Navigator.push(
//     //   context,
//     //   MaterialPageRoute(
//     //     builder: (context) => MallDetailsPage(mallName: qrCode, userId: widget.userId,vendorid: qrCode,),
//     //   ),
//     // );
//   }
//   @override
//   void dispose() {
//     cameraController.dispose(); // Dispose of the controller when the widget is removed
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(60.0),
//         child: Container(
//           decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.6),
//                 spreadRadius: 12,
//                 blurRadius: 8,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: AppBar(
//             backgroundColor: ColorUtils.primarycolor(),
//             title: const Text(
//               'Scan QR',
//               style: TextStyle(color: Colors.white),
//             ),
//             iconTheme: const IconThemeData(color: Colors.white),
//             actions: [
//               IconButton(
//                 icon: Icon(
//                   cameraController.torchEnabled ? Icons.flash_on : Icons.flash_off,
//                   color: Colors.white,
//                 ),
//                 onPressed: _toggleFlashlight,
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: isCameraPermissionGranted
//           ? Column(
//         children: [
//           Expanded(
//             child: MobileScanner(
//               controller: cameraController,
//               onDetect: (BarcodeCapture barcodeCapture) {
//                 final List<Barcode> barcodes = barcodeCapture.barcodes;
//                 if (barcodes.isNotEmpty) {
//                   final String? code = barcodes.first.rawValue;
//                   if (code != null) {
//                     _onQrCodeDetected(code);
//                   }
//                 }
//               },
//             ),
//           ),
//         ],
//       )
//           : const Center(child: Text('Camera permission not granted')),
//     );
//   }
// }
//
//
//
// class MallDetailsPage extends StatefulWidget {
//   final String vendorid;
//   final String mallName;
//   final String userId;
//   const MallDetailsPage({super.key, required this.mallName,required this.userId, required this.vendorid});
//
//   @override
//   _MallDetailsPageState createState() => _MallDetailsPageState();
// }
//
// class _MallDetailsPageState extends State<MallDetailsPage> {
//   final TextEditingController _mallNameController = TextEditingController();
//   final TextEditingController dateController = TextEditingController();
//   final SingleSelectController<String?> carController = SingleSelectController(null);
//   final TextEditingController _timeController = TextEditingController();
//   final FocusNode _mallnameFocusNode = FocusNode();
//
//   final FocusNode _timeFocusNode = FocusNode();
//   final FocusNode _dateFocusNode = FocusNode();
//   late Future<List<Car>> _futureCars;
//   List<String> cars = [];
//   String? _selectedCarType;
//   bool isLoading = false;
//   String? selectedCarType;
//   String _formatDateTime(DateTime dateTime) {
//     return DateFormat("dd-MM-yyyy hh:mm a").format(dateTime);  // Full date + time with AM/PM
//   }
//   User? _user;
//   String? _selectedVehicleNumber;
//   bool _isLoading=false;
//   final bool _issLoading=false;
//   String? selectedCar;
//   DateTime? selectedDateTime;
//   Timer? _timer;
//   Map<String, String> carTypeMap = {}; // Map to store car model and its type
//   Future<void> fetchCars(String userId) async {
//     setState(() {
//       isLoading = true; // Start loading
//     });
//     try {
//       print('Fetching cars for userId: $userId');
//       final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId'));
//
//       print('Response status: ${response.statusCode}');
//       print('Response body: ${response.body}');
//
//       if (response.statusCode == 200) {
//         Map<String, dynamic> jsonResponse = json.decode(response.body);
//         List<dynamic> vehiclesJson = jsonResponse['vehicles'] ?? [];
//         setState(() {
//           cars = vehiclesJson.map<String>((car) {
//             final model = car['vehicleNo'] ?? 'Unknown Model';
//             final vehicletype = car['type'] ?? 'No vehicle type';
//             carTypeMap[model] = vehicletype;
//             print('Vehicle Model: $model, Vehicle Type: $vehicletype');
//             return model;
//           }).toList();
//           print('Fetched cars: $cars'); // Log the fetched car list
//           isLoading = false; // Stop loading
//         });
//       } else {
//         throw Exception('Failed to load cars');
//       }
//     } catch (error) {
//       print('Error fetching cars: $error');
//       setState(() {
//         isLoading = false; // Stop loading on error
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching cars: $error')),
//       );
//     }
//   }
//   @override
//   void initState() {
//     super.initState();
//     _mallNameController.text = widget.mallName; // Pre-fill with mall name from QR code
//     fetchCars(widget.userId);
//     // Set the current date (using DateFormat) immediately
//     final now = DateTime.now();
//     dateController.text = DateFormat('dd-MM-yyyy').format(now);
//     _timeController.text = DateFormat('hh:mm a').format(now);
//     _fetchUserData();
//     // Start a timer to update time every second
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       setState(() {
//         final now = DateTime.now();
//         _timeController.text = DateFormat('hh:mm a').format(now);
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel(); // Cancel the timer to prevent memory leaks
//     super.dispose();
//   }
//   Future<void> _fetchUserData() async {
//     try {
//       final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//
//         if (data['success'] && data['data'] != null) {
//           setState(() {
//             _user = User.fromJson(data['data']); // Initialize user with fetched data
//           });
//         } else {
//           throw Exception(data['message']);
//         }
//       } else {
//         throw Exception('Failed to load user data');
//       }
//     } catch (error) {
//       print('Error fetching user data: $error');
//       // Show error message to user
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to load user data')),
//       );
//     }
//   }
//   Future<void> _registerParking() async {
//     // Check if selectedDateTime is null
//     // if (selectedDateTime == null) {
//     //   ScaffoldMessenger.of(context).showSnackBar(
//     //     SnackBar(content: Text('Please select a date and time')),
//     //   );
//     //   return;
//     // }
//
//     // Check if _user is null
//     if (_user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('User information is missing')),
//       );
//       return;
//     }
//
//     String formattedDate = dateController.text;
//     String formattedTime = _timeController.text;
//
//     try {
//       var data = {
//         'userid': widget.userId,
//         'place': widget.mallName ?? '',
//         'vehicleNumber': carController.value ?? '',
//         'bookingDate': formattedDate,
//         'time': formattedTime, // Use the formatted time
//         'vendorId': widget.vendorid, // Send only vendor ID
//         'carType': _selectedCarType ?? '',
//         'personName': _user?.username ?? 'a', // Provide a default value
//         'mobileNumber': _user?.mobileNumber ?? '', // Provide a default value
//         'sts': 'Instant',
//         'amount': "",
//         'hour': "",
//         'subscriptionType': '',
//         'status': "PARKED",
//         'parkingTime': formattedTime,
//         'parkingDate': formattedDate,
//         'vehicleType': selectedCarType!,
//         'bookingTime': formattedTime,
//         'cancelledStatus': "",
//       };
//
//       setState(() {
//         _isLoading = true;
//       });
//
//       // Debugging log for detailed data
//       print('Sending data to server:');
//       print('User ID: ${widget.userId}');
//       print('Place: ${_mallNameController.text}');
//       print('Vehicle Number: ${carController.value}');
//       print('Booking Date: $formattedDate');
//       print('Vendor ID: ${widget.vendorid}');
//       print('Car Type: $_selectedCarType');
//       print('Person Name: ${_user?.username}');
//       print('Mobile Number: ${_user?.mobileNumber}');
//       print('Status: Instant');
//       print('Parking Time: $formattedTime');
//       print('Parking Date: $formattedDate');
//       print('Vehicle Type: $selectedCarType');
//       print('Booking Time: $formattedTime');
//       print('Cancelled Status: ');
//
//       var response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl}vendor/createbooking'),
//         body: jsonEncode(data),
//         headers: {"Content-Type": "application/json"},
//       );
//
//       print('Response status: ${response.statusCode}');
//       print('Response body: ${response.body}');
//
//       if (response.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Parking registered successfully!')),
//         );
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => ParkingPage(userId: widget.userId)),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Slot not available')),
//         );
//       }
//     } catch (e) {
//       print('Error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Error connecting to server')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         iconTheme: const IconThemeData(
//           color: Colors.white, // Set the icon color to white
//         ),
//         backgroundColor: ColorUtils.primarycolor(),
//         title: const Text('Mall Details',style: TextStyle(color: Colors.white),),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//
//
//             const SizedBox(height: 5),
//             CuTextField(
//               labelColor: ColorUtils.primarycolor(),
//               controller: _mallNameController,
//               focusNode: _mallnameFocusNode,
//               keyboard: TextInputType.text,
//               obscure: false,
//               textInputAction: TextInputAction.next,
//               inputFormatter: const [], // You can add any input formatters here
//               label: 'place',
//               hint: 'place',
//               prefixIcon: Icon(Icons.location_on, color: ColorUtils.primarycolor(),), // Icon color for parking place
//               readOnly: true,
//               selectedColor: ColorUtils.primarycolor(),
//
//             ),
//             const SizedBox(height: 15,),
//             greyfield(
//               labelColor: ColorUtils.primarycolor(),
//               selectedColor: ColorUtils.primarycolor(),
//               controller: dateController,
//               focusNode: _dateFocusNode,
//               keyboard: TextInputType.text,
//               obscure: false,
//               textInputAction: TextInputAction.done,
//               inputFormatter: const [],
//               label: ' Parking Date',
//               hint: 'Parking Date',
//               prefixIcon: Icon(Icons.calendar_month_outlined, color: ColorUtils.primarycolor(),),
//               readOnly: true,
//
//               // onTap: () async {
//               //   _showDateTimePicker(); // Opens the date-time picker
//               // },
//             ),
//             const SizedBox(height: 15,),
//             greyfield(
//               labelColor: ColorUtils.primarycolor(),
//               selectedColor: ColorUtils.primarycolor(),
//               controller: _timeController,
//               focusNode: _timeFocusNode,
//               keyboard: TextInputType.text,
//               obscure: false,
//               textInputAction: TextInputAction.done,
//               inputFormatter: const [],
//               label: ' Time',
//               hint: 'Time',
//               prefixIcon: Icon(Icons.timer, color: ColorUtils.primarycolor(),),
//               readOnly: true,
//
//               // onTap: () async {
//               //   _showDateTimePicker(); // Opens the date-time picker
//               // },
//             ),
//             const SizedBox(height: 15,),
//             isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : Container(
//               height: 55,
//               decoration: BoxDecoration(
//                 border: Border.all(color: ColorUtils.primarycolor()), // Add a border
//                 borderRadius: BorderRadius.circular(5), // Circular border radius
//               ),
//               child: CustomDropdown<String?>(
//                 hintText: 'Select Vehicle',
//                 items: cars,
//                 controller: carController,
//                 onChanged: (String? value) {
//                   setState(() {
//                     carController.value = value;
//                     selectedCarType = carTypeMap[value!]; // Get the vehicle type from the map
//                     print('Selected Car: $value, Type: $selectedCarType'); // Log selected car and type
//                   });
//                 },
//               ),
//             ),
//
//             const SizedBox(height: 20),
//
//             _isLoading
//                 ? const CircularProgressIndicator()
//                 : ElevatedButton(
//               onPressed: _registerParking,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: ColorUtils.primarycolor(),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(5),
//                 ),
//               ),
//               child: const Text('Submit', style: TextStyle(color: Colors.white)),
//             ),
//
//           ],
//         ),
//       ),
//     );
//   }
//
//
// }
