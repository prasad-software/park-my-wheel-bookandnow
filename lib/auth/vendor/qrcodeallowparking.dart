import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mywheels/auth/customer/bookticket.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdpage.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';

import '../customer/dummypages/drawermyspace.dart' hide ParkingEntry;
import '../customer/dummypages/myspaceeditslotchargesamenties.dart'
    show ParkingEntry;
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';
import 'bookings.dart';
import 'menusscreen.dart';
import 'package:mywheels/auth/vendor/paytimeamount.dart';
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class qrcodeallowpark extends StatefulWidget {
  final String vendorid;
  const qrcodeallowpark({super.key, required this.vendorid});

  @override
  _qrcodeallowparkState createState() => _qrcodeallowparkState();
}

class _qrcodeallowparkState extends State<qrcodeallowpark>
    with WidgetsBindingObserver, RouteAware {
  String? _menuImageUrl;
  int _selectedIndex = 2;
  bool isCameraPermissionGranted = false;
  String qrCodeResult = "No QR code scanned yet";
  final MobileScannerController cameraController = MobileScannerController();
  Barcode? _barcode;
  DateTime today = DateTime.now();
  DateTime? parkingDate;
  bool isScannerRunning = true;
  bool _isControllerInitialized = false;
  bool _isDisposed = false;
  bool _isPermanentlyDenied = false;
  late List<Widget> _pages;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pages = [
      vendordashScreen(vendorid: widget.vendorid),
      Bookings(vendorid: widget.vendorid),
      qrcodeallowpark(vendorid: widget.vendorid),
      Third(vendorid: widget.vendorid),
      menu(vendorid: widget.vendorid),
    ];

    _checkPermissionStatus();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
    });

    // Check camera permission status
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        isCameraPermissionGranted = true;
      });
      await _startScanner();
    } else {
      await requestCameraPermission();
    }

    setState(() {
      _isLoading = false;
      _isControllerInitialized = true;
    });
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.camera.status;
    setState(() {
      _isPermanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _startScanner() async {
    try {
      if (_isDisposed || !_isControllerInitialized) return;

      await cameraController.start();
      if (!_isDisposed) {
        setState(() {
          isScannerRunning = true;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start camera: $e')));
      }
    }
  }

  Future<void> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isDenied) {
      // Show explanation dialog if permission was denied before
      final shouldRequest = await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Camera Permission Required'),
              content: const Text(
                'MyWheels needs camera access to scan QR codes',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('OK'),
                ),
              ],
            ),
      );

      if (shouldRequest != true) {
        setState(() {
          isCameraPermissionGranted = false;
        });
        return;
      }
    }

    final newStatus = await Permission.camera.request();
    setState(() {
      isCameraPermissionGranted = newStatus.isGranted;
    });

    if (newStatus.isGranted && !_isDisposed) {
      await _startScanner();
    } else if (newStatus.isPermanentlyDenied) {
      // Show option to open app settings
      if (!mounted) return;
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Please enable camera access in app settings',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: ColorUtils.primarycolor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() async {
    if (!isScannerRunning && isCameraPermissionGranted) {
      await _startScanner();
      setState(() {
        isScannerRunning = true;
        qrCodeResult = "No QR code scanned yet";
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isCameraPermissionGranted) return;

    if (state == AppLifecycleState.resumed) {
      cameraController.start();
    } else if (state == AppLifecycleState.paused) {
      cameraController.stop();
    }
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }

  void _onTabChange(int index) {
    _navigateToPage(index);
  }

  void _toggleFlashlight() {
    if (isCameraPermissionGranted && _isControllerInitialized) {
      try {
        cameraController.toggleTorch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to toggle flashlight: $e')),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not initialized or permission not granted'),
        ),
      );
    }
  }

  Widget _barcodePreview(Barcode? value) {
    if (value == null) {
      return const Text(
        'Scan something!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'No display value.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  void _handleBarcode(BarcodeCapture barcodes) async {
    if (!mounted || !isScannerRunning) return;

    final barcode = barcodes.barcodes.firstOrNull;
    if (barcode == null) return;

    setState(() {
      _barcode = barcode;
      isScannerRunning = false;
    });

    try {
      dynamic parsedData;
      try {
        parsedData = jsonDecode(barcode.rawValue ?? '');
      } catch (e) {
        final lines = (barcode.rawValue ?? '').split('\n');
        parsedData = {};
        for (String line in lines) {
          final parts = line.split(':');
          if (parts.length == 2) {
            parsedData[parts[0].trim()] = parts[1].trim();
          }
        }
      }

      final qrCode = parsedData['bookingId'] ?? barcode.rawValue;
      final vendorId = parsedData['vendorId'] ?? widget.vendorid;

      if (qrCode != null && vendorId != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => BookingDetailsPage(
                  bookingId: qrCode,
                  vendorid: widget.vendorid,
                ),
          ),
        ).then((_) {
          if (mounted && isCameraPermissionGranted) {
            cameraController.start();
            setState(() {
              isScannerRunning = true;
              _barcode = null;
            });
          }
        });
      } else {
        throw const FormatException("Invalid QR code format");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid QR code: ${e.toString()}')),
        );
      }

      if (isCameraPermissionGranted && !_isDisposed) {
        await cameraController.start();
        setState(() {
          isScannerRunning = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ColorUtils.secondarycolor(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => vendorChooseParkingPage(vendorid: widget.vendorid),
              ),
            );
          },
        ),
        titleSpacing: 15,
        automaticallyImplyLeading: false,
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Entry Scan',
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isControllerInitialized && cameraController.torchEnabled
                  ? Icons.flash_on
                  : Icons.flash_off,
              color: Colors.black,
            ),
            onPressed: _toggleFlashlight,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (isCameraPermissionGranted && _isControllerInitialized)
              MobileScanner(
                controller: cameraController,
                onDetect: _handleBarcode,
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        isCameraPermissionGranted
                            ? 'Camera initialization failed'
                            : 'Camera access is required to scan QR codes',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        await requestCameraPermission();
                        if (isCameraPermissionGranted && !isScannerRunning) {
                          await _startScanner();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                          side: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: ColorUtils.primarycolor(),
                        elevation: 2,
                      ),
                      child: const Text('Grant Camera Permission'),
                    ),
                    if (_isPermanentlyDenied)
                      const TextButton(
                        onPressed: openAppSettings,
                        child: Text('Open Settings to Enable'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: _onTabChange,
        menuImageUrl: _menuImageUrl,
      ),
    );
  }
}

