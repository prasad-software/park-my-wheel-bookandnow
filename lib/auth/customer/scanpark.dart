import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mywheels/auth/customer/addcarviewcar/mycars.dart';
import 'package:mywheels/auth/customer/customerdash.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/customer/bottom.dart';
import 'package:mywheels/auth/customer/customerprofile.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/dummy.dart';
import 'package:mywheels/explorebooknow.dart';
import 'package:mywheels/model/user.dart';
import 'package:permission_handler/permission_handler.dart';
import 'drawer/Searchscreen.dart';
import 'drawer/customdrawer.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class scanpark extends StatefulWidget {
  final String userId;
  const scanpark({super.key, required this.userId});

  @override
  _ScanParkState createState() => _ScanParkState();
}

class _ScanParkState extends State<scanpark> with WidgetsBindingObserver, RouteAware {
  int _selectedIndex = 2;
  bool _isSlotListingExpanded = false;
  User? _user;
  bool _isLoading = true;
  bool isCameraPermissionGranted = false;

  bool _isControllerInitialized = false;
  bool _isDisposed = false;
  bool _isPermanentlyDenied = false;

  String qrCodeResult = "No QR code scanned yet";
  late MobileScannerController cameraController;
  final TextEditingController dateTimeController = TextEditingController();
  bool isScannerRunning = true;
  String? selectedCarType;
  Barcode? _barcode;



  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    print('initState: Initializing ScanParkState');
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();

    _pages.addAll([
      customdashScreen(userId: widget.userId),
      CarPage(userId: widget.userId),
      scanpark(userId: widget.userId),
      ParkingPage(userId: widget.userId),
      CProfilePage(userId: widget.userId),
    ]);

