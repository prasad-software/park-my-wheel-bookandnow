import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/dummy.dart';
import 'package:mywheels/explorebooknow.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ScannerPage extends StatefulWidget {
  final String userId;
  const ScannerPage({super.key, required this.userId});

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with RouteAware, WidgetsBindingObserver {
  bool isCameraPermissionGranted = false;
  String qrCodeResult = "No QR code scanned yet";
  late MobileScannerController cameraController;
  final TextEditingController dateTimeController = TextEditingController();
  bool isScannerRunning = true;
  String? selectedCarType;
  Barcode? _barcode;
  final bool _isSlotListingExpanded = false;
  bool _isLoading = true;
  bool _isControllerInitialized = false;
  bool _isDisposed = false;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController = MobileScannerController();
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
        const SnackBar(content: Text('Camera not initialized or permission not granted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building ScannerPage: isCameraPermissionGranted=$isCameraPermissionGranted, _isControllerInitialized=$_isControllerInitialized, _isLoading=$_isLoading');
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.6),
                spreadRadius: 12,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: ColorUtils.primarycolor(),
            title: const Text(
              'Scan QR',
              style: TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(
                  _isControllerInitialized && cameraController.torchEnabled
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: _toggleFlashlight,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (isCameraPermissionGranted && _isControllerInitialized)
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
      ),);
  }
}