// Placeholder for RightToLeftPageRoute (replace with your actual implementation)
class RightToLeftPageRoute extends MaterialPageRoute {
  RightToLeftPageRoute({required super.builder});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }
}

class BookingDetailsPage extends StatefulWidget {
  final String bookingId;
  final String vendorid;

  const BookingDetailsPage({
    super.key,
    required this.bookingId,
    required this.vendorid,
  });

  @override
  _BookingDetailsPageState createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  Map<String, dynamic>? bookingDetails;
  bool isLoading = true;
  String? errorMessage;
  DateTime today = DateTime.now();
  DateTime? parkingDate;
  bool isTodayParking = false;
  bool _locationDenied = false;
  List<dynamic> charges = [];
  bool _locationPermanentlyDenied = false;
  late Position _currentPosition;
  List<String> favoriteVendorIds = [];
  List<String> amenities = []; // Add your amenities list
  List<Services> services = []; // Add your services list
  int selectedTabIndex = 0; // Track selected tab index
  double containerHeight = 500.0; // Define the containerHeight variable

  bool _isExiting = false;
  bool _isCheckingExit = false;

  static const Duration _printTimeout = Duration(seconds: 18);
  static const Duration _apiTimeout = Duration(seconds: 20);
  static const Duration _exitApiTimeout = Duration(seconds: 30);

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case "open parking":
        return Icons.local_parking;
      case "gated parking":
        return Icons.lock;
      case "charging":
        return Icons.electric_car;
      case "covered parking":
        return Icons.garage;
      case "cctv":
        return Icons.videocam;
      case "atms":
        return Icons.atm;
      case "wi-fi":
        return Icons.wifi;
      case "self car wash":
        return Icons.local_car_wash;
      case "restroom":
        return Icons.wc;
      case "security":
        return Icons.security;
      default:
        return Icons.help_outline; // Default icon for unknown amenities
    }
  }

  Pendor? _vendor;
  @override
  void initState() {
    super.initState();
    print('=== Debugging initState ===');
    print('Booking ID: ${widget.bookingId}');
    print('Vendor ID: ${widget.vendorid}');
    print('Today (DateTime.now()): $today');

    _fetchBookingDetails().then((_) {
      // Move parkingDate logic here
      if (bookingDetails != null && bookingDetails!['parkingDate'] != null) {
        try {
          print('Raw parkingDate: ${bookingDetails!['parkingDate']}');
          parkingDate = DateFormat(
            'dd-MM-yyyy',
          ).parse(bookingDetails!['parkingDate']);
          print('Parsed parkingDate: $parkingDate');
          print(
            'Today year: ${today.year}, month: ${today.month}, day: ${today.day}',
          );
          print(
            'ParkingDate year: ${parkingDate!.year}, month: ${parkingDate!.month}, day: ${parkingDate!.day}',
          );
          isTodayParking =
              parkingDate != null &&
              today.year == parkingDate!.year &&
              today.month == parkingDate!.month &&
              today.day == parkingDate!.day;
          print('isTodayParking after comparison: $isTodayParking');
        } catch (e) {
          print('Error parsing parkingDate: $e');
          parkingDate = null;
          isTodayParking = false;
        }
      } else {
        print('bookingDetails or parkingDate is null');
        print('bookingDetails: $bookingDetails');
        print('parkingDate: ${bookingDetails?['parkingDate']}');
        isTodayParking = false;
      }

      if (bookingDetails != null && bookingDetails!['vehicleType'] != null) {
        print(
          'Calling fetchChargesData with vehicleType: ${bookingDetails!['vehicleType']}',
        );
        fetchChargesData(widget.vendorid, bookingDetails!['vehicleType']);
      } else {
        print('vehicleType is missing, cannot fetch charges');
        setState(() {
          charges = [];
          isLoading = false;
        });
      }

      // Trigger UI rebuild after setting isTodayParking
      setState(() {});
    });

    _requestLocationPermission();
    _fetchVendorData();
  }

  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId',
    );
    print('Fetching amenities from: $url');
    try {
      final response = await http.get(url);
      print('Amenities response status: ${response.statusCode}');
      print('Amenities response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed amenities data: $data');
        if (data['AmenitiesData'] != null) {
          return AmenitiesAndParking.fromJson(data);
        } else {
          throw Exception('AmenitiesData is null in response');
        }
      } else {
        throw Exception(
          'Failed to load amenities data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching amenities: $e');
      throw Exception('Error fetching amenities data: $e');
    }
  }

  Future<void> fetchChargesData(String vendorId, String selectedCarType) async {
    setState(() {
      isLoading = true;
    });
    try {
      final url =
          '${ApiConfig.baseUrl}vendor/fetchbookcharge/$vendorId/$selectedCarType';
      print('Fetching charges from: $url');
      final response = await http.get(Uri.parse(url));
      print('Charges response status: ${response.statusCode}');
      print('Charges response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed charges data: $data');

        if (data is List) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(data);
          });
          print('Charges loaded as list: $charges');
        } else if (data['vendor'] != null &&
            data['vendor']['charges'] != null) {
          setState(() {
            charges = List<Map<String, dynamic>>.from(
              data['vendor']['charges'],
            );
          });
          print('Charges loaded from vendor: $charges');
        } else {
          print('Charges data is missing or invalid in the response.');
          setState(() {
            charges = [];
          });
        }
      } else {
        print(
          'Failed to load charges data. Status Code: ${response.statusCode}',
        );
        setState(() {
          charges = [];
        });
      }
    } catch (e) {
      print('Error fetching charges data: $e');
      setState(() {
        charges = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_vendor != null) {
        double distance = haversineDistance(
          _currentPosition.latitude,
          _currentPosition.longitude,
          double.tryParse(_vendor!.latitude) ?? 0.0,
          double.tryParse(_vendor!.longitude) ?? 0.0,
        );
        setState(() {
          _vendor!.distance = distance; // Now this will work
        });
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      setState(() {
        _locationDenied = true;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _locationPermanentlyDenied = true;
      });
    }
  }

  String apiUrl = '${ApiConfig.baseUrl}vendor/fetch-all-vendor-data';

  // Function to fetch vendor data
  Future<List<Map<String, dynamic>>> fetchVendors() async {
    setState(() {
      isLoading = true; // Set loading to true while fetching data
    });
    try {
      final response = await http.get(Uri.parse(apiUrl));
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['data'] != null) {
          return (jsonResponse['data'] as List).map((vendor) {
            double? latitude;
            double? longitude;

            // Attempt to parse latitude and longitude
            try {
              latitude = double.tryParse(
                vendor['latitude'] ?? '0.0',
              ); // Use '0.0' as default
              longitude = double.tryParse(
                vendor['longitude'] ?? '0.0',
              ); // Use '0.0' as default
            } catch (e) {
              print('Error parsing latitude/longitude: $e');
            }

            return {
              'id': vendor['_id'] ?? '',
              'name':
                  vendor['vendorName'] ??
                  'Unknown Vendor', // Default name if null
              'latitude': latitude ?? 0.0, // Default to 0.0 if parsing fails
              'longitude': longitude ?? 0.0, // Default to 0.0 if parsing fails
              'image': vendor['image'] ?? '', // Default to empty string if null
              'address':
                  vendor['address'] ?? 'No Address', // Default address if null
              'contactNo':
                  vendor['contactNo'] ??
                  'No Contact', // Default contact if null
              'landMark':
                  vendor['landMark'] ??
                  'No Landmark', // Default landmark if null
            };
          }).toList();
        } else {
          print('No vendor data found');
          return [];
        }
      } else {
        print('Failed to load vendors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      return [];
    } finally {
      setState(() {
        isLoading = false; // Set loading to false once the data is fetched
      });
    }
  }

  Future<void> _requestPermissionAgain() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
      setState(() {
        _locationDenied = false;
        _locationPermanentlyDenied = false;
      });
    }
  }

  Future<void> _fetchVendorData() async {
    try {
      final url =
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}';
      print('Fetching vendor data from: $url');
      final response = await http.get(Uri.parse(url));
      print('Vendor data response status: ${response.statusCode}');
      print('Vendor data response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Parsed vendor data: $data');

        if (data['data'] != null) {
          try {
            setState(() {
              _vendor = Pendor.fromJson(data['data']);
              isLoading = false;
            });
            // print('Vendor data loaded successfully: ${_vendor?.toJson()}');

            // Fetch amenities and parking
            print('Fetching amenities for vendor ID: ${_vendor!.id}');
            fetchAmenitiesAndParking(_vendor!.id)
                .then((amenitiesAndParking) {
                  setState(() {
                    amenities = amenitiesAndParking.amenities;
                    services = amenitiesAndParking.services;
                  });
                  print('Amenities loaded: $amenities');
                  print('Services loaded: $services');
                })
                .catchError((error) {
                  print('Error fetching amenities: $error');
                });
          } catch (e) {
            print('Error parsing Vendor.fromJson: $e');
            print('Vendor JSON data: ${data['data']}');
            setState(() {
              isLoading = false;
              errorMessage = 'Failed to parse vendor data: $e';
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
          'Failed to load vendor data, status code: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Exception in _fetchVendorData: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load vendor data. Please try again later.'),
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final url = '${ApiConfig.baseUrl}vendor/fetchbookid/${widget.bookingId}';
      print('Fetching booking details from: $url');
      final response = await http.get(Uri.parse(url));
      print('Booking details response status: ${response.statusCode}');
      print('Booking details response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed booking details data: $data');
        if (data['data'] != null) {
          setState(() {
            bookingDetails = data['data'];
            isLoading = false;
          });
          print('Booking details loaded successfully: $bookingDetails');
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Wrong QR code please try again';
            isLoading = false;
          });
          print('Error in booking details response: $errorMessage');
        }
      } else {
        setState(() {
          errorMessage =
              'Wrong QR code please try again (Status: ${response.statusCode})';
          isLoading = false;
        });
        print(
          'Failed to fetch booking details. Status: ${response.statusCode}',
        );
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error fetching booking details: $error';
        isLoading = false;
      });
      print('Exception in _fetchBookingDetails: $error');
    }
  }

  Future<void> _allowParking() async {
    try {
      final now = DateTime.now();
      final parkedDate = DateFormat(
        'dd-MM-yyyy',
      ).format(now); // e.g., "07-07-2025"
      final parkedTime = DateFormat('hh:mm a').format(now); // e.g., "04:54 PM"
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/qrallowpark/${widget.bookingId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'parkedDate': parkedDate, 'parkedTime': parkedTime}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'])));
        // Navigate back after successful parking
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to allow parking')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error allowing parking. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ColorUtils.secondarycolor(),

      body: SafeArea(
        child:
            errorMessage != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Invalid QrCode please try again",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 35,
                        width: 120,
                        decoration: BoxDecoration(
                          color: ColorUtils.primarycolor(),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate back to the QR code scanner page
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => qrcodeallowpark(
                                      vendorid: widget.vendorid,
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors
                                    .transparent, // Transparent to show container color
                            shadowColor:
                                Colors
                                    .transparent, // Remove button shadow (handled by boxShadow)
                            padding: EdgeInsets.zero, // Remove default padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Scanning Again',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize:
                                    12, // Adjust font size to fit height 25
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                : Column(children: [Expanded(child: _buildDetailsTab())]),
      ),
    );
  }

  Widget _buildDetailsTab() {
    print('=== Debugging Allow Parking Button ===');
    print('bookingDetails: $bookingDetails');
    print('bookingDetails status: ${bookingDetails?['status']}');
    print('bookingDetails vendorId: ${bookingDetails?['vendorId']}');
    print('widget.vendorid: ${widget.vendorid}');
    print('isTodayParking: $isTodayParking');
    print('Condition 1 (bookingDetails != null): ${bookingDetails != null}');
    print(
      'Condition 2 (status check): ${(bookingDetails != null && (bookingDetails!['status'] == 'PENDING' || bookingDetails!['status'] == 'Approved'))}',
    );
    print(
      'Condition 3 (vendorId match): ${(bookingDetails != null && bookingDetails!['vendorId'].toString() == widget.vendorid)}',
    );
    print(
      'All conditions met: ${(bookingDetails != null && (bookingDetails!['status'] == 'PENDING' || bookingDetails!['status'] == 'Approved') && bookingDetails!['vendorId'].toString() == widget.vendorid && isTodayParking)}',
    );
    print('=====================================');
    return CustomScrollView(
      slivers: [
        /*
      SliverAppBar(
        expandedHeight: 180.0,
        pinned: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_circle_left, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          _vendor?.vendorName ?? '',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 3,
                color: Colors.black.withOpacity(0.7),
              ),
            ],
          ),
        ),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax, // smooth scroll effect
          background: Stack(
            fit: StackFit.expand,
            children: [
              // --- Image Background ---
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: Image.network(
                  _vendor?.image ?? '',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: LoadingAnimationWidget.halfTriangleDot(
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: ColorUtils.primarycolor(),
                      child: const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 40),
                      ),
                    );
                  },
                ),
              ),

              // --- Gradient Overlay (for better text contrast) ---
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      */
        SliverAppBar(
          pinned: true,
          backgroundColor: ColorUtils.primarycolor(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Scanning Results',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_vendor != null) ...[


                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Builder(
                        builder: (context) {
                          final parkedDate =
                              bookingDetails?['parkedDate'] ??
                              bookingDetails?['parkingDate'] ??
                              '';
                          final parkedTime =
                              bookingDetails?['parkedTime'] ??
                              bookingDetails?['parkingTime'] ??
                              '';
                          DateTime parsedDate = DateTime.now();
                          if (parkedDate.isNotEmpty && parkedTime.isNotEmpty) {
                            try {
                              parsedDate =
                                  UniversalPrintHelper.tryParseDateTime(
                                    date: parkedDate,
                                    time: parkedTime,
                                  ) ??
                                  DateTime.now();
                            } catch (e) {}
                          }
                          var duration = DateTime.now().difference(parsedDate);
                          if (duration.isNegative) duration = Duration.zero;

                          String twoDigits(int n) =>
                              n.toString().padLeft(2, "0");
                          String formattedDuration =
                              "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";

                          String daySuffix(int day) {
                            if (day >= 11 && day <= 13) return 'th';
                            switch (day % 10) {
                              case 1:
                                return 'st';
                              case 2:
                                return 'nd';
                              case 3:
                                return 'rd';
                              default:
                                return 'th';
                            }
                          }

                          const monthNames = [
                            "",
                            "January",
                            "February",
                            "March",
                            "April",
                            "May",
                            "June",
                            "July",
                            "August",
                            "September",
                            "October",
                            "November",
                            "December",
                          ];
                          String hourStr =
                              parsedDate.hour > 12
                                  ? (parsedDate.hour - 12).toString().padLeft(
                                    2,
                                    '0',
                                  )
                                  : (parsedDate.hour == 0
                                      ? '12'
                                      : parsedDate.hour.toString().padLeft(
                                        2,
                                        '0',
                                      ));
                          String minuteStr = parsedDate.minute
                              .toString()
                              .padLeft(2, '0');
                          String period = parsedDate.hour >= 12 ? 'PM' : 'AM';
                          String formattedDate =
                              "${parsedDate.day}${daySuffix(parsedDate.day)} ${monthNames[parsedDate.month]} ${parsedDate.year}, $hourStr:$minuteStr $period";

                          return Column(
                            children: [
                              SizedBox(
                                height: 100,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 30,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: ColorUtils.primarycolor(),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(30),
                                            bottomRight: Radius.circular(30),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              spreadRadius: 1,
                                              blurRadius: 2,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.all(5.0),
                                          child: Text(
                                            'Booking on : $formattedDate',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(5),
                                                  topRight: Radius.circular(5),
                                                  bottomLeft: Radius.circular(
                                                    20,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    20,
                                                  ),
                                                ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                spreadRadius: 1,
                                                blurRadius: 2,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.only(
                                                  left: 14,
                                                  top: 2,
                                                  right: 0.0,
                                                  bottom: 0.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          ColorUtils.primarycolor(),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(
                                                              5.0,
                                                            ),
                                                        topRight:
                                                            Radius.circular(
                                                              5.0,
                                                            ),
                                                      ),
                                                  color: Colors.grey[200],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      bookingDetails?['vehicleNumber'] ??
                                                          'Unknown',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        color:
                                                            ColorUtils.primarycolor(),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 0),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          5.0,
                                                        ),
                                                    child: Container(
                                                      height: 40,
                                                      width: 40,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            ColorUtils.primarycolor(),
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                20,
                                                              ),
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.directions_car,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      RichText(
                                                        text: TextSpan(
                                                          text:
                                                              'Parking Schedule: ',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors
                                                                        .black,
                                                              ),
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  '${bookingDetails?['parkingDate'] ?? ''} ${bookingDetails?['parkingTime'] ?? ''}',
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color:
                                                                    Colors
                                                                        .black,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      RichText(
                                                        text: TextSpan(
                                                          text:
                                                              'Payable Time: ',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    Colors
                                                                        .black,
                                                              ),
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  formattedDuration,
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color:
                                                                    Colors
                                                                        .black,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              if (bookingDetails != null &&
                                  bookingDetails!['status'] == 'PARKED' &&
                                  bookingDetails!['vendorId'].toString() ==
                                      widget.vendorid)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    left: 10,
                                    right: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (bookingDetails!['sts']?.toString() ==
                                          'Instant')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 15,
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                _isExiting
                                                    ? null
                                                    : () => _handlePrintAndExit(
                                                      bookingDetails!,
                                                    ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  ColorUtils.primarycolor(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 18,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                      Radius.circular(5),
                                                    ),
                                                side: BorderSide(
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_isExiting)
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            ColorUtils.primarycolor(),
                                                          ),
                                                    ),
                                                  )
                                                else
                                                  const Icon(
                                                    Icons.check_circle_outline,
                                                    color: Colors.black,
                                                    size: 24,
                                                  ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  _isExiting
                                                      ? 'Processing...'
                                                      : 'Print & Exit',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        ColorUtils.primarycolor(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 15,
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                              (_isCheckingExit || _isExiting)
                                                  ? null
                                                  : () =>
                                                      _handleExitButtonPressed(
                                                        bookingDetails!,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  const BorderRadius.all(
                                                    Radius.circular(5),
                                                  ),
                                              side: BorderSide(
                                                color:
                                                    ColorUtils.primarycolor(),
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (_isCheckingExit)
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          ColorUtils.primarycolor(),
                                                        ),
                                                  ),
                                                )
                                              else
                                                const Icon(
                                                  Icons.qr_code_scanner,
                                                  color: Colors.green,
                                                  size: 24,
                                                ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _isCheckingExit
                                                    ? 'Checking...'
                                                    : 'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final String bId =
                                              bookingDetails!['_id']
                                                  ?.toString() ??
                                              '';
                                          if (bId.isEmpty) return;
                                          String currentAmount = '0';
                                          try {
                                            currentAmount =
                                                await UniversalPrintHelper.getPrintAmountFromAPI(
                                                  bId,
                                                );
                                          } catch (_) {}
                                          await UniversalPrintHelper.printTicket(
                                            context: context,
                                            vendorName:
                                                bookingDetails!['vendorName'] ??
                                                'Vendor',
                                            bookingId: bId,
                                            invoiceId:
                                                bookingDetails!['invoiceId']
                                                    ?.toString(),
                                            vehicleType:
                                                bookingDetails!['vehicleType'] ??
                                                '',
                                            vehicleNumber:
                                                bookingDetails!['vehicleNumber'] ??
                                                '',
                                            parkingDate:
                                                bookingDetails!['parkingDate'] ??
                                                '',
                                            parkingTime:
                                                bookingDetails!['parkingTime'] ??
                                                '',
                                            amount: currentAmount,
                                            personName:
                                                bookingDetails!['userName'] ??
                                                bookingDetails!['personName'] ??
                                                '',
                                            valetCharge:
                                                double.tryParse(
                                                  bookingDetails!['valetCharge']
                                                          ?.toString() ??
                                                      '0',
                                                ) ??
                                                0.0,
                                            mobileNumber:
                                                bookingDetails!['mobileNumber'] ??
                                                '',
                                            vendorId:
                                                bookingDetails!['vendorId']
                                                    ?.toString() ??
                                                widget.vendorid,
                                            bookType:
                                                bookingDetails!['bookingType'] ??
                                                bookingDetails!['bookType'] ??
                                                '',
                                            sts:
                                                bookingDetails!['sts']
                                                    ?.toString() ??
                                                '',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              ColorUtils.primarycolor(),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                const BorderRadius.all(
                                                  Radius.circular(5),
                                                ),
                                            side: BorderSide(
                                              color: ColorUtils.primarycolor(),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.print,
                                              color: Colors.black,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Print',
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    ColorUtils.primarycolor(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: Column(
                        children: [
                          /*
                        const SizedBox(height: 15),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white, // Move color inside decoration
                            borderRadius: BorderRadius.circular(5), // Set border radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          // color: Colors.white,
                          child: Column(
                            children: [
                              const SizedBox(height: 5),
                              Container(
                                color: Colors.white,
                                child: Align(
                                  alignment: Alignment.center, // Aligns content to the left
                                  child: Text(
                                    "Price details",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      // decoration: TextDecoration.underline, // Add underline here
                                      decorationColor: Colors.black, // Optional: Set the color of the underline
                                      // Optional: Set the thickness of the underline
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                thickness: 0.5, // Set the thickness of the divider
                                color: ColorUtils.primarycolor(), // Set the color of the divider
                              ),
                              // const SizedBox(height: 2),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white, // Move color inside decoration
                                  borderRadius: BorderRadius.circular(5), // Set border radius
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal, // Enable horizontal scrolling
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center, // Center items inside Row
                                      children: List.generate(charges.length, (index) {
                                        var charge = charges[index];
                                        return Row(
                                          children: [
                                            Container(
                                              width: 85, // Set width for each item
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 6, horizontal: 4), // Reduce vertical padding
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    charge['type'],
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 1), // Reduce space between text
                                                  Text(
                                                    "₹${charge['amount']}",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.black,
                                                      fontSize: 14,
                                                      height: 1.2, // Reduce line spacing
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (index < charges.length - 1)
                                              const SizedBox(
                                                width: 16, // Reduce spacing between items
                                                height: 35, // Set height to match container's height
                                                child: VerticalDivider(
                                                  color: Colors.grey,
                                                  thickness: 0.5,
                                                  width: 8, // Reduce space between items
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
      */
                          const SizedBox(height: 8),
                          if (amenities.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    Colors
                                        .white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(
                                  5,
                                ), // Set border radius
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 5),
                                  Container(
                                    color: Colors.white,
                                    child: Align(
                                      alignment:
                                          Alignment
                                              .center, // Aligns content to the left
                                      child: Text(
                                        "Facilities",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // decoration: TextDecoration.underline, // Add underline here
                                          decorationColor:
                                              Colors
                                                  .black, // Optional: Set the color of the underline
                                          // Optional: Set the thickness of the underline
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness:
                                        0.5, // Set the thickness of the divider
                                    color:
                                        ColorUtils.primarycolor(), // Set the color of the divider
                                  ),
                                  //
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
                                    child: Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children:
                                          amenities.map((amenity) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                // color:  ColorUtils.primarycolor() ,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: Border.all(
                                                  color:
                                                      Colors
                                                          .black, // Set the color of the border
                                                  width:
                                                      0.5, // Set the width of the border
                                                ),
                                                boxShadow: const [
                                                  // BoxShadow(
                                                  //   color: Colors.black26,
                                                  //   blurRadius: 4.0,
                                                  //   offset: Offset(0, 2),
                                                  // ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getAmenityIcon(amenity),
                                                    size: 12,
                                                    color: Colors.black,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    amenity,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                      // fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (services.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    Colors
                                        .white, // Move color inside decoration
                                borderRadius: BorderRadius.circular(
                                  5,
                                ), // Set border radius
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    color: Colors.white,
                                    child: Align(
                                      alignment:
                                          Alignment
                                              .center, // Aligns content to the left
                                      child: Text(
                                        "Additional Services",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          // decoration: TextDecoration.underline, // Add underline here
                                          decorationColor:
                                              Colors
                                                  .black, // Optional: Set the color of the underline
                                          // Optional: Set the thickness of the underline
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    thickness:
                                        0.5, // Set the thickness of the divider
                                    color:
                                        ColorUtils.primarycolor(), // Set the color of the divider
                                  ),
                                  const SizedBox(height: 8),
                                  // Heading Card

                                  // Loop through the services list
                                  Wrap(
                                    spacing: 6.0,
                                    runSpacing: 6.0,
                                    children:
                                        services.asMap().entries.map((entry) {
                                          final s = entry.value;

                                          return Container(
                                            // width: 100, // Adjust width as needed
                                            padding: const EdgeInsets.all(5.0),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  s.type,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  softWrap: true,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  ": ₹${s.amount}",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),

                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ],
                          // Google Map removed as per request
                          const SizedBox(height: 10),

                          // Parse booking parking date (adjust format if needed)
                          if (bookingDetails != null &&
                              (bookingDetails!['status'] == 'PENDING' ||
                                  bookingDetails!['status'] == 'Approved') &&
                              bookingDetails!['vendorId'].toString() ==
                                  widget.vendorid &&
                              isTodayParking)
                            Align(
                              alignment: Alignment.centerRight,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await _allowParking();
                                  },
                                  label: Text(
                                    'Allow Parking',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorUtils.primarycolor(),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 3,
                                    shadowColor: Colors.green.withOpacity(0.3),
                                    animationDuration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    enableFeedback: true,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: const Size(120, 20),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _setExiting(bool isExiting) {
    if (!mounted) return;
    setState(() {
      _isExiting = isExiting;
    });
  }

  Future<void> _handleExitButtonPressed(Map<String, dynamic> vehicle) async {
    if (!mounted) return;
    if (_isCheckingExit || _isExiting) return;

    setState(() => _isCheckingExit = true);
    try {
      String amountStr = '0';
      try {
        amountStr = await UniversalPrintHelper.getPrintAmountFromAPI(
          vehicle['_id']?.toString() ?? '',
        ).timeout(_apiTimeout);
      } catch (_) {}

      final amountVal = double.tryParse(amountStr.trim()) ?? 0.0;
      if (!mounted) return;

      if (amountVal <= 0) {
        setState(() => _isCheckingExit = false);
        await _performQuickExit(vehicle, '0');
      } else {
        setState(() => _isCheckingExit = false);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return DraggableScrollableSheet(
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Exitpage(
                    currentTabIndex: 0,
                    userid: vehicle['userId']?.toString() ?? '',
                    otp: vehicle['otp']?.toString() ?? '',
                    vehicletype: vehicle['vehicleType']?.toString() ?? '',
                    bookingid: vehicle['_id']?.toString() ?? '',
                    parkingdate: vehicle['parkingDate']?.toString() ?? '',
                    vehiclenumber: vehicle['vehicleNumber']?.toString() ?? '',
                    username: vehicle['userName']?.toString() ?? '',
                    phoneno: vehicle['mobileNumber']?.toString() ?? '',
                    parkingtime: vehicle['parkingTime']?.toString() ?? '',
                    bookingtypetemporary: vehicle['status']?.toString() ?? '',
                    sts: vehicle['sts']?.toString() ?? '',
                    cartype: vehicle['carType']?.toString() ?? '',
                    vendorid:
                        vehicle['vendorId']?.toString() ?? widget.vendorid,
                    bookType: vehicle['bookingType']?.toString() ?? '',
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingExit = false);
      print('Exit check error: $e');
    }
  }

  Future<void> _handlePrintAndExit(Map<String, dynamic> vehicle) async {
    final String bookingId = vehicle['_id']?.toString() ?? '';
    if (bookingId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Booking ID not found')),
        );
      }
      return;
    }

    _setExiting(true);
    try {
      String currentAmount;
      try {
        currentAmount = await UniversalPrintHelper.getPrintAmountFromAPI(
          bookingId,
        ).timeout(_apiTimeout);
      } catch (e) {
        currentAmount = '0';
      }

      if (!mounted) return;
      try {
        await UniversalPrintHelper.printTicket(
          context: context,
          vendorName: vehicle['vendorName'] ?? 'Vendor',
          bookingId: bookingId,
          invoiceId: vehicle['invoiceId']?.toString(),
          vehicleType: vehicle['vehicleType'] ?? '',
          vehicleNumber: vehicle['vehicleNumber'] ?? '',
          parkingDate: vehicle['parkingDate'] ?? '',
          parkingTime: vehicle['parkingTime'] ?? '',
          amount: currentAmount,
          personName: vehicle['userName'] ?? vehicle['personName'] ?? '',
          valetCharge:
              double.tryParse(vehicle['valetCharge']?.toString() ?? '0') ?? 0.0,
          mobileNumber: vehicle['mobileNumber'] ?? '',
          vendorId: vehicle['vendorId']?.toString() ?? widget.vendorid,
          bookType: vehicle['bookingType'] ?? vehicle['bookType'] ?? '',
          sts: vehicle['sts']?.toString() ?? '',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Print failed. Continuing with exit...'),
            ),
          );
        }
      }

      await _performQuickExit(vehicle, currentAmount, manageLoading: false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => vendorChooseParkingPage(vendorid: widget.vendorid),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exit failed: $msg')));
      }
    } finally {
      _setExiting(false);
    }
  }

  Future<void> _performQuickExit(
    Map<String, dynamic> vehicle,
    String amount, {
    bool manageLoading = true,
  }) async {
    final String bookingId = vehicle['_id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    if (manageLoading) _setExiting(true);

    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId',
      );
      final parkedDate = vehicle['parkingDate'] ?? '';
      final parkedTime = vehicle['parkingTime'] ?? '';

      final parkedDateTime =
          UniversalPrintHelper.tryParseDateTime(
            date: parkedDate,
            time: parkedTime,
          ) ??
          DateTime.now();

      var duration = DateTime.now().difference(parkedDateTime);
      if (duration.isNegative) duration = Duration.zero;
      final formattedDuration = _formatDuration(duration);

      final parkingCharge = double.tryParse(amount.trim()) ?? 0.0;
      final Map<String, dynamic> requestBody = {
        'amount': parkingCharge,
        'hour': formattedDuration,
        'paymentMode': 'Cash',
      };

      final userId = (vehicle['userId'] ?? '').toString().trim();
      if (userId.isNotEmpty) {
        try {
          final gstData = await _fetchGstFeeForExit().timeout(_apiTimeout);
          final gstPercentage =
              double.tryParse(gstData['gst']?.toString() ?? '0') ?? 0.0;
          final handlingFeeAmount =
              double.tryParse(gstData['handlingfee']?.toString() ?? '0') ?? 0.0;
          final gstBase = parkingCharge + handlingFeeAmount;
          final gstAmount = (gstBase * gstPercentage) / 100;
          final exactTotal = parkingCharge + handlingFeeAmount + gstAmount;
          final finalTotal = _roundUpToNearestRupeeForExit(exactTotal);
          requestBody['gstamout'] = gstAmount;
          requestBody['handlingfee'] = handlingFeeAmount;
          requestBody['totalamout'] = finalTotal;
        } catch (e) {
          print('GST fetch failed: $e');
        }
      }

      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_exitApiTimeout);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle exited successfully (Cash)!'),
            ),
          );
          _fetchBookingDetails(); // Refresh details
        }
      } else {
        String errMsg = 'Failed to exit vehicle (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? data['error'] ?? errMsg;
        } catch (_) {}
        throw Exception(errMsg);
      }
    } finally {
      if (manageLoading) _setExiting(false);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<Map<String, dynamic>> _fetchGstFeeForExit() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}vendor/getgstfee'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty && data[0] is Map) {
        return Map<String, dynamic>.from(data[0] as Map);
      }
      return {'gst': '0', 'handlingfee': '0'};
    }
    throw Exception('Failed to load GST fees');
  }

  double _roundUpToNearestRupeeForExit(double amount) {
    final double decimal = amount - amount.floor();
    return decimal >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
  }
}

class Pendor {
  final String status;
  final String id;
  final String vendorName;
  final List<Contact> contacts;
  final String latitude;
  final String longitude;
  final String address;
  final String landMark;
  final String image;
  double? distance;
  final List<ParkingEntry> parkingEntries;

  Pendor({
    required this.status,
    required this.id,
    required this.vendorName,
    required this.contacts,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.landMark,
    required this.image,
    required this.parkingEntries,
    this.distance,
  });

  Pendor copyWith({
    String? status,
    String? id,
    String? vendorName,
    String? address,
    String? landMark,
    String? image,
    String? latitude,
    String? longitude,
    List<Contact>? contacts,
    List<ParkingEntry>? parkingEntries,
    double? distance,
  }) {
    return Pendor(
      status: status ?? this.status,
      id: id ?? this.id,
      vendorName: vendorName ?? this.vendorName,
      address: address ?? this.address,
      landMark: landMark ?? this.landMark,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contacts: contacts ?? this.contacts,
      parkingEntries: parkingEntries ?? this.parkingEntries,
      distance: distance ?? this.distance,
    );
  }

  factory Pendor.fromJson(Map<String, dynamic> json) {
    return Pendor(
      status: json['status']?.toString() ?? 'active', // Default status
      id: json['_id']?.toString() ?? '', // Handle null ID
      vendorName: json['vendorName']?.toString() ?? 'Unknown Vendor',
      contacts:
          (json['contacts'] as List<dynamic>? ?? [])
              .map((contactJson) => Contact.fromJson(contactJson))
              .toList(),
      latitude: json['latitude']?.toString() ?? '0.0', // Default latitude
      longitude: json['longitude']?.toString() ?? '0.0', // Default longitude
      address: json['address']?.toString() ?? 'No Address',
      landMark: json['landMark']?.toString() ?? 'No Landmark',
      image: json['image']?.toString() ?? '', // Default empty image
      parkingEntries:
          (json['parkingEntries'] as List<dynamic>? ?? [])
              .map(
                (parkingEntryJson) => ParkingEntry.fromJson(parkingEntryJson),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      '_id': id,
      'vendorName': vendorName,
      'contacts': contacts.map((contact) => contact.toJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'landMark': landMark,
      'image': image,
      // 'parkingEntries': parkingEntries.map((entry) => entry.toJson()).toList(),
    };
  }
}

class Contact {
  final String name;
  final String mobile;

  Contact({required this.name, required this.mobile});

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      name: json['name']?.toString() ?? 'Unknown', // Handle null name
      mobile: json['mobile']?.toString() ?? '', // Handle null mobile
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'mobile': mobile};
  }
}