    cameraController = MobileScannerController();
    print('initState: MobileScannerController created');
    _checkPermissionStatus();
    _initializeCamera();
  }
  Future<void> _checkPermissionStatus() async {
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        setState(() {
          isCameraPermissionGranted = true;
        });
        await _startScanner();
      } else {
        await requestCameraPermission();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isControllerInitialized = true;
        });
      }
    }
  }

  Future<void> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isDenied) {
      final shouldRequest = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('MyWheels needs camera access to scan QR codes'),
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
        final permissionStatus = await Permission.camera.status; // Fetch status asynchronously
        setState(() {
          isCameraPermissionGranted = false;
          _isPermanentlyDenied = permissionStatus.isPermanentlyDenied;
        });
        return;
      }
    }

    final newStatus = await Permission.camera.request();
    setState(() {
      isCameraPermissionGranted = newStatus.isGranted;
      _isPermanentlyDenied = newStatus.isPermanentlyDenied;
    });

    if (newStatus.isGranted && !_isDisposed) {
      await _startScanner();
    } else if (newStatus.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('Please enable camera access in app settings'),
          actions: [
            ElevatedButton(
              onPressed: openAppSettings,
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
  Future<void> _startScanner() async {
    if (_isDisposed || !_isControllerInitialized) return;

    try {
      await cameraController.start();
      if (!_isDisposed && mounted) {
        setState(() {
          isScannerRunning = true;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          isScannerRunning = false;
          _isControllerInitialized = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start camera: $e')),
        );
        // Retry after a delay
        await Future.delayed(const Duration(seconds: 2));
        if (!_isDisposed && mounted && isCameraPermissionGranted) {
          await _startScanner();
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    cameraController.stop();
    cameraController.dispose();
    dateTimeController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() async {
    if (!isScannerRunning && isCameraPermissionGranted && !_isDisposed) {
      await _startScanner();
      if (mounted) {
        setState(() {
          isScannerRunning = true;
          qrCodeResult = "No QR code scanned yet";
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isCameraPermissionGranted || _isDisposed) return;

    if (state == AppLifecycleState.resumed) {
      _startScanner();
    } else if (state == AppLifecycleState.paused) {
      cameraController.stop();
    }
  }

  void _toggleFlashlight() {
    print('_toggleFlashlight: Attempting to toggle flashlight');
    if (isCameraPermissionGranted && _isControllerInitialized) {
      try {
        print('_toggleFlashlight: Toggling torch');
        cameraController.toggleTorch();
        print('_toggleFlashlight: Torch toggled successfully');
      } catch (e) {
        print('_toggleFlashlight: Failed to toggle flashlight - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to toggle flashlight: $e')),
          );
        }
      }
    } else {
      print('_toggleFlashlight: Cannot toggle flashlight - isCameraPermissionGranted: $isCameraPermissionGranted, _isControllerInitialized: $_isControllerInitialized');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not initialized or permission not granted')),
        );
      }
    }
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

      final vendorName = parsedData['vendorName']?.toString();
      final vendorId = parsedData['vendorId']?.toString();

      if (vendorName != null && vendorId != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => liveExploreBook(
              selectedOption: "Instant",
              vendorName: vendorName,
              userId: widget.userId,
              vendorId: vendorId,
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
        if (mounted) {
          setState(() {
            isScannerRunning = true;
          });
        }
      }
    }
  }

  Future<void> _fetchUserData() async {
    print('_fetchUserData: Fetching user data for userId: ${widget.userId}');
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));
      print('_fetchUserData: HTTP response status - ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('_fetchUserData: Response data - $data');
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            print('_fetchUserData: User data loaded - ${_user?.username}');
          });
        }
      }
    } catch (e) {
      print('_fetchUserData: Failed to load user data - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
    }
  }

  void _handleTabChange(int index) {
    print('_handleTabChange: Changing tab to index $index');
    setState(() =>47);
    _selectedIndex = index;
    print('_handleTabChange: _selectedIndex set to $_selectedIndex');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _pages[index]));
    print('_handleTabChange: Navigated to page at index $index');
  }

  Widget _buildScannerBody() {
    print('_buildScannerBody: Building scanner body, _isLoading: $_isLoading');
    if (_isLoading) {
      print('_buildScannerBody: Showing loading indicator');
      return const Center(child: CircularProgressIndicator());
    }

    if (!isCameraPermissionGranted || !_isControllerInitialized) {
      print('_buildScannerBody: Camera permission not granted or controller not initialized');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Camera access is required to scan QR codes', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print('_buildScannerBody: Grant Camera Permission button pressed');
                requestCameraPermission();
              },
              child: const Text('Grant Camera Permission'),
            ),
            TextButton(
              onPressed: () {
                print('_buildScannerBody: Open Settings button pressed');
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    print('_buildScannerBody: Rendering MobileScanner widget');
    return MobileScanner(
      controller: cameraController,
      onDetect: _handleBarcode,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('build: Building ScanPark widget');
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        title: Text('Scan & Park', style: GoogleFonts.poppins(color: Colors.black, fontSize: 18)),
        // backgroundColor: ColorUtils.primarycolor(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              print('build: Search icon pressed, navigating to SearchScreen');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    userid: widget.userId,
                    title: "Search Parking",
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isControllerInitialized && cameraController.torchEnabled
                  ? Icons.flash_on
                  : Icons.flash_off,
              color: Colors.black,
            ),
            onPressed: () {
              print('build: Flashlight icon pressed');
              _toggleFlashlight();
            },
          ),
        ],
      ),
      drawer: CustomDrawer(
        userid: widget.userId,
        imageUrl: _user?.imageUrl ?? '',
        username: _user?.username ?? '',
        mobileNumber: _user?.mobileNumber ?? '',
        onLogout: () {
          print('build: Logout triggered from CustomDrawer');
        },
        isSlotListingExpanded: _isSlotListingExpanded,
        onSlotListingToggle: () {
          print('build: Toggling slot listing in CustomDrawer');
          setState(() => _isSlotListingExpanded = !_isSlotListingExpanded);
          print('build: _isSlotListingExpanded set to $_isSlotListingExpanded');
        },
      ),
      body: SafeArea(
        child: _buildScannerBody(),
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: _handleTabChange,
      ),
    );
  }
}