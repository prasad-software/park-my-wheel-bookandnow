import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // For image processing and custom markers
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mywheels/pageloader.dart';
import 'dart:typed_data';

import '../../../config/authconfig.dart';

class ExplorePage extends StatefulWidget {
  final LatLng? initialPosition;
  final String userid;

  const ExplorePage({super.key, this.initialPosition, required this.userid});

  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  LatLng _center = const LatLng(12.9716, 77.5946); // Default Bangalore coordinates
  GoogleMapController? _mapController;
  String address = '';
  bool isLoading = true;
  List<Map<String, dynamic>> vendors = [];
  final Set<Marker> _markers = {};
  double _tilt = 85.0;
  double _bearing = 30.0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _requestPermission();
    _getCurrentLocation();
  }

  void _initializeControllers() {
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
  }

  Future<void> _getCurrentLocation() async {
    print('Getting current location...');
    final stopwatch = Stopwatch()..start();

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print('Current location fetched: ${stopwatch.elapsedMilliseconds} ms');
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
          _updateAddress(_center);
        } else {
          print('Map controller not initialized yet');
        }
      });

      vendors = await fetchVendors();
      await _loadVendorMarkers();
    } catch (e) {
      print('Error fetching location: $e');
    } finally {
      setState(() {
        isLoading = false;
        print('Loading complete: ${stopwatch.elapsedMilliseconds} ms');
      });
    }
  }

  String apiUrl = '${ApiConfig.baseUrl}vendor/fetchvisible';

  Future<List<Map<String, dynamic>>> fetchVendors() async {
    print('Fetching vendors from API...');
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));
      print('API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('API response body: $jsonResponse');

        if (jsonResponse is Map && jsonResponse.containsKey('data') && jsonResponse['data'] is List && jsonResponse['data'].isNotEmpty) {
          List<Map<String, dynamic>> vendorsList = (jsonResponse['data'] as List)
              .map((vendor) {
            double latitude = 0.0;
            double longitude = 0.0;

            try {
              latitude = double.parse(vendor['latitude']?.toString() ?? '');
            } catch (_) {
              print('Invalid/missing latitude for vendor: ${vendor['vendorName']}, using 0.0');
            }

            try {
              longitude = double.parse(vendor['longitude']?.toString() ?? '');
            } catch (_) {
              print('Invalid/missing longitude for vendor: ${vendor['vendorName']}, using 0.0');
            }

            return {
              'name': vendor['vendorName'] ?? 'Unknown Vendor',
              'latitude': latitude,
              'longitude': longitude,
              'image': vendor['image'] ?? '',
              'address': vendor['address'] ?? '',
              'contactNo': vendor['contactNo'] ?? '',
            };
          })
              .toList();

          print('Fetched ${vendorsList.length} vendors in ${stopwatch.elapsedMilliseconds} ms');
          return vendorsList;
        } else {
          print('No vendor data found in response, returning fallback vendors');
          return getFallbackVendors();
        }
      } else {
        print('Failed to load vendors, status code: ${response.statusCode}');
        throw Exception('Failed to load vendors');
      }
    } catch (e) {
      print('Error fetching vendors: $e, returning fallback vendors');
      return getFallbackVendors();
    }
  }

  List<Map<String, dynamic>> getFallbackVendors() {
    return [
      {
        'name': 'Fallback Parking Lot 1',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'image': 'https://via.placeholder.com/150', // Placeholder image
        'address': 'MG Road, Bangalore',
        'contactNo': '9999999991',
      },
      {
        'name': 'Fallback Parking Lot 2',
        'latitude': 13.0350,
        'longitude': 77.5970,
        'image': 'https://via.placeholder.com/150',
        'address': 'Indiranagar, Bangalore',
        'contactNo': '9999999992',
      },
    ];
  }

  Future<void> _loadVendorMarkers() async {
    print('Loading vendor markers...');
    const batchSize = 5;
    for (var i = 0; i < vendors.length; i += batchSize) {
      final batch = vendors.sublist(i, min(i + batchSize, vendors.length));
      await Future.wait(batch.map((vendor) => _createVendorMarker(vendor)));
    }
  }

  Future<void> _createVendorMarker(Map<String, dynamic> vendor) async {
    try {
      final icon = await _getMarkerIcon(vendor['image']);
      final marker = Marker(
        markerId: MarkerId(vendor['name']),
        position: LatLng(vendor['latitude'], vendor['longitude']),
        icon: icon,
        infoWindow: InfoWindow(
          title: vendor['name'],
          snippet: vendor['address'],
        ),
      );

      setState(() {
        _markers.add(marker);
      });
    } catch (error) {
      print('Error creating marker for vendor ${vendor['name']}: $error');
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 5));
      print('Fetching marker icon from $imageUrl...');
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        img.Image? originalImage = img.decodeImage(bytes);
        if (originalImage != null) {
          img.Image resizedImage = img.copyResize(originalImage, width: 70, height: 70);

          final Uint8List resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));
          final ui.Codec codec = await ui.instantiateImageCodec(resizedBytes, targetWidth: 70);
          final ui.FrameInfo fi = await codec.getNextFrame();

          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final Canvas canvas = Canvas(recorder);
          final Paint paint = Paint()..color = Colors.green;

          const double width = 110;
          const double height = 140;
          const double circleSize = 80;

          final Path pinPath = Path()
            ..addRRect(RRect.fromRectAndRadius(
                const Rect.fromLTWH(10, 10, width - 20, height - 30),
                const Radius.circular(50)))
            ..moveTo(width / 2 - 15, height - 30)
            ..lineTo(width / 2, height - 10)
            ..lineTo(width / 2 + 15, height - 30)
            ..close();

          canvas.drawPath(pinPath, paint);
          final Rect imageRect = Rect.fromCircle(center: const Offset(width / 2, 50), radius: circleSize / 2);
          canvas.drawCircle(imageRect.center, circleSize / 2 + 2, Paint()..color = Colors.black);

          final Paint imagePaint = Paint()..isAntiAlias = true..filterQuality = FilterQuality.high;
          final Path clipPath = Path()..addOval(imageRect);
          canvas.clipPath(clipPath);
          final Rect srcRect = Rect.fromLTRB(0, 0, fi.image.width.toDouble(), fi.image.height.toDouble());
          canvas.drawImageRect(fi.image, srcRect, imageRect, imagePaint);

          final ui.Image markerImage = await recorder.endRecording().toImage(width.toInt(), height.toInt());
          final ByteData? byteData = await markerImage.toByteData(format: ui.ImageByteFormat.png);
          final Uint8List uint8list = byteData!.buffer.asUint8List();

          return BitmapDescriptor.fromBytes(uint8list);
        }
      }
    } catch (e) {
      print("Error loading marker image: $e");
    }
    return BitmapDescriptor.defaultMarker;
  }

  void _updateAddress(LatLng position) async {
    print('Updating address for position: ${position.latitude}, ${position.longitude}');
    setState(() {
      address = 'Fetching address...';
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          address = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.postalCode ?? ''}';
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
  }

  Future<void> _requestPermission() async {
    print('Requesting location permission...');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: const Text('Location permission is required for this feature. Please enable it in the app settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: const Text(
          'Explore Parking Space(s)',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
              print('Search clicked');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const LoadingGif()
            : Column(
          children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (widget.initialPosition != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(widget.initialPosition!));
                } else {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
                }
              },
              myLocationEnabled: true,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 18.0,
                tilt: _tilt,
                bearing: _bearing,
              ),
              onCameraMove: (position) {
                setState(() {
                  _tilt = position.tilt;
                  _bearing = position.bearing;
                });
                _updateAddress(position.target);
              },
              markers: _markers,
            ),
          ),

        ],
      ),),
    );
  }
}