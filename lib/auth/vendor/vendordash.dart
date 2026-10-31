import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mywheels/auth/customer/parking/parkindetails.dart';
import 'package:mywheels/auth/vendor/paytimeamount.dart';
import 'package:flutter/material.dart';
import 'package:mywheels/auth/vendor/bookings.dart';
import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'package:mywheels/auth/vendor/subscription/addsubscribe.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/flashbarvendor.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdbottom.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdpage.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/vendorprofile.dart';
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';
import 'package:mywheels/auth/vendor/vendornotificationpage.dart';
import 'package:mywheels/auth/vendor/vendorsearch.dart';
import 'package:mywheels/auth/vendor/booking_ticket_dialog.dart';
import 'package:mywheels/auth/vendor/vendorsubscriptionapply.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mywheels/services/local_db_service.dart'; // For json.decode
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import 'package:mywheels/utils/sts_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:tab_container/tab_container.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
import 'package:mywheels/services/pinelabs_print_helper.dart';
import 'package:mywheels/utils/vehicle_image_widget.dart';

import '../../main.dart';
import '../customer/parking/bookparking.dart';
import 'menusscreen.dart';

Map<String, String> globalSelectedPaymentModes = {};

class GlobalVendorDashCache {
  static String? currentVendorId;
  static Vendor? vendor;
  static List<Bookingdata>? carsOnParking;
  static List<Bookingdata>? carsCompleted;
  static List<Bookingdata>? bikesOnParking;
  static List<Bookingdata>? bikesCompleted;
  static List<Bookingdata>? othersOnParking;
  static List<Bookingdata>? othersCompleted;

  static void clear() {
    currentVendorId = null;
    vendor = null;
    carsOnParking = null;
    carsCompleted = null;
    bikesOnParking = null;
    bikesCompleted = null;
    othersOnParking = null;
    othersCompleted = null;
  }
}

bool _isInstantBooking(Bookingdata b) {
  final sts = b.sts.trim().toLowerCase();
  final bType = b.bookType.trim().toLowerCase();
  if (b.subscriptiontype.trim().isNotEmpty) return false;
  if (['subscription', 'weekly', '15day', 'monthly'].contains(sts)) return false;
  if (RegExp(r'^\d+hr$', caseSensitive: false).hasMatch(sts)) return false;
  if (['weekly', 'monthly', 'subscription', '12 hours', '24 hours', '48 hours', '72 hours', 'fullday', 'full day', 'pass'].contains(bType)) {
    return false;
  }
  return true;
}

bool _isInstantBookingStrings(String? sts, String? bookType) {
  final s = (sts ?? '').trim().toLowerCase();
  final b = (bookType ?? '').trim().toLowerCase();
  if (['subscription', 'weekly', '15day', 'monthly'].contains(s)) return false;
  if (RegExp(r'^\d+hr$', caseSensitive: false).hasMatch(s)) return false;
  if (['weekly', 'monthly', 'subscription', '12 hours', '24 hours', '48 hours', '72 hours', 'fullday', 'full day', 'pass'].contains(b)) {
    return false;
  }
  return true;
}

class vendordashScreen extends StatefulWidget {
  final String vendorid;
  final int? initialTabIndex;
  const vendordashScreen({
    super.key,
    required this.vendorid,
    this.initialTabIndex,
    // required this.userName
  });

  @override
  State<vendordashScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<vendordashScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _dateController = TextEditingController();

  String? _menuImageUrl;
  final PermissionStatus _locationPermissionStatus = PermissionStatus.denied;

  int _currentSegment = 0;
  Vendor? _vendor;
  late List<Widget> _pages;
  late TabController _tabController;
  Key _tabKey = UniqueKey();

  void _onTabChange(int index) {
    _navigateToPage(index);
  }

  @override
  void initState() {
    super.initState();
    if (GlobalVendorDashCache.currentVendorId != widget.vendorid) {
      GlobalVendorDashCache.clear();
      GlobalVendorDashCache.currentVendorId = widget.vendorid;
    }
    _requestNotificationPermission();
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialTabIndex ?? 0,
      vsync: this,
    );
    _currentSegment = widget.initialTabIndex ?? 0;
    _tabController.addListener(() {
      setState(() {
        _currentSegment =
            _tabController
                .index; // Update current segment based on TabController index
      });
    });
    _fetchVendorData();
    _fetcVendorData();
    // fetchUserData(int.parse(widget.userId)); // Convert userId to int
    _pagess = [
      vendordashScreen(vendorid: widget.vendorid),
      Bookings(vendorid: widget.vendorid),
      qrcodeallowpark(vendorid: widget.vendorid),
      Third(vendorid: widget.vendorid),

      menu(vendorid: widget.vendorid),
    ];
  }

  Future<void> _fetchVendorData() async {
    try {
      final String url =
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}';
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(url);
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(url, jsonDecode(response.body));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _menuImageUrl = data['data']['image']; // Fetch menu image URL
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
          'Failed to load vendor data, status code: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('fetchVendorData error: $error');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      // For Android 13 (API level 33) and above
      if (await DeviceInfoPlugin().androidInfo.then(
            (info) => info.version.sdkInt,
          ) >=
          33) {
        final status = await Permission.notification.status;

        if (status.isDenied) {
          // Request permission
          final result = await Permission.notification.request();

          if (result.isPermanentlyDenied) {
            // Show dialog to guide user to app settings
            _showPermissionSettingsDialog();
          }
        }
      }
      // For Android 12 and below, notifications are enabled by default
    } else if (Platform.isIOS) {
      // iOS-specific permission request
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            // badge: true,
            sound: true,
          );

      if (result != true) {
        _showPermissionSettingsDialog();
      }
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Notifications are important for booking updates and alerts. '
            'Please enable them in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings(); // Open device settings
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    debugPrint('SnackBar suppressed: $message');
  }

  Future<Map<String, dynamic>> fetchCategories(String vendorId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fetch-slot-vendor-data/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Cars') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Cars': data['Cars'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchbookedslot(String vendorId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}vendor/bookedslots/$vendorId');
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Cars') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Cars': data['Cars'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchavailableslote(String vendorId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/availableslots/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Cars') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Cars': data['Cars'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchbikeCategories(String vendorId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fetch-slot-vendor-data/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Bikes') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Bikes': data['Bikes'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchbikebookedslot(String vendorId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}vendor/bookedslots/$vendorId');
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Bikes') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Bikes': data['Bikes'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchbikeavailableslote(String vendorId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/availableslots/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Bikes') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {'Bikes': data['Bikes'].toString(), 'categories': categories};
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchothersCategories(String vendorId) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fetch-slot-vendor-data/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Others') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {
            'Others': data['Others'].toString(),
            'categories': categories,
          };
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchothersbookedslot(String vendorId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}vendor/bookedslots/$vendorId');
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Others') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {
            'Others': data['Others'].toString(),
            'categories': categories,
          };
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<Map<String, dynamic>> fetchothersavailableslote(
    String vendorId,
  ) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/availableslots/$vendorId',
      );
      http.Response? response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      Map<String, dynamic> data = {};
      bool proceed = false;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(uri.toString());
        if (cached != null) {
          data = cached;
          proceed = true;
        } else {
          throw Exception('No internet and no cache');
        }
      } else {
        response = await http.get(uri);
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          LocalDbService.cacheApiResponse(uri.toString(), data);
          proceed = true;
        } else {
          throw Exception(
            'Failed to load data, status code: ${response?.statusCode}',
          );
        }
      }

      if (proceed) {
        if (data.isNotEmpty) {
          final List<Category> categories = [];
          data.forEach((key, value) {
            if (key != 'Others') {
              categories.add(Category.fromJson(key, value));
            }
          });
          return {
            'Others': data['Others'].toString(),
            'categories': categories,
          };
        } else {
          throw Exception('No categories found');
        }
      } else {
        throw Exception(
          'Failed to load categories, status code: ${response?.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('An error occurred while fetching categories: $e');
    }
  }

  Future<String> fetchSubscriptionStatus(String vendorId) async {
    final urlStr = '${ApiConfig.baseUrl}vendor/fetchsubscription/$vendorId';
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first == ConnectivityResult.none;
      if (isOffline) {
        final cached = LocalDbService.getCachedApiResponse(urlStr);
        if (cached != null) {
          final vendor = cached['vendor'];
          return vendor != null ? vendor['subscription'].toString() : 'false';
        }
        return 'true';
      }
      final response = await http.get(Uri.parse(urlStr));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        LocalDbService.cacheApiResponse(urlStr, data);
        final vendor = data['vendor'];
        return vendor['subscription']?.toString() ?? 'false';
      } else {
        return 'false';
      }
    } catch (e) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null) {
        final vendor = cached['vendor'];
        return vendor != null ? vendor['subscription'].toString() : 'false';
      }
      return 'true';
    }
  }

  Future<void> _fetcVendorData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String url =
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}';
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(url);
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(url, jsonDecode(response.body));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            GlobalVendorDashCache.vendor = _vendor;
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
          'Failed to load vendor data, status code: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error fetching vendor data: $error');
      debugPrint('fetchVendorData (loading) error: $error');
    } finally {
      setState(() {
        _isLoading = false; // Set loading to false when done
      });
    }
  }

  bool _isLoading = true;
  Map<String, dynamic>?
  _dashboardSlots; // single fetch replaces 9 FutureBuilders
  final int _selectedIndex = 0;
  int _selecteddIndex = 0;
  late List<Widget> _pagess;

  void _navigateToPage(int index) {
    setState(() {
      _selecteddIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pagess[index]),
    );
  }

  @override
  void dispose() {
    _tabController.dispose(); // Clean up the controller when not in use
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

      body: SafeArea(child: _buildRamScreen()),

      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: _onTabChange,
        menuImageUrl: _menuImageUrl,
      ),
    );
  }

  String getLimitedText(String text, int maxLength) {
    if (text.length > maxLength) {
      return text.substring(0, maxLength); // Truncate the text to maxLength
    }
    return text;
  }

  Widget _buildRamScreen() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Skeletonizer(
              enabled: _isLoading, // Activate skeleton loading if still loading
              child:
                  _isLoading
                      ? _buildSkeletonLoader()
                      : Row(
                        children: [
                          // Location Icon
                          Icon(
                            Icons.location_on_rounded,
                            color: ColorUtils.primarycolor(),
                            size: 34,
                          ),
                          const SizedBox(width: 10), // Spacing
                          // Vendor Details (GestureDetector and Text wrapped inside a Column)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => vendorProfilePage(
                                        vendorid: widget.vendorid,
                                      ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      (_vendor?.vendorName ?? '').length > 15
                                          ? '${_vendor!.vendorName.substring(0, 20)}...'
                                          : _vendor?.vendorName ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                                Text(
                                  getLimitedText(
                                    _vendor?.address ?? '',
                                    25,
                                  ), // Limit to 30 characters
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1, // Ensure single-line display
                                ),
                              ],
                            ),
                          ),

                          // Spacer to push the CircleAvatar to the far right
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => VendorNotificationScreen(
                                        vendorid: widget.vendorid,
                                      ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ColorUtils.primarycolor(),
                                  width: 0.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: ColorUtils.primarycolor(),
                                child: const Icon(
                                  Icons.notifications,
                                  size: 24,
                                  color: Colors.white,
                                ), // Moved inside `child`
                              ),
                            ),
                          ),

                          // Circle Avatar for Menu Icon
                          // GestureDetector(
                          //   onTap: () {
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(
                          //           builder: (context) =>
                          //               vendorProfilePage(vendorid: widget.vendorid)),
                          //     );
                          //   },
                          //   child: Container(
                          //     decoration: BoxDecoration(
                          //       shape: BoxShape.circle,
                          //       border: Border.all(
                          //         color: ColorUtils.primarycolor(),
                          //         width: 0.5,
                          //       ),
                          //     ),
                          //     child: CircleAvatar(
                          //       radius: 20,
                          //       backgroundColor: Colors.grey[300],
                          //       backgroundImage: (_vendor?.image.isNotEmpty ?? false)
                          //           ? NetworkImage(_vendor!.image)
                          //           : null,
                          //       child: (_vendor?.image.isEmpty ?? true)
                          //           ? Icon(Icons.person, size: 14, color: Colors.black54)
                          //           : null,
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
            ),
          ),

          // Padding(
          //   padding: const EdgeInsets.only(left: 8.0), // Space between search and button
          //   child: Stack(
          //     alignment: Alignment.centerRight,
          //     children: [
          //       ElevatedButton(
          //         onPressed: () async {
          //           String subscriptionStatus = await fetchSubscriptionStatus(widget.vendorid);
          //
          //           if (subscriptionStatus == 'true') {
          //             Navigator.push(
          //               context,
          //               MaterialPageRoute(
          //                 builder: (context) => vendorChooseParkingPage(vendorid: widget.vendorid),
          //               ),
          //             );
          //           } else {
          //             Navigator.push(
          //               context,
          //               MaterialPageRoute(
          //                 builder: (context) => ChoosePlan(vendorid: widget.vendorid),
          //               ),
          //             );
          //           }
          //         },
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: ColorUtils.primarycolor(),
          //           foregroundColor: Colors.white,
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(5),
          //             side: BorderSide(color: Colors.black, width: 0.5), // Black border with 0.5px width
          //           ),
          //           padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0), // Add top padding for text
          //           minimumSize: Size(0, 15),
          //         ),
          //         child: Column(
          //           mainAxisAlignment: MainAxisAlignment.start, // Aligns text at the top of the button
          //           children: [
          //             Text(
          //               'New Booking',
          //               style: GoogleFonts.poppins(
          //                 fontSize: 12,
          //                 fontWeight: FontWeight.bold,
          //                 color: Colors.white, // Correctly setting the text color
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //       Positioned(
          //         right: 0, // Adjust this value to control how much of the image is outside
          //         top: -5,
          //
          //         child: Container(
          //           width: 35, // Controls the visible part of the image
          //           height: 35, // Optional: Adjust size of the image as needed
          //           child: Image.asset('assets/subscribe.png'),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.only(left: 7.0, right: 7.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  vSearchScreen(vendorid: widget.vendorid),
                        ),
                      ).then((_) {
                        GlobalVendorDashCache.carsOnParking = null;
                        GlobalVendorDashCache.carsCompleted = null;
                        GlobalVendorDashCache.bikesOnParking = null;
                        GlobalVendorDashCache.bikesCompleted = null;
                        GlobalVendorDashCache.othersOnParking = null;
                        GlobalVendorDashCache.othersCompleted = null;
                        if (mounted) {
                          setState(() {
                            _tabKey = UniqueKey();
                          });
                        }
                      });
                    },
                    child: TextFormField(
                      readOnly: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    vSearchScreen(vendorid: widget.vendorid),
                          ),
                        ).then((_) {
                          GlobalVendorDashCache.carsOnParking = null;
                          GlobalVendorDashCache.carsCompleted = null;
                          GlobalVendorDashCache.bikesOnParking = null;
                          GlobalVendorDashCache.bikesCompleted = null;
                          GlobalVendorDashCache.othersOnParking = null;
                          GlobalVendorDashCache.othersCompleted = null;
                          if (mounted) {
                            setState(() {
                              _tabKey = UniqueKey();
                            });
                          }
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F2F3),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: ColorUtils.primarycolor(),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(5),
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
                        suffixIcon: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => vSearchScreen(
                                      vendorid: widget.vendorid,
                                    ),
                              ),
                            ).then((_) {
                              GlobalVendorDashCache.carsOnParking = null;
                              GlobalVendorDashCache.carsCompleted = null;
                              GlobalVendorDashCache.bikesOnParking = null;
                              GlobalVendorDashCache.bikesCompleted = null;
                              GlobalVendorDashCache.othersOnParking = null;
                              GlobalVendorDashCache.othersCompleted = null;
                              if (mounted) {
                                setState(() {
                                  _tabKey = UniqueKey();
                                });
                              }
                            });
                          },
                          child: Icon(
                            Icons.search,
                            color: ColorUtils.primarycolor(),
                          ),
                        ),
                        constraints: const BoxConstraints(
                          maxHeight: 40,
                          maxWidth: double.infinity,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        hintText: 'Search',
                        hintStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w300,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 5.0,
                  ), // Space between search and button
                  child: Stack(
                    clipBehavior: Clip.none, // Allows overflow
                    alignment: Alignment.centerRight,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          String subscriptionStatus =
                              await fetchSubscriptionStatus(widget.vendorid);

                          if (subscriptionStatus == 'true') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => vendorChooseParkingPage(
                                      vendorid: widget.vendorid,
                                    ),
                              ),
                            ).then((value) {
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (context, animation1, animation2) =>
                                            vendordashScreen(
                                              vendorid: widget.vendorid,
                                              initialTabIndex:
                                                  value is int
                                                      ? value
                                                      : _currentSegment,
                                            ),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                              }
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        ChoosePlan(vendorid: widget.vendorid),
                              ),
                            ).then((value) {
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (context, animation1, animation2) =>
                                            vendordashScreen(
                                              vendorid: widget.vendorid,
                                              initialTabIndex:
                                                  value is int
                                                      ? value
                                                      : _currentSegment,
                                            ),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                              }
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.primarycolor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: const BorderSide(
                              color: Color(0xFFE4AC3F),
                              width: 1.5,
                            ),

                            // Black border with 0.5px width
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 10.0,
                          ), // Reduced vertical padding
                          minimumSize: const Size(0, 36),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/addicon.png', height: 20),
                            const SizedBox(
                              width: 5.0,
                            ), // Space between icon and text
                            Text(
                              'New Booking',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    Colors
                                        .white, // Correctly setting the text color
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top:
                            -18, // Move the image upwards to position it in the top half
                        right:
                            10, // Adjust this value to control how much of the image is outside
                        child: SizedBox(
                          width: 80, // Controls the visible part of the image
                          height: 35, // Adjust size of the image as needed
                          child: Image.asset('assets/subscribe.png'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // SizedBox(height: 15,),
          //
          //
          //
          // SizedBox(height: 15,),
          const SizedBox(height: 10),

          Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F2F3),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      10,
                    ), // Rounded corners only at the top
                    topRight: Radius.circular(10),
                  ), // Adjust radius for the circular effect
                  // border: Border.all(
                  //     color: ColorUtils.primarycolor(), // Red border color
                  // // Border color
                  //     width: 0.5, //full border
                  //
                  // ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 39,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(
                            10,
                          ), // Rounded corner at the top-left
                          topRight: Radius.circular(
                            10,
                          ), // Rounded corner at the top-right
                        ), // Set the circular border radius to 1
                        // border: Border.all(
                        //   color: ColorUtils.primarycolor(), // Set the border color (or any other color you prefer)
                        //   width: 0, // Set the border width
                        // ),
                      ),
                      child: TabBar(
                        dividerHeight: 0,
                        controller: _tabController,
                        indicator: RoundedRectIndicator(
                          color: const Color(0xFFF1F2F3),
                          radius: 8,
                        ),
                        tabs: [
                          Tab(
                            child: CustomTab(
                              text: "Cars",
                              isSelected: _tabController.index == 0,
                            ),
                          ),
                          Tab(
                            child: CustomTab(
                              text: "Bikes",
                              isSelected: _tabController.index == 1,
                            ),
                          ),
                          Tab(
                            child: CustomTab(
                              text: "Others",
                              isSelected: _tabController.index == 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Builder(
                        builder: (context) {
                          if (_currentSegment == 0) {
                            // Display data for Cars
                            return Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                buildcartotal(),
                                const SizedBox(width: 15),
                                buildcarparked(),
                                const SizedBox(width: 15),
                                buildavailableparked(),
                              ],
                            );
                          } else if (_currentSegment == 1) {
                            // Display data for Bikes
                            return Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                buildbiketotal(),
                                const SizedBox(width: 15),
                                buildbikeparked(),
                                const SizedBox(width: 15),
                                buildbikeavailableparked(),
                              ],
                            );
                          } else if (_currentSegment == 2) {
                            // Display data for Others
                            return Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                buildotherstotal(),
                                const SizedBox(width: 15),
                                buildothersparked(),
                                const SizedBox(width: 15),
                                buildothersavailableparked(),
                              ],
                            );
                          } else {
                            // Fallback to an empty container for invalid segments
                            return Container();
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF1F2F3),
                        child: TabBarView(
                          key: _tabKey,
                          controller: _tabController,
                          children: [
                            CarsTab(
                              vendorid: widget.vendorid,
                              tab: "0",
                              defaultVendorName: _vendor?.vendorName,
                              vendor: _vendor,
                            ),
                            BikesTab(
                              vendorid: widget.vendorid,
                              tab: "1",
                              defaultVendorName: _vendor?.vendorName,
                              vendor: _vendor,
                            ),
                            OthersTab(
                              vendorid: widget.vendorid,
                              tab: "2",
                              defaultVendorName: _vendor?.vendorName,
                              vendor: _vendor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    String title,
    String totalCount, [
    List<Category>? categories,
  ]) {
    if (title == "Available") title = "Open";
    return Expanded(
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 20,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  totalCount,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 110,
        width: 110,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(height: 10, width: 50, color: Colors.grey[300]),
            const SizedBox(height: 8),
            CircleAvatar(radius: 16, backgroundColor: Colors.grey[300]),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (index) =>
                    Container(height: 10, width: 30, color: Colors.grey[300]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SafeArea(
      child: Row(
        children: [
          // Skeleton for location icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          const SizedBox(width: 10),

          // Skeleton for text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 100, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(height: 14, width: 150, color: Colors.grey[300]),
              ],
            ),
          ),

          // Skeleton for avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildcartotal() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchCategories(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['categories'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Cars'];
        List<Category> categories = snapshot.data!['categories'];

        return _buildContent("Total", totalCount, categories);
      },
    );
  }

  Widget buildcarparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchbookedslot(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Cars'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Cars'];

        return _buildContent("Booked", totalCount);
      },
    );
  }

  Widget buildavailableparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchavailableslote(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Cars'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Cars'];

        return _buildContent("Available", totalCount);
      },
    );
  }

  Widget buildbiketotal() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchbikeCategories(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Bikes'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Bikes'];
        List<Category> categories = snapshot.data!['categories'];

        return _buildContent("Total", totalCount, categories);
      },
    );
  }

  Widget buildbikeparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchbikebookedslot(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Bikes'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Bikes'];

        return _buildContent("Booked", totalCount);
      },
    );
  }

  Widget buildbikeavailableparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchbikeavailableslote(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Bikes'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Bikes'];

        return _buildContent("Available", totalCount);
      },
    );
  }

  Widget buildotherstotal() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchothersCategories(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['categories'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Others'];
        List<Category> categories = snapshot.data!['categories'];

        return _buildContent("Total", totalCount, categories);
      },
    );
  }

  Widget buildothersparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchothersbookedslot(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Others'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Others'];

        return _buildContent("Booked", totalCount);
      },
    );
  }

  Widget buildothersavailableparked() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchothersavailableslote(widget.vendorid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['Others'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['Others'];

        return _buildContent("Available", totalCount);
      },
    );
  }
}

// Cars Stateful Widget
class CarsTab extends StatefulWidget {
  final String vendorid;
  final String tab;
  final String? defaultVendorName;
  final Vendor? vendor;
  const CarsTab({
    super.key,
    required this.vendorid,
    required this.tab,
    this.defaultVendorName,
    this.vendor,
  });
  @override
  _CarsTabState createState() => _CarsTabState();
}

class _CarsTabState extends State<CarsTab> with SingleTickerProviderStateMixin {
  Vendor? get _vendor => widget.vendor ?? GlobalVendorDashCache.vendor;
  late final TabController _controller;
  int selectedTabIndex = 0;
  DateTime selectedDateTime =
      DateTime.now(); // Initialize with the current date and time
  late final Timer _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  bool isLoading = true;
  List<Exitcharge> parkingCharges = [];
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  String fullDayChargeType = '24 Hours';
  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    _controller = TabController(vsync: this, length: 2);

    // Update tab change listener
    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
      });

      if (selectedTabIndex == 0) {
        fetchOnParkingData()
            .then((data) {
              setState(() {
                bookingDataNotifier.value = data;
                isLoading =
                    false; // Set loading flag to false after data is fetched
              });
              updatePayableTimes();
            })
            .catchError((error) {
              setState(() {
                isLoading = false;
              });
              print('Error fetching booking data: $error');
            });
      }
      // You can handle the other tab (index 1) as needed
    });

    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });

    // Try to load from cache first for instant display
    if (GlobalVendorDashCache.currentVendorId != widget.vendorid) {
      GlobalVendorDashCache.clear();
      GlobalVendorDashCache.currentVendorId = widget.vendorid;
    }
    if (GlobalVendorDashCache.carsOnParking != null) {
      bookingDataNotifier.value = GlobalVendorDashCache.carsOnParking!;
      isLoading = false;
      updatePayableTimes();
    }

    // Fetch the initial data in background
    fetchOnParkingData()
        .then((data) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = data;
              isLoading =
                  false; // Set loading flag to false after initial data load
            });
            updatePayableTimes();
          }
          GlobalVendorDashCache.currentVendorId = widget.vendorid;
          GlobalVendorDashCache.carsOnParking = data;
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = [];
              isLoading = false;
            });
          }
          print('Error fetching booking data: $error');
        });

    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      // Fetch GST and Handling Fee
      final gstResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetchgstdata?vendor_id=${widget.vendorid}',
        ),
      );
      if (gstResponse.statusCode == 200) {
        final gstData = json.decode(gstResponse.body);
        setState(() {
          gstPercentage = double.tryParse(gstData['gst'].toString()) ?? 0.0;
          handlingFee =
              double.tryParse(gstData['handlingfee'].toString()) ?? 0.0;
        });
      }

      // Fetch Parking Charges
      final chargeResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-exit-charges?vendor_id=${widget.vendorid}&vehicleType=Car',
        ),
      );
      if (chargeResponse.statusCode == 200) {
        final Map<String, dynamic> chargeData = json.decode(
          chargeResponse.body,
        );
        if (chargeData['charges'] != null) {
          setState(() {
            parkingCharges =
                (chargeData['charges'] as List)
                    .map((item) => Exitcharge.fromJson(item))
                    .toList();
            fullDayChargeType = chargeData['fullDayCharge'] ?? '24 Hours';
          });
        }
      }
      if (GlobalVendorDashCache.vendor == null) {
        try {
          final vendorResponse = await http.get(
            Uri.parse(
              '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
            ),
          );
          if (vendorResponse.statusCode == 200) {
            final Map<String, dynamic> vData = json.decode(vendorResponse.body);
            if (vData['data'] != null) {
              GlobalVendorDashCache.vendor = Vendor.fromJson(vData['data']);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    }
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(
      2,
      '0',
    ); // Ensure two digits
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }

  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData =
        bookingDataNotifier.value.map((booking) {
          if (booking.status == 'PARKED' || booking.status == 'Booked') {
            final parkingTime = parseParkingDateTime(
              "${booking.parkeddate} ${booking.parkedtime}",
            );
            final elapsed = now.difference(parkingTime);

            // Debugging: Print elapsed time
            // print('Elapsed Time for ${booking.vehicleNumber}: $elapsed');

            // Ensure we update the payableDuration with correct values
            booking.payableDuration = elapsed;

            if (parkingCharges.isNotEmpty) {
              double payable = BookingAmountCalculator.calculatePayableAmount(
                duration: elapsed,
                bookType: booking.bookType,
                parkedDate: booking.parkeddate,
                parkedTime: booking.parkedtime,
                parkingCharges: parkingCharges,
                fullDayChargeType: fullDayChargeType,
              );
              double total = BookingAmountCalculator.calculateTotalWithTaxes(
                payable,
                gstPercentage,
                handlingFee,
              );
              final maxCar = _vendor?.maxCarAmount ?? 0.0;
              if (maxCar > 0 && total > maxCar && _isInstantBooking(booking)) {
                total = maxCar;
              }
              booking.currentCalculatedAmount = total.toStringAsFixed(2);
            }
          }
          return booking;
        }).toList();
    // Navigator.pop(context);
    // Trigger a rebuild of the widget with the updated data
    bookingDataNotifier.value = updatedData;
  }

  Future<List<Bookingdata>> fetchBookingData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Car';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  Future<List<Bookingdata>> fetchOnParkingData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Car/onparking';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  Future<List<Bookingdata>> fetchCompletedData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Car/completed';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  DateTime parseParkingDateTime(String dateTimeString) {
    // Example input: "06-12-2024 11:04 AM"
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':'); // Change from '.' to ':'

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Handle AM/PM
    if (parts[2] == 'PM' && hour != 12) {
      hour += 12; // Convert to 24-hour format
    } else if (parts[2] == 'AM' && hour == 12) {
      hour = 0; // Midnight case
    }

    return DateTime(year, month, day, hour, minute);
  }

  Duration getTotalParkedTime(String parkingDateTimeString) {
    DateTime parkingDateTime = parseParkingDateTime(parkingDateTimeString);
    DateTime now =
        DateTime.now(); // You can replace this with server time if available

    Duration difference = now.difference(parkingDateTime);

    if (difference.isNegative) {
      return Duration
          .zero; // Return zero duration if the parking time has not started yet
    }

    return difference; // Return the duration
  }

  @override
  void dispose() {
    // _timer.cancel();
    bookingDataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentSegment = _HomeScreenState()._currentSegment;
    return Container(
      decoration: BoxDecoration(
        // color: ColorUtils.primarycolor(),
        borderRadius: BorderRadius.circular(10), // Circular border
        // border: Border.all(
        //   color: ColorUtils.primarycolor(),  // Border color, change as needed
        //   width: 0,           // Border width, adjust as needed
        // ),
      ),
      child: TabContainer(
        controller: _controller, // Ensure the controller is passed here
        borderRadius: BorderRadius.circular(
          10,
        ), // Ensure this is passed as well
        tabEdge: TabEdge.top,
        curve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.2, 0.0),
              end: const Offset(0.0, 0.0),
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        selectedTextStyle: GoogleFonts.poppins(
          fontSize: 15.0,
          color: ColorUtils.primarycolor(),
        ),
        unselectedTextStyle: GoogleFonts.poppins(
          fontSize: 13.0,
          color: Colors.black, // Set default unselected color
        ),
        tabs: _getTabs(),
        children: [
          // Provide content for the "On Parking" tab
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: ValueListenableBuilder<List<Bookingdata>>(
                valueListenable: bookingDataNotifier,
                builder: (context, bookingData, child) {
                  if (bookingData.isEmpty) {
                    // Show CircularProgressIndicator only if the data is still loading
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Car Parked')],
                    );
                  }

                  // Filter the data
                  final filteredData =
                      bookingData.where((booking) {
                        try {
                          if (GlobalRecentExits.exitedBookingIds.contains(
                            booking.id,
                          )) {
                            return false;
                          }
                          final exitDate =
                              (booking.exitvehicledate ?? '').trim();
                          if (exitDate.isNotEmpty && exitDate != 'null') {
                            return false;
                          }
                          if (booking.status.toUpperCase() == 'COMPLETED') {
                            return false;
                          }
                          return isVendorShortParkingSts(
                            booking.sts?.toString(),
                          );
                        } catch (e) {
                          return false; // Skip invalid entries
                        }
                      }).toList();

                  if (filteredData.isEmpty) {
                    // Show "No data available" if filtering results in an empty list
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Car Parked')],
                    );
                  }

                  // Show the filtered data in a ListView
                  return RefreshIndicator(
                    onRefresh: () async {
                      final data = await fetchOnParkingData();
                      setState(() {
                        bookingDataNotifier.value = data;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];

                          return cardashleft(
                            currentTabIndex: 0,
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                            onExitSuccess: () {
                              final currentData =
                                  bookingDataNotifier.value.toList();
                              currentData.removeWhere(
                                (v) => v.id == vehicle.id,
                              );
                              bookingDataNotifier.value = currentData;
                              GlobalRecentExits.exitedBookingIds.add(
                                vehicle.id,
                              );
                              GlobalVendorDashCache.carsOnParking?.removeWhere(
                                (v) => v.id == vehicle.id,
                              );
                              GlobalVendorDashCache.carsCompleted = null;
                              LocalDbService.markBookingCompletedOffline(
                                vehicle.id,
                              );
                              setState(
                                () {},
                              ); // Rebuild to refresh the Completed tab
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FutureBuilder<List<Bookingdata>>(
                future: fetchCompletedData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const SizedBox(height: 50),
                        Center(
                          child: Lottie.asset(
                            'assets/carload.json', // Path to your Lottie JSON file
                            width: double.infinity, // Adjust the size
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Car Parked')],
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Car Parked')],
                    );
                  } else {
                    final filteredData =
                        snapshot.data!.where((booking) {
                          // API already filters by COMPLETED + today's date
                          // Check if exitvehicledate exists
                          if (booking.exitvehicledate == null ||
                              booking.exitvehicledate!.isEmpty)
                            return false;

                          // Parse exitvehicledate safely (assuming format: dd-mm-yyyy)
                          final parts = booking.exitvehicledate!.split('-');
                          if (parts.length != 3) return false;

                          final exitDay = int.tryParse(parts[0]);
                          final exitMonth = int.tryParse(parts[1]);
                          final exitYear = int.tryParse(parts[2]);
                          if (exitDay == null ||
                              exitMonth == null ||
                              exitYear == null)
                            return false;

                          final exitDate = DateTime(
                            exitYear,
                            exitMonth,
                            exitDay,
                          );
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);

                          final bool isMatchingVendor =
                              booking.Vendorid == widget.vendorid;
                          final bool isVehicleCar =
                              booking.vehicletype == 'Car';
                          final bool isCompleted =
                              booking.status.toUpperCase() == 'COMPLETED';
                          final bool isSameDay =
                              exitDate.year == today.year &&
                              exitDate.month == today.month &&
                              exitDate.day == today.day;

                          final bool isBookingTypeValid =
                              isVendorShortParkingSts(booking.sts?.toString());

                          // Filter condition
                          return isMatchingVendor &&
                              isVehicleCar &&
                              isCompleted &&
                              isSameDay &&
                              isBookingTypeValid;
                        }).toList();

                    print('Filtered Data Count: ${filteredData.length}');

                    // Debugging: print final filtered data
                    print('Filtered Data: $filteredData');

                    // If no filtered data, show message
                    if (filteredData.isEmpty) {
                      return const Column(
                        children: [
                          SizedBox(height: 150),
                          Text('No Car Parked'),
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];
                          return vendordashright(
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTabs() {
    return [
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 8),
          Text(
            'On Parking',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 0 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.verified_outlined,
          //   color: selectedTabIndex == 1 ? Colors.black : Colors.black,
          // ),
          const SizedBox(width: 8),
          Text(
            'Completed',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
    ];
  }
}

class BikesTab extends StatefulWidget {
  final String tab;
  final String vendorid;
  final String? defaultVendorName;
  final Vendor? vendor;
  const BikesTab({
    super.key,
    required this.vendorid,
    required this.tab,
    this.defaultVendorName,
    this.vendor,
  });
  @override
  _BikesTabState createState() => _BikesTabState();
}

class _BikesTabState extends State<BikesTab>
    with SingleTickerProviderStateMixin {
  Vendor? get _vendor => widget.vendor ?? GlobalVendorDashCache.vendor;
  late final TabController _controller;
  int selectedTabIndex = 0;
  DateTime selectedDateTime =
      DateTime.now(); // Initialize with the current date and time
  late final Timer _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  List<Exitcharge> parkingCharges = [];
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  String fullDayChargeType = '24 Hours';

  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    _controller = TabController(vsync: this, length: 2);
    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });

    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
        print('Selected Tab Index: $selectedTabIndex');
      });
    });
    // Try to load from cache first for instant display
    if (GlobalVendorDashCache.currentVendorId != widget.vendorid) {
      GlobalVendorDashCache.clear();
      GlobalVendorDashCache.currentVendorId = widget.vendorid;
    }
    if (GlobalVendorDashCache.bikesOnParking != null) {
      bookingDataNotifier.value = GlobalVendorDashCache.bikesOnParking!;
      updatePayableTimes();
    }

    fetchOnParkingData()
        .then((data) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = data;
            });
            updatePayableTimes(); // Call update once data is fetched
          }
          GlobalVendorDashCache.currentVendorId = widget.vendorid;
          GlobalVendorDashCache.bikesOnParking = data;
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = [];
            });
          }
          print('Error fetching bikes data: $error');
        });
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      final gstResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetchgstdata?vendor_id=${widget.vendorid}',
        ),
      );
      if (gstResponse.statusCode == 200) {
        final gstData = json.decode(gstResponse.body);
        setState(() {
          gstPercentage = double.tryParse(gstData['gst'].toString()) ?? 0.0;
          handlingFee =
              double.tryParse(gstData['handlingfee'].toString()) ?? 0.0;
        });
      }

      final chargeResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-exit-charges?vendor_id=${widget.vendorid}&vehicleType=Bike',
        ),
      );
      if (chargeResponse.statusCode == 200) {
        final Map<String, dynamic> chargeData = json.decode(
          chargeResponse.body,
        );
        if (chargeData['charges'] != null) {
          setState(() {
            parkingCharges =
                (chargeData['charges'] as List)
                    .map((item) => Exitcharge.fromJson(item))
                    .toList();
            fullDayChargeType = chargeData['fullDayCharge'] ?? '24 Hours';
          });
        }
      }
      if (GlobalVendorDashCache.vendor == null) {
        try {
          final vendorResponse = await http.get(
            Uri.parse(
              '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
            ),
          );
          if (vendorResponse.statusCode == 200) {
            final Map<String, dynamic> vData = json.decode(vendorResponse.body);
            if (vData['data'] != null) {
              GlobalVendorDashCache.vendor = Vendor.fromJson(vData['data']);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    }
  }

  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData =
        bookingDataNotifier.value.map((booking) {
          if (booking.status == 'PARKED' || booking.status == 'Booked') {
            final parkingTime = parseParkingDateTime(
              "${booking.parkeddate} ${booking.parkedtime}",
            );
            final elapsed = now.difference(parkingTime);

            // Debugging: Print elapsed time
            // print('Elapsed Time for ${booking.vehicleNumber}: $elapsed');

            // Ensure we update the payableDuration with correct values
            booking.payableDuration = elapsed;

            if (parkingCharges.isNotEmpty) {
              double payable = BookingAmountCalculator.calculatePayableAmount(
                duration: elapsed,
                bookType: booking.bookType,
                parkedDate: booking.parkeddate,
                parkedTime: booking.parkedtime,
                parkingCharges: parkingCharges,
                fullDayChargeType: fullDayChargeType,
              );
              double total = BookingAmountCalculator.calculateTotalWithTaxes(
                payable,
                gstPercentage,
                handlingFee,
              );
              final maxBike = _vendor?.maxBikeAmount ?? 0.0;
              if (maxBike > 0 && total > maxBike && _isInstantBooking(booking)) {
                total = maxBike;
              }
              booking.currentCalculatedAmount = total.toStringAsFixed(2);
            }
          }
          return booking;
        }).toList();

    // Trigger a rebuild of the widget with the updated data
    bookingDataNotifier.value = updatedData;
  }

  Future<List<Bookingdata>> fetchBookingData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Bike';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  Future<List<Bookingdata>> fetchOnParkingData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Bike/onparking';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  Future<List<Bookingdata>> fetchCompletedData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Bike/completed';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw response.body;
    }
  }

  DateTime parseParkingDateTime(String dateTimeString) {
    // Example input: "06-12-2024 11:04 AM"
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':'); // Change from '.' to ':'

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Handle AM/PM
    if (parts[2] == 'PM' && hour != 12) {
      hour += 12; // Convert to 24-hour format
    } else if (parts[2] == 'AM' && hour == 12) {
      hour = 0; // Midnight case
    }

    return DateTime(year, month, day, hour, minute);
  }

  Duration getTotalParkedTime(String parkingDateTimeString) {
    DateTime parkingDateTime = parseParkingDateTime(parkingDateTimeString);
    DateTime now =
        DateTime.now(); // You can replace this with server time if available

    Duration difference = now.difference(parkingDateTime);

    if (difference.isNegative) {
      return Duration
          .zero; // Return zero duration if the parking time has not started yet
    }

    return difference; // Return the duration
  }

  @override
  void dispose() {
    // _timer.cancel();
    bookingDataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentSegment = _HomeScreenState()._currentSegment;
    return Container(
      decoration: BoxDecoration(
        // color: ColorUtils.primarycolor(),
        borderRadius: BorderRadius.circular(10), // Circular border
        // border: Border.all(
        //   color: ColorUtils.primarycolor(),  // Border color, change as needed
        //   width: 0,           // Border width, adjust as needed
        // ),
      ),
      child: TabContainer(
        controller: _controller, // Ensure the controller is passed here
        borderRadius: BorderRadius.circular(
          10,
        ), // Ensure this is passed as well
        tabEdge: TabEdge.top,
        curve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.2, 0.0),
              end: const Offset(0.0, 0.0),
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        selectedTextStyle: GoogleFonts.poppins(
          fontSize: 15.0,
          color: ColorUtils.primarycolor(),
        ),
        unselectedTextStyle: GoogleFonts.poppins(
          fontSize: 13.0,
          color: Colors.black, // Set default unselected color
        ),
        tabs: _getTabs(),
        children: [
          // Provide content for the "On Parking" tab
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: ValueListenableBuilder<List<Bookingdata>>(
                valueListenable: bookingDataNotifier,
                builder: (context, bookingData, child) {
                  if (bookingData.isEmpty) {
                    // Show CircularProgressIndicator only if the data is still loading
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Bike Parked')],
                    );
                  }

                  // Filter the data
                  final filteredData =
                      bookingData.where((booking) {
                        try {
                          if (GlobalRecentExits.exitedBookingIds.contains(
                            booking.id,
                          )) {
                            return false;
                          }
                          final exitDate =
                              (booking.exitvehicledate ?? '').trim();
                          if (exitDate.isNotEmpty && exitDate != 'null') {
                            return false;
                          }
                          if (booking.status.toUpperCase() == 'COMPLETED') {
                            return false;
                          }
                          return isVendorShortParkingSts(
                            booking.sts?.toString(),
                          );
                        } catch (e) {
                          return false; // Skip invalid entries
                        }
                      }).toList();

                  if (filteredData.isEmpty) {
                    // Show "No data available" if filtering results in an empty list
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Bike Parked')],
                    );
                  }

                  // Show the filtered data in a ListView
                  return RefreshIndicator(
                    onRefresh: () async {
                      final data = await fetchOnParkingData();
                      setState(() {
                        bookingDataNotifier.value = data;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];

                          return bikedashleft(
                            currentTabIndex: 1,
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                            onExitSuccess: () {
                              final currentData =
                                  bookingDataNotifier.value.toList();
                              currentData.removeWhere(
                                (v) => v.id == vehicle.id,
                              );
                              bookingDataNotifier.value = currentData;
                              GlobalRecentExits.exitedBookingIds.add(
                                vehicle.id,
                              );
                              GlobalVendorDashCache.bikesOnParking?.removeWhere(
                                (v) => v.id == vehicle.id,
                              );
                              GlobalVendorDashCache.bikesCompleted = null;
                              LocalDbService.markBookingCompletedOffline(
                                vehicle.id,
                              );
                              setState(
                                () {},
                              ); // Rebuild to refresh the Completed tab
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FutureBuilder<List<Bookingdata>>(
                future: fetchCompletedData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const SizedBox(height: 50),
                        Center(
                          child: Lottie.asset(
                            'assets/bikeload.json', // Path to your Lottie JSON file
                            width: double.infinity, // Adjust the size
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Bike Parked')],
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Column(
                      children: [SizedBox(height: 150), Text('No Bike Parked')],
                    );
                  } else {
                    final filteredData =
                        snapshot.data!.where((booking) {
                          // Ensure exitvehicledate is not null or empty
                          if (booking.exitvehicledate == null ||
                              booking.exitvehicledate!.isEmpty)
                            return false;

                          // Parse the exit date safely (assuming format: dd-mm-yyyy)
                          final parts = booking.exitvehicledate!.split('-');
                          if (parts.length != 3) return false;

                          final exitDay = int.tryParse(parts[0]);
                          final exitMonth = int.tryParse(parts[1]);
                          final exitYear = int.tryParse(parts[2]);
                          if (exitDay == null ||
                              exitMonth == null ||
                              exitYear == null)
                            return false;

                          final exitDate = DateTime(
                            exitYear,
                            exitMonth,
                            exitDay,
                          );

                          // Vendor match
                          bool isMatchingVendor =
                              booking.Vendorid == widget.vendorid;
                          print(
                            'Booking Vendor ID: ${booking.Vendorid}, Widget Vendor ID: ${widget.vendorid}, Match: $isMatchingVendor',
                          );

                          // Vehicle type match (Bike)
                          bool isVehicleBike = booking.vehicletype == 'Bike';
                          print(
                            'Booking Vehicle Type: ${booking.vehicletype}, Is Bike: $isVehicleBike',
                          );

                          // Completed status check
                          bool isCompleted =
                              booking.status.toUpperCase() == 'COMPLETED';
                          print(
                            'Booking Status: ${booking.status}, Is Completed: $isCompleted',
                          );

                          // Compare only date (ignore time)
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          bool isSameDay =
                              exitDate.year == today.year &&
                              exitDate.month == today.month &&
                              exitDate.day == today.day;

                          // Final filter condition
                          return isMatchingVendor &&
                              isVehicleBike &&
                              isCompleted &&
                              isSameDay;
                        }).toList();

                    print('Filtered Bike Data Count: ${filteredData.length}');

                    print('Filtered Data: $filteredData');

                    // If no filtered data, show message
                    if (filteredData.isEmpty) {
                      return const Column(
                        children: [
                          SizedBox(height: 150),
                          Text('No Bike Parked'),
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];
                          return vendordashright(
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTabs() {
    return [
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.local_parking,
          //   color: selectedTabIndex == 0 ? Colors.black : Colors.black,
          // ),
          const SizedBox(width: 8),
          Text(
            'On Parking',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 0 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.verified_outlined,
          //   color: selectedTabIndex == 1 ? Colors.black : Colors.black,
          // ),
          const SizedBox(width: 8),
          Text(
            'Completed',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
    ];
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(
      2,
      '0',
    ); // Ensure two digits
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }
}

class OthersTab extends StatefulWidget {
  final String vendorid;
  final String tab;
  final String? defaultVendorName;
  final Vendor? vendor;
  const OthersTab({
    super.key,
    required this.vendorid,
    required this.tab,
    this.defaultVendorName,
    this.vendor,
  });
  @override
  _OthersTabState createState() => _OthersTabState();
}

class _OthersTabState extends State<OthersTab>
    with SingleTickerProviderStateMixin {
  Vendor? get _vendor => widget.vendor ?? GlobalVendorDashCache.vendor;
  late final TabController _controller;
  int selectedTabIndex = 0;
  DateTime selectedDateTime =
      DateTime.now(); // Initialize with the current date and time
  late final Timer _payableTimer;
  ValueNotifier<List<Bookingdata>> bookingDataNotifier = ValueNotifier([]);
  bool isLoading = true;
  List<Exitcharge> parkingCharges = [];
  double gstPercentage = 0.0;
  double handlingFee = 0.0;
  String fullDayChargeType = '24 Hours';
  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
    _controller = TabController(vsync: this, length: 2);
    _payableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        updatePayableTimes();
      }
    });
    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
        print('Selected Tab Index: $selectedTabIndex');
      });
    });
    // Try to load from cache first for instant display
    if (GlobalVendorDashCache.currentVendorId != widget.vendorid) {
      GlobalVendorDashCache.clear();
      GlobalVendorDashCache.currentVendorId = widget.vendorid;
    }
    if (GlobalVendorDashCache.othersOnParking != null) {
      bookingDataNotifier.value = GlobalVendorDashCache.othersOnParking!;
      isLoading = false;
      updatePayableTimes();
    }

    fetchOnParkingData()
        .then((data) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = data;
              isLoading = false;
            });
            updatePayableTimes(); // Call update once data is fetched
          }
          GlobalVendorDashCache.currentVendorId = widget.vendorid;
          GlobalVendorDashCache.othersOnParking = data;
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              bookingDataNotifier.value = [];
              isLoading = false;
            });
          }
          print('Error fetching others data: $error');
        });
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      final gstResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetchgstdata?vendor_id=${widget.vendorid}',
        ),
      );
      if (gstResponse.statusCode == 200) {
        final gstData = json.decode(gstResponse.body);
        setState(() {
          gstPercentage = double.tryParse(gstData['gst'].toString()) ?? 0.0;
          handlingFee =
              double.tryParse(gstData['handlingfee'].toString()) ?? 0.0;
        });
      }

      final chargeResponse = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-exit-charges?vendor_id=${widget.vendorid}&vehicleType=Others',
        ),
      );
      if (chargeResponse.statusCode == 200) {
        final Map<String, dynamic> chargeData = json.decode(
          chargeResponse.body,
        );
        if (chargeData['charges'] != null) {
          setState(() {
            parkingCharges =
                (chargeData['charges'] as List)
                    .map((item) => Exitcharge.fromJson(item))
                    .toList();
            fullDayChargeType = chargeData['fullDayCharge'] ?? '24 Hours';
          });
        }
      }
      if (GlobalVendorDashCache.vendor == null) {
        try {
          final vendorResponse = await http.get(
            Uri.parse(
              '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
            ),
          );
          if (vendorResponse.statusCode == 200) {
            final Map<String, dynamic> vData = json.decode(vendorResponse.body);
            if (vData['data'] != null) {
              GlobalVendorDashCache.vendor = Vendor.fromJson(vData['data']);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error fetching initial data: $e');
    }
  }

  void updatePayableTimes() {
    final now = DateTime.now();
    final updatedData =
        bookingDataNotifier.value.map((booking) {
          if (booking.status == 'PARKED' || booking.status == 'Booked') {
            final parkingTime = parseParkingDateTime(
              "${booking.parkeddate} ${booking.parkedtime}",
            );
            final elapsed = now.difference(parkingTime);

            // Debugging: Print elapsed time
            // print('Elapsed Time for ${booking.vehicleNumber}: $elapsed');

            // Ensure we update the payableDuration with correct values
            booking.payableDuration = elapsed;

            if (parkingCharges.isNotEmpty) {
              double payable = BookingAmountCalculator.calculatePayableAmount(
                duration: elapsed,
                bookType: booking.bookType,
                parkedDate: booking.parkeddate,
                parkedTime: booking.parkedtime,
                parkingCharges: parkingCharges,
                fullDayChargeType: fullDayChargeType,
              );
              double total = BookingAmountCalculator.calculateTotalWithTaxes(
                payable,
                gstPercentage,
                handlingFee,
              );
              final maxOthers = _vendor?.maxOthersAmount ?? 0.0;
              if (maxOthers > 0 && total > maxOthers && _isInstantBooking(booking)) {
                total = maxOthers;
              }
              booking.currentCalculatedAmount = total.toStringAsFixed(2);
            }
          }
          return booking;
        }).toList();

    // Trigger a rebuild of the widget with the updated data
    bookingDataNotifier.value = updatedData;
  }

  Future<List<Bookingdata>> fetchBookingData() async {
    setState(() => isLoading = true);

    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Others';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw 'Error fetching data: ${response?.statusCode}';
    }
  }

  Future<List<Bookingdata>> fetchOnParkingData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Others/onparking';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw 'Error fetching data: ${response?.statusCode}';
    }
  }

  Future<List<Bookingdata>> fetchCompletedData() async {
    final urlStr =
        '${ApiConfig.baseUrl}vendor/getbookingdata/${widget.vendorid}/Others/completed';
    final url = Uri.parse(urlStr);

    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    if (!isOnline) {
      final cached = LocalDbService.getCachedApiResponse(urlStr);
      if (cached != null && cached['bookings'] is List) {
        final List<dynamic> data = cached['bookings'];
        if (data.isEmpty) throw 'No bookings available';
        return data
            .map(
              (item) => Bookingdata.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      throw 'No bookings available (offline)';
    }

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      LocalDbService.cacheApiResponse(urlStr, jsonResponse);
      final List<dynamic>? data = jsonResponse['bookings'];
      if (data == null || data.isEmpty) throw 'No bookings available';
      return data
          .map((item) => Bookingdata.fromJson(item))
          .where(
            (b) =>
                !GlobalRecentExits.exitedBookingIds.contains(b.id) &&
                (b.exitvehicledate == null ||
                    b.exitvehicledate!.trim().isEmpty ||
                    b.exitvehicledate == 'null') &&
                b.status.toUpperCase() != 'COMPLETED',
          )
          .toList();
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      throw 'No booking found';
    } else {
      throw 'Error fetching data: ${response?.statusCode}';
    }
  }

  // Function to add 'st', 'nd', 'rd', 'th' suffix

  DateTime parseParkingDateTime(String dateTimeString) {
    // Example input: "06-12-2024 11:04 AM"
    final parts = dateTimeString.split(' ');
    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':'); // Change from '.' to ':'

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    // Handle AM/PM
    if (parts[2] == 'PM' && hour != 12) {
      hour += 12; // Convert to 24-hour format
    } else if (parts[2] == 'AM' && hour == 12) {
      hour = 0; // Midnight case
    }

    return DateTime(year, month, day, hour, minute);
  }

  Duration getTotalParkedTime(String parkingDateTimeString) {
    DateTime parkingDateTime = parseParkingDateTime(parkingDateTimeString);
    DateTime now =
        DateTime.now(); // You can replace this with server time if available

    Duration difference = now.difference(parkingDateTime);

    if (difference.isNegative) {
      return Duration
          .zero; // Return zero duration if the parking time has not started yet
    }

    return difference; // Return the duration
  }

  @override
  void dispose() {
    // _timer.cancel();
    bookingDataNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentSegment = _HomeScreenState()._currentSegment;
    return Container(
      decoration: BoxDecoration(
        // color: ColorUtils.primarycolor(),
        borderRadius: BorderRadius.circular(5), // Circular border
        // border: Border.all(
        //   color: ColorUtils.primarycolor(),  // Border color, change as needed
        //   width: 0,           // Border width, adjust as needed
        // ),
      ),
      child: TabContainer(
        controller: _controller, // Ensure the controller is passed here
        borderRadius: BorderRadius.circular(
          10,
        ), // Ensure this is passed as well
        tabEdge: TabEdge.top,
        curve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.2, 0.0),
              end: const Offset(0.0, 0.0),
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        selectedTextStyle: GoogleFonts.poppins(
          fontSize: 15.0,
          color: ColorUtils.primarycolor(),
        ),
        unselectedTextStyle: GoogleFonts.poppins(
          fontSize: 13.0,
          color: Colors.black, // Set default unselected color
        ),
        tabs: _getTabs(),
        children: [
          // Provide content for the "On Parking" tab
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: ValueListenableBuilder<List<Bookingdata>>(
                valueListenable: bookingDataNotifier,
                builder: (context, bookingData, child) {
                  if (bookingData.isEmpty) {
                    // Show CircularProgressIndicator only if the data is still loading
                    return const Column(
                      children: [
                        SizedBox(height: 150),
                        Text('Nothing Parked (Others)'),
                      ],
                    );
                  }

                  // Filter the data
                  final filteredData =
                      bookingData.where((booking) {
                        try {
                          if (GlobalRecentExits.exitedBookingIds.contains(
                            booking.id,
                          )) {
                            return false;
                          }
                          final exitDate =
                              (booking.exitvehicledate ?? '').trim();
                          if (exitDate.isNotEmpty && exitDate != 'null') {
                            return false;
                          }
                          if (booking.status.toUpperCase() == 'COMPLETED') {
                            return false;
                          }
                          return isVendorShortParkingSts(
                            booking.sts?.toString(),
                          );
                        } catch (e) {
                          return false; // Skip invalid entries
                        }
                      }).toList();

                  if (filteredData.isEmpty) {
                    // Show "No data available" if filtering results in an empty list
                    return const Column(
                      children: [
                        SizedBox(height: 150),
                        Text('Nothing Parked (Others)'),
                      ],
                    );
                  }

                  // Show the filtered data in a ListView
                  return RefreshIndicator(
                    onRefresh: () async {
                      final data = await fetchOnParkingData();
                      setState(() {
                        bookingDataNotifier.value = data;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];

                          return othersdashleft(
                            currentTabIndex: 2,
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                            onExitSuccess: () {
                              final currentData =
                                  bookingDataNotifier.value.toList();
                              currentData.removeWhere(
                                (v) => v.id == vehicle.id,
                              );
                              bookingDataNotifier.value = currentData;
                              GlobalRecentExits.exitedBookingIds.add(
                                vehicle.id,
                              );
                              GlobalVendorDashCache.othersOnParking
                                  ?.removeWhere((v) => v.id == vehicle.id);
                              GlobalVendorDashCache.othersCompleted = null;
                              LocalDbService.markBookingCompletedOffline(
                                vehicle.id,
                              );
                              setState(
                                () {},
                              ); // Rebuild to refresh the Completed tab
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: FutureBuilder<List<Bookingdata>>(
                future: fetchCompletedData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Column(
                      children: [
                        SizedBox(height: 150),
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return const Column(
                      children: [
                        SizedBox(height: 150),
                        Text('Nothing Parked (Others)'),
                      ],
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Column(
                      children: [
                        SizedBox(height: 150),
                        Text('Nothing Parked (Others)'),
                      ],
                    );
                  } else {
                    final filteredData = snapshot.data!.toList();

                    print(
                      'Filtered "Others" Completed Count: ${filteredData.length}',
                    );

                    // If no filtered data, show message
                    if (filteredData.isEmpty) {
                      return const Column(
                        children: [
                          SizedBox(height: 150),
                          Text('Nothing Parked (Others)'),
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 5.0,
                      ),
                      child: ListView.separated(
                        itemCount: filteredData.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final vehicle = filteredData[index];
                          return vendordashright(
                            vehicle: vehicle,
                            vendorId: widget.vendorid,
                            bookType: vehicle.bookType ?? '',
                            defaultVendorName: widget.defaultVendorName,
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTabs() {
    return [
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.local_parking,
          //   color: selectedTabIndex == 0 ? Colors.black : Colors.black,
          // ),
          const SizedBox(width: 8),
          Text(
            'On Parking',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 0 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon(
          //   Icons.verified_outlined,
          //   color: selectedTabIndex == 1 ? Colors.black : Colors.black,
          // ),
          const SizedBox(width: 8),
          Text(
            'Completed',
            style: GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? Colors.black : Colors.black,
            ),
          ),
        ],
      ),
    ];
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(
      2,
      '0',
    ); // Ensure two digits
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0'); // Ensure two digits

    return '$hours.$minutes.$seconds'; // Format as HH.MM.SS
  }
}

class BookingAmountCalculator {
  static double calculatePayableAmount({
    required Duration duration,
    required String? bookType,
    required String parkedDate,
    required String parkedTime,
    required List<Exitcharge> parkingCharges,
    required String fullDayChargeType,
  }) {
    String bookTypeLower = (bookType ?? 'Hourly').toLowerCase();
    if (bookTypeLower == 'hourly') {
      return _calculateHourly(parkingCharges, duration);
    } else if (bookTypeLower == '24 hours' ||
        bookTypeLower == '24hours' ||
        bookTypeLower == '24hr') {
      return _calculateFullDay(
        parkingCharges,
        duration,
        parkedDate,
        parkedTime,
        bookTypeLower,
        fullDayChargeType,
      );
    }
    return 0.0;
  }

  static double _calculateFullDay(
    List<Exitcharge> charges,
    Duration duration,
    String parkedDate,
    String parkedTime,
    String bookType,
    String fullDayChargeType,
  ) {
    String chargeTypeToFind =
        fullDayChargeType.toLowerCase() == 'fullday' ? '24 Hours' : 'Full Day';

    Exitcharge? fullDayCharge;
    try {
      fullDayCharge = charges.firstWhere(
        (c) => c.type.toLowerCase() == chargeTypeToFind.toLowerCase(),
      );
    } catch (_) {
      try {
        fullDayCharge = charges.firstWhere(
          (c) => c.fullDayCharge.toLowerCase() == 'fullday',
        );
      } catch (_) {}
    }

    double fullDayAmount = fullDayCharge?.amount ?? 0.0;
    if (fullDayAmount == 0.0) return 0.0;

    DateTime? parkingStart;
    try {
      parkingStart = DateFormat(
        "dd-MM-yyyy hh:mm a",
      ).parse("$parkedDate $parkedTime");
    } catch (_) {}

    if (parkingStart == null) return fullDayAmount;

    DateTime currentTime = DateTime.now();
    int numberOfPeriods = 1;

    if (fullDayChargeType.toLowerCase() == 'full day') {
      DateTime startDate = DateTime(
        parkingStart.year,
        parkingStart.month,
        parkingStart.day,
      );
      DateTime endDate = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
      );
      numberOfPeriods = endDate.difference(startDate).inDays;
      numberOfPeriods =
          currentTime.isAfter(parkingStart) ? max(1, numberOfPeriods) : 1;
    } else {
      Duration timeElapsed = currentTime.difference(parkingStart);
      if (timeElapsed.inSeconds <= 0) {
        numberOfPeriods = 1;
      } else {
        double totalHours = timeElapsed.inSeconds / 3600.0;
        numberOfPeriods = max(1, (totalHours / 24).ceil());
      }
    }

    return fullDayAmount * numberOfPeriods;
  }

  static double _calculateHourly(List<Exitcharge> charges, Duration duration) {
    int totalHours = duration.inHours;
    if (duration.inMinutes % 60 > 0) totalHours += 1;

    final initialChargeTypes = [
      '0 to 1 hour',
      '0 to 2 hours',
      '0 to 3 hours',
      '0 to 4 hours',
    ];

    Exitcharge? initialCharge;
    int minInitialHours = 5;

    for (var charge in charges) {
      if (initialChargeTypes.contains(charge.type)) {
        try {
          int hours = int.parse(
            RegExp(r'0 to (\d+)').firstMatch(charge.type)!.group(1)!,
          );
          if (hours < minInitialHours) {
            minInitialHours = hours;
            initialCharge = charge;
          }
        } catch (_) {}
      }
    }

    initialCharge ??= charges.isNotEmpty ? charges.first : null;
    if (initialCharge == null) return 0.0;

    int initialHours = 1;
    try {
      initialHours = int.parse(
        RegExp(r'0 to (\d+)').firstMatch(initialCharge.type)!.group(1)!,
      );
    } catch (_) {}

    if (totalHours <= initialHours) return initialCharge.amount;

    double totalAmount = initialCharge.amount;
    int remainingHours = totalHours - initialHours;

    final additionalChargeTypes = [
      'Additional 1 hour',
      'Additional 2 hours',
      'Additional 3 hours',
      'Additional 4 hours',
    ];

    Exitcharge? additionalCharge;
    try {
      additionalCharge = charges.firstWhere(
        (charge) => additionalChargeTypes.contains(charge.type),
      );
    } catch (_) {
      try {
        additionalCharge = charges.firstWhere(
          (charge) => charge.type.toLowerCase().contains('additional'),
        );
      } catch (_) {}
    }

    if (additionalCharge != null) {
      int blockHours = 1;
      try {
        blockHours = int.parse(
          RegExp(
            r'Additional (\d+)',
          ).firstMatch(additionalCharge.type)!.group(1)!,
        );
      } catch (_) {}
      int blocks = (remainingHours / blockHours).ceil();
      totalAmount += blocks * additionalCharge.amount;
    }

    return totalAmount;
  }

  static double calculateTotalWithTaxes(
    double payableAmount,
    double gstPercentage,
    double handlingFee,
  ) {
    double gstAmount = ((payableAmount + handlingFee) * gstPercentage) / 100;
    double exactTotal = payableAmount + handlingFee + gstAmount;
    double decimal = exactTotal - exactTotal.floor();
    return decimal >= 0.5
        ? exactTotal.ceilToDouble()
        : exactTotal.floorToDouble();
  }
}

/// Vendor line on receipts: prefer booking record, then dashboard profile, then placeholder.
String effectivePrintVendorName(
  String bookingVendorName,
  String? defaultVendorName,
) {
  final v = bookingVendorName.trim();
  if (v.isNotEmpty) return v;
  final d = defaultVendorName?.trim() ?? '';
  if (d.isNotEmpty) return d;
  return 'Vendor';
}

// Universal Printer Helper - Supports both Sunmi and Pinelabs (ESC/POS) printers
class UniversalPrintHelper {
  static const String _printerTroubleshootMsg =
      'Printer unavailable. For Sumi: (1) Enable Mobile Printer in Settings > Local Services, '
      '(2) Restart app. For Sunmi: (1) Enable Mobile Printer in Settings > Local Services, '
      '(2) Restart app. For Pinelabs: (1) Enable Mobile Printer in Settings, '
      '(2) For external: Pair via Bluetooth, (3) Enable permissions.';

  static const Duration _bindTimeout = Duration(seconds: 2);
  static const Duration _initTimeout = Duration(seconds: 2);
  static const Duration _btCheckTimeout = Duration(seconds: 2);
  static const Duration _btConnectTimeout = Duration(seconds: 3);
  static const Duration _chargeLookupTimeout = Duration(seconds: 4);
  static const Duration _printerCacheTtl = Duration(minutes: 15);

  static String? _cachedPrinterType;
  static String? _cachedBluetoothMac;
  static bool _sunmiBoundAndInited = false;
  static DateTime? _printerCacheAt;

  static void _rememberPrinter(String type, {String? bluetoothMac}) {
    _cachedPrinterType = type;
    _printerCacheAt = DateTime.now();
    if (bluetoothMac != null && bluetoothMac.isNotEmpty) {
      _cachedBluetoothMac = bluetoothMac;
    }
  }

  static void _clearPrinterCache() {
    _cachedPrinterType = null;
    _cachedBluetoothMac = null;
    _sunmiBoundAndInited = false;
    _printerCacheAt = null;
  }

  /// Full invoice ID for receipts (no truncation, no Mongo _id).
  static String formatReceiptBookingId(String? invoiceId) {
    return (invoiceId ?? '').trim();
  }

  /// Formats a line of text enclosed in a rectangular ASCII box for thermal receipt printing.
  static List<String> formatBoxedLines(String text) {
    final clean = text.trim();
    final int innerWidth = clean.length + 2;
    final String border = '+${'-' * innerWidth}+';
    final String middle = '| $clean |';
    return [border, middle, border];
  }

  static String? _extractInvoiceIdFromMap(Map<String, dynamic> map) {
    for (final key in ['invoiceid', 'invoiceId', 'invoice_id']) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Reads invoice id from create-booking / get-booking JSON (root or nested).
  static String extractInvoiceIdFromJson(Map<String, dynamic> json) {
    final direct = _extractInvoiceIdFromMap(json);
    if (direct != null) return direct;
    final booking = json['booking'];
    if (booking is Map<String, dynamic>) {
      final nested = _extractInvoiceIdFromMap(booking);
      if (nested != null) return nested;
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final nested = _extractInvoiceIdFromMap(data);
      if (nested != null) return nested;
    }
    return '';
  }

  static Future<String> resolveInvoiceIdForPrint({
    String? invoiceId,
    required String bookingId,
  }) async {
    // 1. If we have a permanent offline ID mapping, ALWAYS use it first so receipts match
    final mappedOfflineId = LocalDbService.getOfflineMappedId(bookingId);
    if (mappedOfflineId != null && mappedOfflineId.isNotEmpty) {
      return mappedOfflineId;
    }

    final passed = (invoiceId ?? '').trim();
    if (passed.isNotEmpty) return passed;
    if (bookingId.trim().isEmpty) return '';

    final fetched = await fetchInvoiceIdForBooking(bookingId);
    if (fetched.isNotEmpty) return fetched;

    // Fallback: If no invoice ID is found and it's a long Mongo ID, format it to a short ID.
    if (bookingId.length == 24) {
      try {
        final counter = int.parse(bookingId.substring(18), radix: 16);
        return 'PMW$counter';
      } catch (_) {
        return 'PMW${bookingId.substring(18).toUpperCase()}';
      }
    }

    return bookingId;
  }

  static Future<String> fetchInvoiceIdForBooking(String bookingId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getbooking/$bookingId');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return extractInvoiceIdFromJson(decoded);
        }
      }
    } catch (e) {
      print('fetchInvoiceIdForBooking error: $e');
    }
    return '';
  }

  static bool _isBuiltinPrinterType(String type) =>
      type == 'sunmi' || type == 'sumi' || type == 'pinelabs_builtin';

  static Future<bool> _bindAndInitSunmi({
    bool init = true,
    bool forceBind = false,
  }) async {
    if (_sunmiBoundAndInited && !forceBind) return true;
    try {
      final bool? bound = await SunmiPrinterPlus().rebindPrinter().timeout(
        _bindTimeout,
      );
      if (bound != true) return false;
      // initPrinter is no longer required in sunmi_printer_plus 4.x
      _sunmiBoundAndInited = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _tryCachedPrinter() async {
    final cached = _cachedPrinterType;
    final cachedAt = _printerCacheAt;
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > _printerCacheTtl) {
      _clearPrinterCache();
      return null;
    }

    if (_isBuiltinPrinterType(cached)) {
      if (cached == 'pinelabs_builtin') {
        return 'pinelabs_builtin';
      }
      if (_sunmiBoundAndInited) return 'sunmi';
      if (await _bindAndInitSunmi()) {
        _rememberPrinter('sunmi');
        return 'sunmi';
      }
      return null;
    }

    if (cached == 'bluetooth') {
      try {
        final connected = await PrintBluetoothThermal.connectionStatus.timeout(
          _btCheckTimeout,
        );
        if (connected) return 'bluetooth';

        final mac = _cachedBluetoothMac;
        if (mac != null && mac.isNotEmpty) {
          final ok = await PrintBluetoothThermal.connect(
            macPrinterAddress: mac,
          ).timeout(_btConnectTimeout);
          if (ok) return 'bluetooth';
        }
      } catch (_) {}
      return null;
    }

    return null;
  }

  /// Parse date/time received from backend into a [DateTime].
  /// Backend time formats vary (e.g. `hh:mm a` vs `HH:mm`), especially for exit/completed.
  static DateTime? tryParseDateTime({
    required String date,
    required String time,
  }) {
    final d = date.trim();
    final t = time.trim();
    if (d.isEmpty || t.isEmpty) return null;

    final combined = '$d $t';

    // Try common formats used by this app/backends.
    const patterns = <String>[
      'dd-MM-yyyy hh:mm a',
      'dd-MM-yyyy hh:mm:ss a',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm:ss.SSS',
    ];

    for (final p in patterns) {
      try {
        return DateFormat(p).parse(combined);
      } catch (_) {
        // Try next pattern
      }
    }
    return null;
  }

  static String? _extractAmountFromMap(Map<String, dynamic> map) {
    // Backend key naming is inconsistent (typos/casing), so check multiple options.
    const candidates = <String>[
      'amount',
      'payableAmount',
      'payable_amount',
      'totalamout', // existing typo in other parts of the code
      'totalAmount',
      'recievableamount', // spelling used in Bookingdata debug
      'receivableAmount',
      'recievable_amount',
    ];

    for (final key in candidates) {
      final v = map[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      return s;
    }
    return null;
  }

  static String _formatMoney(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    if (value == value.roundToDouble()) return value.round().toString();
    final s = value.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\\.00$'), '');
  }

  /// Fetches the full-day charge for [vehicleType] from getchargesdata API.
  /// Returns the amount string, or null if not found.
  static Future<String?> _getFullDayChargeFromAPI({
    required String vendorId,
    required String vehicleType,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final Map<String, dynamic>? dataMap =
          data is Map<String, dynamic> ? data : null;
      final dynamic chargesJson = dataMap?['vendor']?['charges'];
      if (chargesJson is! List) return null;

      final vt = vehicleType.trim().toLowerCase();
      bool categoryMatches(String? cat) {
        if (cat == null) return false;
        final cc = cat.trim().toLowerCase();
        if (cc == vt) return true;
        if (vt == 'others' && cc == 'other') return true;
        if (vt == 'other' && cc == 'others') return true;
        return false;
      }

      for (final c in chargesJson.whereType<Map>()) {
        final type = c['type']?.toString().trim() ?? '';
        final cat = c['category']?.toString();
        if (!categoryMatches(cat)) continue;
        if (RegExp(r'full\s*day', caseSensitive: false).hasMatch(type)) {
          final amt = double.tryParse(c['amount']?.toString() ?? '');
          if (amt != null) {
            return amt == amt.roundToDouble()
                ? amt.round().toString()
                : amt.toStringAsFixed(2);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches hourly slab pricing and returns 0-4 hours + additional-per-hour lines.
  /// If the API does not return expected slabs, it returns an empty list.
  static Future<List<String>> _getHourlyPricingSlabLines({
    required String vendorId,
    required String vehicleType,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fetch-exit-charges?vendor_id=$vendorId&vehicleType=$vehicleType',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body);
      final chargesJson = data['charges'];
      if (chargesJson is! List) return const [];

      final charges =
          chargesJson
              .map(
                (item) =>
                    Exitcharge.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList();

      Exitcharge? baseCharge;

      // Pick the "0 to X hours" slab with the largest hour window (the configured minimum period).
      {
        final slabRe = RegExp(
          r'^0\s*(?:to|-)\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
          caseSensitive: false,
        );
        int? bestHours;
        for (final c in charges) {
          final m = slabRe.firstMatch(c.type.trim());
          if (m == null) continue;
          final hours = int.tryParse(m.group(1) ?? '');
          if (hours == null) continue;
          if (bestHours == null || hours > bestHours) {
            bestHours = hours;
            baseCharge = c;
          }
        }
      }

      Exitcharge? additionalCharge;

      // Prefer explicit "Additional per hour" charge.
      try {
        additionalCharge = charges.firstWhere(
          (c) =>
              c.type.toLowerCase().contains('additional') &&
              c.type.toLowerCase().contains('per hour'),
        );
      } catch (_) {}

      // Otherwise pick the largest "Additional X hour(s)" slab (matches the configured block).
      if (additionalCharge == null) {
        final candidates =
            charges.where((c) {
              return RegExp(
                r'additional\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
                caseSensitive: false,
              ).hasMatch(c.type);
            }).toList();

        Exitcharge? chosen;
        int? maxAdditionalHours;
        for (final c in candidates) {
          final match = RegExp(
            r'additional\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
            caseSensitive: false,
          ).firstMatch(c.type);
          final blockHours = int.tryParse(match?.group(1) ?? '');
          if (blockHours == null || blockHours <= 0) continue;
          if (maxAdditionalHours == null || blockHours > maxAdditionalHours) {
            maxAdditionalHours = blockHours;
            chosen = c;
          }
        }
        additionalCharge = chosen;

        if (additionalCharge == null) {
          try {
            additionalCharge = charges.firstWhere(
              (c) => c.type.toLowerCase().contains('additional'),
            );
          } catch (_) {}
        }
      }

      final lines = <String>[];
      if (baseCharge != null) {
        lines.add(
          '${baseCharge.type.trim()} : Rs. ${_formatMoney(baseCharge.amount)}',
        );
      }
      if (additionalCharge != null) {
        lines.add(
          '${additionalCharge.type.trim()} : Rs. ${_formatMoney(additionalCharge.amount)}',
        );
      }
      return lines;
    } catch (_) {
      return const [];
    }
  }

  /// Hourly pricing slabs for ENTRY receipts (vendor create booking).
  /// Source API matches `vendor/getchargesdata/<vendorId>` used in `vendorcreatebooking.dart`.
  static Future<List<String>> _getEntryHourlyPricingSlabLines({
    required String vendorId,
    required String vehicleType,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body);
      final Map<String, dynamic>? dataMap =
          data is Map<String, dynamic> ? data as Map<String, dynamic> : null;
      final dynamic chargesJson = dataMap?['vendor']?['charges'];
      if (chargesJson is! List) return const [];

      // Normalize vehicleType matching (backend might use `Other` vs `Others`)
      final vt = vehicleType.trim().toLowerCase();
      bool categoryMatches(String? chargeCategory) {
        if (chargeCategory == null) return false;
        final cc = chargeCategory.trim().toLowerCase();
        if (cc == vt) return true;
        if (vt == 'others' && cc == 'other') return true;
        if (vt == 'other' && cc == 'others') return true;
        return false;
      }

      String? getType(dynamic charge) =>
          charge is Map ? charge['type']?.toString() : null;
      dynamic getAmount(dynamic charge) =>
          charge is Map ? charge['amount'] : null;
      String? getCategory(dynamic charge) =>
          charge is Map ? charge['category']?.toString() : null;

      final allCharges = chargesJson.whereType<Map>().toList();
      final hourlyCharges =
          allCharges.where((c) => categoryMatches(getCategory(c))).toList();

      if (hourlyCharges.isEmpty) return const [];

      // Pick the "0 to X hours" slab with the largest hour window (the configured minimum period).
      Map<String, dynamic>? baseCharge;
      {
        final slabRe = RegExp(
          r'^0\s*(?:to|-)\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
          caseSensitive: false,
        );
        int? bestHours;
        for (final c in hourlyCharges) {
          final t = getType(c) ?? '';
          final m = slabRe.firstMatch(t.trim());
          if (m == null) continue;
          final hours = int.tryParse(m.group(1) ?? '');
          if (hours == null) continue;
          if (bestHours == null || hours > bestHours) {
            bestHours = hours;
            baseCharge = Map<String, dynamic>.from(c as Map);
          }
        }
      }

      // Pick the additional charge to display:
      // - Prefer explicit "Additional ... per hour"
      // - Otherwise pick largest "Additional X hours" slab (matches the configured block)
      Map<String, dynamic>? additionalCharge;

      for (final c in hourlyCharges) {
        final t = getType(c) ?? '';
        final lower = t.toLowerCase();
        if (lower.contains('additional') && lower.contains('per hour')) {
          additionalCharge = Map<String, dynamic>.from(c as Map);
          break;
        }
      }

      if (additionalCharge == null) {
        final candidates =
            hourlyCharges.where((c) {
              final t = getType(c) ?? '';
              return RegExp(
                r'additional\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
                caseSensitive: false,
              ).hasMatch(t);
            }).toList();

        int? maxAdditionalHours;
        for (final c in candidates) {
          final t = getType(c) ?? '';
          final match = RegExp(
            r'additional\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
            caseSensitive: false,
          ).firstMatch(t);
          final blockHours = int.tryParse(match?.group(1) ?? '');
          if (blockHours == null || blockHours <= 0) continue;
          if (maxAdditionalHours == null || blockHours > maxAdditionalHours) {
            maxAdditionalHours = blockHours;
            additionalCharge = Map<String, dynamic>.from(c as Map);
          }
        }

        if (additionalCharge == null) {
          for (final c in hourlyCharges) {
            final t = getType(c) ?? '';
            if (t.toLowerCase().contains('additional')) {
              additionalCharge = Map<String, dynamic>.from(c as Map);
              break;
            }
          }
        }
      }

      final lines = <String>[];

      if (baseCharge != null) {
        final baseType = baseCharge['type']?.toString() ?? '';
        final amt = double.tryParse(baseCharge['amount']?.toString() ?? '');
        final formatted =
            amt != null
                ? _formatMoney(amt)
                : (baseCharge['amount']?.toString() ?? '0');
        lines.add('$baseType : Rs. $formatted');
      }

      if (additionalCharge != null) {
        final addType = getType(additionalCharge) ?? '';
        final addAmt = double.tryParse(
          getAmount(additionalCharge)?.toString() ?? '',
        );
        final addFormatted =
            addAmt != null
                ? _formatMoney(addAmt)
                : (getAmount(additionalCharge)?.toString() ?? '0');
        lines.add('$addType : Rs. $addFormatted');
      }

      return lines;
    } catch (_) {
      return const [];
    }
  }

  // Detect available printer type (cached after first success for faster reprints).
  static Future<String> detectPrinterType({bool fast = false}) async {
    if (!Platform.isAndroid) return 'none';

    if (fast) {
      final cached = await _tryCachedPrinter();
      if (cached != null) {
        print('Printer: using cached $cached');
        return cached;
      }
    }

    // Try Sunmi first on POS devices (instant AIDL binding ~10ms vs PineLabs timeout)
    if (await _tryBindSunmiPrinter(maxRetries: fast ? 1 : 2)) {
      _rememberPrinter('sunmi');
      return 'sunmi';
    }

    final pineLabsType = await PineLabsPrintHelper.detectPineLabsPrinter();
    if (pineLabsType == 'pinelabs_builtin') {
      _rememberPrinter('pinelabs_builtin');
      return 'pinelabs_builtin';
    }

    print('=== Printer detection (Bluetooth) ===');

    try {
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }

      final bool bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled
          .timeout(_btCheckTimeout);
      print('Bluetooth enabled: $bluetoothEnabled');
      if (bluetoothEnabled) {
        final List<BluetoothInfo> printers = await PrintBluetoothThermal
            .pairedBluetooths
            .timeout(_btCheckTimeout);
        print('Bluetooth paired printers: ${printers.length}');
        for (var p in printers) {
          print('Paired Printer: ${p.name} - ${p.macAdress}');
        }
        if (printers.isNotEmpty) {
          _rememberPrinter('bluetooth', bluetoothMac: printers.first.macAdress);
          print('Bluetooth printer available: ${printers.first.name}');
          return 'bluetooth';
        } else {
          print('No paired Bluetooth printers found.');
        }
      } else {
        print('Bluetooth is NOT enabled on the device.');
      }
    } catch (e) {
      print('Bluetooth detection error: $e');
    }

    _clearPrinterCache();
    print('No compatible printer detected');
    return 'none';
  }

  /// Bind/detect printer when the booking screen opens so Book & Print is faster.
  static Future<void> warmUpPrinter() async {
    if (!Platform.isAndroid) return;
    try {
      await detectPrinterType(fast: false);
    } catch (e) {
      print('Printer warm-up skipped: $e');
    }
  }

  // Connect to Bluetooth printer (reuses cache + existing connection).
  static Future<bool> connectBluetoothPrinter() async {
    try {
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }
      try {
        final bool alreadyConnected = await PrintBluetoothThermal
            .connectionStatus
            .timeout(_btCheckTimeout);
        if (alreadyConnected) return true;
      } catch (_) {}

      final cachedMac = _cachedBluetoothMac;
      if (cachedMac != null && cachedMac.isNotEmpty) {
        try {
          final bool connected = await PrintBluetoothThermal.connect(
            macPrinterAddress: cachedMac,
          ).timeout(_btConnectTimeout);
          if (connected) return true;
        } catch (_) {}
      }

      final bool bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled
          .timeout(_btCheckTimeout);
      if (!bluetoothEnabled) return false;

      final List<BluetoothInfo> printers = await PrintBluetoothThermal
          .pairedBluetooths
          .timeout(_btCheckTimeout);
      if (printers.isEmpty) return false;

      for (final printer in printers) {
        try {
          final bool connected = await PrintBluetoothThermal.connect(
            macPrinterAddress: printer.macAdress,
          ).timeout(_btConnectTimeout);
          if (connected) {
            _cachedBluetoothMac = printer.macAdress;
            return true;
          }
        } catch (_) {}
      }
      return false;
    } catch (e) {
      print('Bluetooth connection error: $e');
      return false;
    }
  }

  // Print using Sunmi printer
  static Future<void> _printWithSunmi({
    required String vendorId,
    required String vendorName,
    required String bookingId,
    String? invoiceId,
    required String vehicleType,
    required String vehicleNumber,
    required String parkingDate,
    required String parkingTime,
    required String amount,
    required String personName,
    required String mobileNumber,
    String? duration,
    String? sts,
    String? bookType,
    bool skipChargeLookup = false,
    bool instantParkingReceipt = false,
    bool isPrintAndExit = false,
    double? valetCharge,
    String? operationalTimings,
    bool isEntryReceipt = false,
  }) async {
    final String headerVendorName =
        vendorName.trim().isEmpty ? 'Vendor' : vendorName.trim();
    final displayId = formatReceiptBookingId(invoiceId);

    // Calculate duration if not provided
    String durationText = duration ?? '0 hr 00 min';
    if (duration == null || duration.isEmpty) {
      final DateTime? parkingDateTime = tryParseDateTime(
        date: parkingDate,
        time: parkingTime,
      );

      if (parkingDateTime != null) {
        Duration calcDuration = DateTime.now().difference(parkingDateTime);
        if (!calcDuration.isNegative) {
          final hours = calcDuration.inHours.toString().padLeft(2, '0');
          final minutes = calcDuration.inMinutes
              .remainder(60)
              .toString()
              .padLeft(2, '0');
          durationText = '$hours Hours $minutes Minutes';
        }
      }
    }
    if (isPrintAndExit &&
        (durationText.isEmpty ||
            durationText == '0 hr 00 min' ||
            durationText == '00 Hours 00 Minutes')) {
      durationText = '00 Hours 01 Minute';
    }

    // Increased top spacing to prevent clipping first letter
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      headerVendorName,
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );
    // Directly print separator after vendor name (no big gap)
    await SunmiPrinter.printText(
      '**************************',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.printText(
      'Parking Receipt',
      style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('Booking ID : $displayId');
    await SunmiPrinter.lineWrap(1);
    // Determine vehicle label
    String vehicleLabel = "$vehicleType Number";
    if (vehicleType.toLowerCase() == 'others') {
      vehicleLabel = "Vehicle Number";
    }

    await SunmiPrinter.printText("$vehicleLabel : $vehicleNumber");
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText("Parked on : $parkingDate, $parkingTime");
    await SunmiPrinter.lineWrap(1);

    List<String> slabLines = const [];
    if (!skipChargeLookup) {
      try {
        slabLines = await _getHourlyPricingSlabLines(
          vendorId: vendorId,
          vehicleType: vehicleType,
        ).timeout(_chargeLookupTimeout, onTimeout: () => const []);
      } catch (_) {
        slabLines = const [];
      }
    }
    // Always print duration (COMPLETED receipts may also have slab lines, but user expects duration).
    if (durationText.trim().isNotEmpty) {
      await SunmiPrinter.printText("Duration : $durationText");
      await SunmiPrinter.lineWrap(1);
    }
    final stsNorm = sts?.trim().toLowerCase() ?? '';
    final passMatch = RegExp(
      r'^(\d+)hr$',
      caseSensitive: false,
    ).firstMatch(stsNorm);
    final v = double.tryParse(amount.toString().trim());
    double finalAmtSunmi = v ?? 0.0;
    if (!isPrintAndExit && valetCharge != null && valetCharge > 0) {
      finalAmtSunmi += valetCharge;
      if (GlobalVendorDashCache.vendor != null && _isInstantBookingStrings(sts, bookType)) {
        final cap = GlobalVendorDashCache.vendor!.maxCarAmount;
        if (cap > 0 && finalAmtSunmi > cap && vehicleType.toLowerCase().contains('car')) {
          finalAmtSunmi = cap;
        }
      }
    }
    final cleanedAmt =
        (v == null && (valetCharge == null || valetCharge == 0 || isPrintAndExit))
            ? amount.trim()
            : (finalAmtSunmi == finalAmtSunmi.roundToDouble()
                ? finalAmtSunmi.round().toString()
                : finalAmtSunmi.toStringAsFixed(2));

    if (passMatch != null) {
      // Pass booking (12hr / 24hr / 48hr / 72hr)
      final passHours = passMatch.group(1);
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        await SunmiPrinter.lineWrap(1);
        final label = passHours == '24' ? 'Full Day' : '$passHours Hour';
        await SunmiPrinter.printText('$label Pass');
        await SunmiPrinter.lineWrap(1);
        for (final line in formatBoxedLines('Parking Amount : Rs. $cleanedAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else if (stsNorm == 'weekly' || stsNorm == 'monthly') {
      // Subscription: print weekly / monthly label with the booking amount
      final label = stsNorm == 'weekly' ? 'Weekly' : 'Monthly';
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        await SunmiPrinter.lineWrap(1);
        for (final line in formatBoxedLines('$label : Rs. $cleanedAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else if ((bookType ?? '').trim().toLowerCase() == '24 hours' &&
        !skipChargeLookup) {
      String? fullDayAmt;
      try {
        fullDayAmt = await _getFullDayChargeFromAPI(
          vendorId: vendorId,
          vehicleType: vehicleType,
        ).timeout(_chargeLookupTimeout);
      } catch (_) {
        fullDayAmt = null;
      }
      final displayAmt =
          (fullDayAmt != null && fullDayAmt.isNotEmpty && fullDayAmt != '0')
              ? fullDayAmt
              : cleanedAmt;
      if (displayAmt.isNotEmpty && displayAmt != '0') {
        await SunmiPrinter.lineWrap(1);
        for (final line in formatBoxedLines('Full Day : Rs. $displayAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else {
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        if (!instantParkingReceipt || isPrintAndExit) {
          await SunmiPrinter.lineWrap(1);
          for (final line in formatBoxedLines('Parking Amount : Rs. $cleanedAmt')) {
            await SunmiPrinter.printText(
              line,
              style: SunmiTextStyle(bold: true),
            );
            await SunmiPrinter.lineWrap(1);
          }
        }
      }
    }

    if (bookingId.isNotEmpty && !isPrintAndExit) {
      await SunmiPrinter.printText('\u00A0\n\u00A0'); // Extra space before QR
      await SunmiPrinter.printQRCode(
        bookingId,
        style: SunmiQrcodeStyle(align: SunmiPrintAlign.CENTER, qrcodeSize: 7),
      );
      await SunmiPrinter.printText('\u00A0\n\u00A0'); // Extra space after QR
    }

    if (operationalTimings != null && operationalTimings.isNotEmpty) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Timings : $operationalTimings');
    }

    if (!isPrintAndExit) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        'we are not responsible for any belongings inside and outside of the vehicle.',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      );
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      '**************************',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.lineWrap(1); // Ensure "Powered by" starts on next line
    await SunmiPrinter.printText(
      'Powered by ParkMyWheels',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );

    // Bottom spacing - using non-breaking spaces and a dot to completely defeat the printer's whitespace trimmer
    await SunmiPrinter.printText('\u00A0\n\u00A0\n\u00A0\n\u00A0\n.');
  }

  // Print using ESC/POS (Pinelabs) printer with basic commands
  static Future<void> printWithESCPOS({
    required String vendorId,
    required String vendorName,
    required String bookingId,
    String? invoiceId,
    required String vehicleType,
    required String vehicleNumber,
    required String parkingDate,
    required String parkingTime,
    required String amount,
    required String personName,
    required String mobileNumber,
    String? duration,
    bool includeDuration = true,
    bool isEntryReceipt = false,
    String? sts,
    String? bookType,
    bool skipChargeLookup = false,
    List<String>? slabLinesOverride,
    bool instantParkingReceipt = false,
    bool isPrintAndExit = false,
    double? valetCharge,
    String? operationalTimings,
  }) async {
    final String headerVendorName =
        vendorName.trim().isEmpty ? 'Vendor' : vendorName.trim();
    final displayId = formatReceiptBookingId(invoiceId);

    // Calculate duration only when it will be printed.
    String durationText = duration ?? '0 hr 00 min';
    if (includeDuration && (duration == null || duration.isEmpty)) {
      final DateTime? parkingDateTime = tryParseDateTime(
        date: parkingDate,
        time: parkingTime,
      );

      if (parkingDateTime != null) {
        Duration calcDuration = DateTime.now().difference(parkingDateTime);
        if (!calcDuration.isNegative) {
          final hours = calcDuration.inHours.toString().padLeft(2, '0');
          final minutes = calcDuration.inMinutes
              .remainder(60)
              .toString()
              .padLeft(2, '0');
          durationText = '$hours Hours $minutes Minutes';
        }
      }
    }

    // If duration is effectively zero, don't print it on entry receipts.
    final normalizedDuration = durationText.trim().toLowerCase();
    final bool isZeroDuration =
        normalizedDuration == '0 hr 00 min' ||
        normalizedDuration == '00 hours 00 minutes' ||
        normalizedDuration == '0 hours 0 minutes';
    if (isZeroDuration) {
      if (isPrintAndExit) {
        durationText = '00 Hours 01 Minute';
      } else {
        durationText = '';
      }
    }

    List<String> slabLines = slabLinesOverride ?? const [];
    if (slabLines.isEmpty && !skipChargeLookup) {
      try {
        slabLines =
            isEntryReceipt
                ? await _getEntryHourlyPricingSlabLines(
                  vendorId: vendorId,
                  vehicleType: vehicleType,
                ).timeout(_chargeLookupTimeout, onTimeout: () => const [])
                : await _getHourlyPricingSlabLines(
                  vendorId: vendorId,
                  vehicleType: vehicleType,
                ).timeout(_chargeLookupTimeout, onTimeout: () => const []);
      } catch (_) {
        slabLines = const [];
      }
    }

    // Basic ESC/POS commands for thermal printer
    List<int> bytes = [];

    // Initialize printer
    bytes += [0x1B, 0x40]; // ESC @

    // Reduced top spacing - adding back a bit to prevent clipping
    bytes += [0x0A]; // Line feed

    // Header - Vendor Name (Centered, Bold)
    bytes += [0x1B, 0x45]; // ESC E
    bytes += [0x1B, 0x01]; // SOH
    bytes += [0x1B, 0x61, 0x01]; // ESC a 1 (Centered)
    bytes += headerVendorName.codeUnits; // Vendor name
    bytes += [0x0A]; // Line feed

    // Separator
    bytes += '**************************'.codeUnits;
    bytes += [0x0A]; // Line feed

    // Title - Parking Receipt (Right aligned)
    bytes += [0x1B, 0x45]; // ESC E
    bytes += [0x1B, 0x01]; // SOH
    bytes += [0x1B, 0x61, 0x02]; // ESC a 2 (Right)
    bytes += 'Parking Receipt'.codeUnits; // Title
    bytes += [0x0A]; // Line feed
    bytes += [0x1B, 0x61, 0x00]; // ESC a 0 (Left) for following lines

    // Booking ID (Left aligned)
    bytes += 'Booking ID : $displayId'.codeUnits; // Booking ID
    bytes += [0x0A]; // Line feed

    // Determine vehicle label
    String vehicleLabel = "$vehicleType Number";
    if (vehicleType.toLowerCase() == 'others') {
      vehicleLabel = "Vehicle Number";
    }

    // Vehicle Number (Left aligned)
    bytes += '$vehicleLabel : $vehicleNumber'.codeUnits;
    bytes += [0x0A]; // Line feed

    // Parked on (Left aligned)
    bytes += 'Parked on : $parkingDate, $parkingTime'.codeUnits;
    bytes += [0x0A]; // Line feed

    // Optionally print duration, then slab lines (if any).
    if (includeDuration && durationText.trim().isNotEmpty) {
      bytes += 'Duration : $durationText'.codeUnits;
      bytes += [0x0A]; // Line feed
    }
    final stsNormEsc = sts?.trim().toLowerCase() ?? '';
    final passMatchEsc = RegExp(
      r'^(\d+)hr$',
      caseSensitive: false,
    ).firstMatch(stsNormEsc);
    final escV = double.tryParse(amount.toString().trim());
    double finalAmtEsc = escV ?? 0.0;
    if (!isPrintAndExit && valetCharge != null && valetCharge > 0) {
      finalAmtEsc += valetCharge;
      if (GlobalVendorDashCache.vendor != null && _isInstantBookingStrings(sts, bookType)) {
        final cap = GlobalVendorDashCache.vendor!.maxCarAmount;
        if (cap > 0 && finalAmtEsc > cap && vehicleType.toLowerCase().contains('car')) {
          finalAmtEsc = cap;
        }
      }
    }
    final cleanedEscAmt =
        (escV == null && (valetCharge == null || valetCharge == 0 || isPrintAndExit))
            ? amount.trim()
            : (finalAmtEsc == finalAmtEsc.roundToDouble()
                ? finalAmtEsc.round().toString()
                : finalAmtEsc.toStringAsFixed(2));

    if (passMatchEsc != null) {
      // Pass booking: print pass label + amount
      final passHours = passMatchEsc.group(1);
      if (cleanedEscAmt.isNotEmpty && cleanedEscAmt != '0') {
        final label = passHours == '24' ? 'Full Day' : '$passHours Hour';
        bytes += '$label Pass'.codeUnits;
        bytes += [0x0A];
        bytes += [0x1B, 0x45, 0x01, 0x1B, 0x47, 0x01]; // ESC E 1 + ESC G 1 (Bold ON)
        for (final line in formatBoxedLines('Parking Amount : Rs. $cleanedEscAmt')) {
          bytes += line.codeUnits;
          bytes += [0x0A];
        }
        bytes += [0x1B, 0x45, 0x00, 0x1B, 0x47, 0x00]; // Bold OFF
      }
    } else if (stsNormEsc == 'weekly' || stsNormEsc == 'monthly') {
      // Subscription
      final label = stsNormEsc == 'weekly' ? 'Weekly' : 'Monthly';
      if (cleanedEscAmt.isNotEmpty && cleanedEscAmt != '0') {
        bytes += [0x1B, 0x45, 0x01, 0x1B, 0x47, 0x01]; // ESC E 1 + ESC G 1 (Bold ON)
        for (final line in formatBoxedLines('$label : Rs. $cleanedEscAmt')) {
          bytes += line.codeUnits;
          bytes += [0x0A];
        }
        bytes += [0x1B, 0x45, 0x00, 0x1B, 0x47, 0x00]; // Bold OFF
      }
    } else if ((bookType ?? '').trim().toLowerCase() == '24 hours') {
      String? fullDayAmt;
      if (!skipChargeLookup) {
        try {
          fullDayAmt = await _getFullDayChargeFromAPI(
            vendorId: vendorId,
            vehicleType: vehicleType,
          ).timeout(_chargeLookupTimeout);
        } catch (_) {
          fullDayAmt = null;
        }
      }
      final displayAmt =
          (fullDayAmt != null && fullDayAmt.isNotEmpty && fullDayAmt != '0')
              ? fullDayAmt
              : cleanedEscAmt;
      if (displayAmt.isNotEmpty && displayAmt != '0') {
        bytes += [0x1B, 0x45, 0x01, 0x1B, 0x47, 0x01]; // ESC E 1 + ESC G 1 (Bold ON)
        for (final line in formatBoxedLines('Full Day : Rs. $displayAmt')) {
          bytes += line.codeUnits;
          bytes += [0x0A];
        }
        bytes += [0x1B, 0x45, 0x00, 0x1B, 0x47, 0x00]; // Bold OFF
      }
    } else {
      if (cleanedEscAmt.isNotEmpty && cleanedEscAmt != '0') {
        if (!instantParkingReceipt || isPrintAndExit) {
          bytes += [0x1B, 0x45, 0x01, 0x1B, 0x47, 0x01]; // ESC E 1 + ESC G 1 (Bold ON)
          for (final line in formatBoxedLines('Parking Amount : Rs. $cleanedEscAmt')) {
            bytes += line.codeUnits;
            bytes += [0x0A];
          }
          bytes += [0x1B, 0x45, 0x00, 0x1B, 0x47, 0x00]; // Bold OFF
        }
      }
    }

    if (bookingId.isNotEmpty && !isPrintAndExit) {
      bytes += [0x1B, 0x61, 0x01]; // ESC a 1 (Centered)

      // PineLabs firmware does not support native ESC/POS QR generation
      // Render the QR code to an image first
      final qrCode = QrCode(4, QrErrorCorrectLevel.M);
      qrCode.addData(bookingId);
      final qrImage = QrImage(qrCode);

      final size = qrImage.moduleCount;
      final scale = 8;
      final imgSize = size * scale;

      final image = img.Image(width: imgSize, height: imgSize);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      for (int x = 0; x < size; x++) {
        for (int y = 0; y < size; y++) {
          if (qrImage.isDark(y, x)) {
            img.fillRect(
              image,
              x1: x * scale,
              y1: y * scale,
              x2: (x + 1) * scale - 1,
              y2: (y + 1) * scale - 1,
              color: img.ColorRgb8(0, 0, 0),
            );
          }
        }
      }

      // Convert the rendered image to ESC/POS raster byte commands (GS v 0)
      int widthBytes = (imgSize + 7) ~/ 8;
      bytes += [0x1D, 0x76, 0x30, 0x00];
      bytes += [widthBytes % 256, widthBytes ~/ 256];
      bytes += [imgSize % 256, imgSize ~/ 256];
      for (int y = 0; y < imgSize; y++) {
        for (int x = 0; x < widthBytes; x++) {
          int byte = 0;
          for (int b = 0; b < 8; b++) {
            int pX = x * 8 + b;
            if (pX < imgSize) {
              final pixel = image.getPixel(pX, y);
              if (pixel.r == 0 && pixel.g == 0 && pixel.b == 0) {
                byte |= (1 << (7 - b));
              }
            }
          }
          bytes.add(byte);
        }
      }
      bytes += [0x0A]; // Line feed
    }

    if (operationalTimings != null && operationalTimings.isNotEmpty) {
      bytes += [0x1B, 0x61, 0x01]; // ESC a 1 (Centered)
      bytes += 'Timings : $operationalTimings'.codeUnits;
      bytes += [0x0A]; // Line feed
    }

    if (!isPrintAndExit) {
      // Separator above footer — center
      bytes += [0x1B, 0x61, 0x01]; // ESC a 1 (Centered)
      bytes +=
          'we are not responsible for any belongings inside and outside of the vehicle.'
              .codeUnits;
      bytes += [0x0A]; // Line feed
    }
    bytes += '**************************'.codeUnits;
    bytes += [0x0A]; // Line feed (footer on next line)
    // Footer - Powered by (Centered)
    bytes += [0x1B, 0x45]; // ESC E
    bytes += [0x1B, 0x01]; // SOH
    bytes += [0x1B, 0x61, 0x01]; // ESC a 1 (Centered)
    bytes += 'Powered by ParkMyWheels'.codeUnits; // Footer
    // Bottom spacing
    bytes += [0x0A]; // Line feed
    bytes += [0x0A]; // Line feed
    bytes += [0x0A]; // Line feed
    bytes += [0x0A]; // Line feed

    // Send to printer
    bool connected = await PrintBluetoothThermal.connectionStatus;
    if (connected) {
      bool result = await PrintBluetoothThermal.writeBytes(bytes);
      if (result) {
        print('ESC/POS print successful');
      } else {
        print('ESC/POS print failed');
      }
    } else {
      print('ESC/POS printer not connected');
    }
  }

  // Main print method - automatically detects and uses available printer
  static Future<void> printTicket({
    required BuildContext context,
    required String vendorName,
    required String bookingId,
    String? invoiceId,
    required String vehicleType,
    required String vehicleNumber,
    required String parkingDate,
    required String parkingTime,
    required String amount,
    required String personName,
    required String mobileNumber,
    required String vendorId,
    required String bookType,
    String? sts,
    String? preCalculatedDuration,
    bool fastPrint = true,
    bool instantParkingReceipt = false,
    bool isPrintAndExit = false,
    double? valetCharge,
  }) async {
    // Calculate duration from parking time
    final DateTime? parkingDateTime = tryParseDateTime(
      date: parkingDate,
      time: parkingTime,
    );

    Duration duration = Duration.zero;
    String formattedDuration = preCalculatedDuration ?? '';

    if (formattedDuration.isEmpty && parkingDateTime != null) {
      duration = DateTime.now().difference(parkingDateTime);
      if (!duration.isNegative) {
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = duration.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        // Receipt format: no seconds (e.g. "02 Hours 15 Minutes")
        formattedDuration = '$hours Hours $minutes Minutes';
      }
    }
    if (!Platform.isAndroid) {
      debugPrint(_printerTroubleshootMsg);
      return;
    }

    final String resolvedVendorName =
        vendorName.trim().isEmpty ? 'Vendor' : vendorName.trim();

    try {
      // Use the amount that's already calculated and passed to printTicket
      // This amount comes from getPrintAmount which is called in the print button
      String currentAmount = amount;
      if (GlobalVendorDashCache.vendor == null && vendorId.isNotEmpty) {
        try {
          final vendorResponse = await http
              .get(
                Uri.parse(
                  '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=$vendorId',
                ),
              )
              .timeout(const Duration(seconds: 3));
          if (vendorResponse.statusCode == 200) {
            final Map<String, dynamic> vData = json.decode(vendorResponse.body);
            if (vData['data'] != null) {
              GlobalVendorDashCache.vendor = Vendor.fromJson(vData['data']);
            }
          }
        } catch (_) {}
      }
      if (GlobalVendorDashCache.vendor != null && _isInstantBookingStrings(sts, bookType)) {
        final v = GlobalVendorDashCache.vendor!;
        final vt = vehicleType.toLowerCase();
        double cap = 0.0;
        if (vt.contains('bike')) {
          cap = v.maxBikeAmount;
        } else if (vt.contains('car')) {
          cap = v.maxCarAmount;
        } else {
          cap = v.maxOthersAmount;
        }
        final parsed = double.tryParse(currentAmount.trim()) ?? 0.0;
        if (cap > 0 && parsed > cap) {
          currentAmount = (cap == cap.roundToDouble())
              ? cap.round().toString()
              : cap.toStringAsFixed(2);
          print('Clamped printTicket amount to ceiling cap: $currentAmount');
        }
      }
      print('Using amount from printTicket parameter: $currentAmount');

      final String resolvedInvoiceId = await resolveInvoiceIdForPrint(
        invoiceId: invoiceId,
        bookingId: bookingId,
      );
      print('Receipt invoice id: "$resolvedInvoiceId"');

      String? operationalTimings;
      try {
        final response = await http
            .get(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId',
              ),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['businessHours'] != null) {
            final List businessHours = data['businessHours'];
            final today = DateFormat('EEEE').format(DateTime.now());
            final todayTiming = businessHours.firstWhere(
              (b) =>
                  (b['day'] ?? '').toString().toLowerCase() ==
                  today.toLowerCase(),
              orElse: () => null,
            );
            if (todayTiming != null &&
                todayTiming['openTime'] != null &&
                todayTiming['closeTime'] != null) {
              String formatTime(String t) {
                try {
                  final p = t.split(':');
                  int h = int.parse(p[0]);
                  String ampm = h >= 12 ? 'PM' : 'AM';
                  int h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
                  return '${h12.toString().padLeft(2, '0')}:${p[1]} $ampm';
                } catch (_) {
                  return t;
                }
              }

              operationalTimings =
                  '${formatTime(todayTiming['openTime'])} to ${formatTime(todayTiming['closeTime'])}';
            }
          }
        }
      } catch (e) {
        print('Error fetching operational timings for print: $e');
      }

      final bool skipChargeLookup = fastPrint;
      final String printerType = await detectPrinterType(fast: fastPrint);

      if (printerType == 'pinelabs_builtin') {
        await PineLabsPrintHelper.printTicket(
          vendorName: resolvedVendorName,
          bookingId: bookingId,
          invoiceId: resolvedInvoiceId.isNotEmpty ? resolvedInvoiceId : null,
          vehicleType: vehicleType,
          vehicleNumber: vehicleNumber,
          parkingDate: parkingDate,
          parkingTime: parkingTime,
          amount: currentAmount,
          personName: personName,
          mobileNumber: mobileNumber,
          duration: formattedDuration,
          sts: sts,
          bookType: bookType,
          isEntryReceipt: formattedDuration.isEmpty,
        );
        return;
      } else if (printerType == 'sumi' || printerType == 'sunmi') {
        final bool isBound =
            _sunmiBoundAndInited ||
            await _tryBindSunmiPrinter(maxRetries: fastPrint ? 1 : 2);
        if (isBound) {
          await _printWithSunmi(
            vendorId: vendorId,
            vendorName: resolvedVendorName,
            bookingId: bookingId,
            invoiceId: resolvedInvoiceId.isNotEmpty ? resolvedInvoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: vehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: currentAmount,
            personName: personName,
            mobileNumber: mobileNumber,
            duration: formattedDuration,
            sts: sts,
            bookType: bookType,
            skipChargeLookup: skipChargeLookup,
            instantParkingReceipt: instantParkingReceipt,
            isPrintAndExit: isPrintAndExit,
            valetCharge: isPrintAndExit ? null : valetCharge,
            operationalTimings: operationalTimings,
            isEntryReceipt: formattedDuration.isEmpty,
          );
        } else {
          _clearPrinterCache();
          _showError(context);
          return;
        }
      } else if (printerType == 'bluetooth') {
        final bool connected = await connectBluetoothPrinter();
        if (connected) {
          await printWithESCPOS(
            vendorId: vendorId,
            vendorName: resolvedVendorName,
            bookingId: bookingId,
            invoiceId: resolvedInvoiceId.isNotEmpty ? resolvedInvoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: vehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: currentAmount,
            personName: personName,
            mobileNumber: mobileNumber,
            duration: formattedDuration,
            sts: sts,
            bookType: bookType,
            skipChargeLookup: skipChargeLookup,
            instantParkingReceipt: instantParkingReceipt,
            isPrintAndExit: isPrintAndExit,
            valetCharge: isPrintAndExit ? null : valetCharge,
            operationalTimings: operationalTimings,
            isEntryReceipt: formattedDuration.isEmpty,
          );
        } else {
          _clearPrinterCache();
          _showError(context);
          return;
        }
      } else {
        _showError(context);
        return;
      }

      print('Receipt printed successfully');
    } catch (e) {
      print('Exception in print: $e');
      _showError(context);
    }
  }

  static List<String> _buildSummaryReportLines({
    required String reportDate,
    required String reportTime,
    required String vendorName,
    required String fromDate,
    required String fromTime,
    required String toDate,
    required String toTime,
    required String entry,
    required String exit,
    required String empId,
    required int hourlyCount,
    required double hourlyAmount,
    required int pass12Count,
    required double pass12Amount,
    required int pass24Count,
    required double pass24Amount,
    required int pass48Count,
    required double pass48Amount,
    required int pass72Count,
    required double pass72Amount,
    required int weeklyCount,
    required double weeklyAmount,
    required int pass15Count,
    required double pass15Amount,
    required int monthlyCount,
    required double monthlyAmount,
    required double cashTotal,
    required double onlineTotal,
  }) {
    String money(double v) =>
        v.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');

    String totalsOneLine(double cash, double online) {
      final cs = money(cash);
      final os = money(online);
      final full = 'Cash: $cs | Online: $os';
      if (full.length <= 32) return full;
      final tight = 'Cash:$cs | On:$os';
      if (tight.length <= 32) return tight;
      return 'C:$cs|O:$os';
    }

    String entryExitOneLine(String e, String x) {
      final full = 'Entry: $e | Exit: $x';
      if (full.length <= 32) return full;
      return 'In:$e|Out:$x';
    }

    // Thermal ~32 cols: keep each row <= 32 chars so count & amount stay on same line.
    String row(String type, int vehicles, double amount) {
      final t = (type.length > 12 ? type.substring(0, 12) : type).padRight(12);
      final v = vehicles.toString().padLeft(4);
      final a = money(amount).padLeft(10);
      return '$t|$v|$a';
    }

    const sep = '________________________________';
    return [
      'Summary Report',
      '$reportDate, $reportTime',
      sep,
      vendorName,
      'Duration:',
      'From: $fromDate, $fromTime',
      'To  : $toDate, $toTime',
      sep,
      'Vehicle Parking Details',
      if (empId.isNotEmpty) 'Emp ID: $empId',
      entryExitOneLine(entry, exit),
      '\u00A0', // Forced blank line
      '${'Type'.padRight(12)}|${'Veh'.padLeft(4)}|${'Amount'.padLeft(10)}',
      row('Hourly:', hourlyCount, hourlyAmount),
      row('12 Hrs Pass:', pass12Count, pass12Amount),
      row('24 Hrs Pass:', pass24Count, pass24Amount),
      row('48 Hrs Pass:', pass48Count, pass48Amount),
      row('72 Hrs Pass:', pass72Count, pass72Amount),
      row('Weekly Pass:', weeklyCount, weeklyAmount),
      row('15 Days Pass:', pass15Count, pass15Amount),
      row('Monthly Pass:', monthlyCount, monthlyAmount),
      sep,
      totalsOneLine(cashTotal, onlineTotal),
      'Total Amount: ${money(cashTotal + onlineTotal)}',
      sep,
      'Powered by ParkMyWheels',
      '\u00A0',
    ];
  }

  static Future<void> printSummaryReport({
    required BuildContext context,
    required String vendorId,
    required String vendorName,
    required String reportDate,
    required String reportTime,
    required String fromDate,
    required String fromTime,
    required String toDate,
    required String toTime,
    required String entry,
    required String exit,
    required String empId,
    required int hourlyCount,
    required double hourlyAmount,
    required int pass12Count,
    required double pass12Amount,
    required int pass24Count,
    required double pass24Amount,
    required int pass48Count,
    required double pass48Amount,
    required int pass72Count,
    required double pass72Amount,
    required int weeklyCount,
    required double weeklyAmount,
    required int pass15Count,
    required double pass15Amount,
    required int monthlyCount,
    required double monthlyAmount,
    required double cashTotal,
    required double onlineTotal,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint(_printerTroubleshootMsg);
      return;
    }

    final lines = _buildSummaryReportLines(
      reportDate: reportDate,
      reportTime: reportTime,
      vendorName: vendorName,
      fromDate: fromDate,
      fromTime: fromTime,
      toDate: toDate,
      toTime: toTime,
      entry: entry,
      exit: exit,
      empId: empId,
      hourlyCount: hourlyCount,
      hourlyAmount: hourlyAmount,
      pass12Count: pass12Count,
      pass12Amount: pass12Amount,
      pass24Count: pass24Count,
      pass24Amount: pass24Amount,
      pass48Count: pass48Count,
      pass48Amount: pass48Amount,
      pass72Count: pass72Count,
      pass72Amount: pass72Amount,
      weeklyCount: weeklyCount,
      weeklyAmount: weeklyAmount,
      pass15Count: pass15Count,
      pass15Amount: pass15Amount,
      monthlyCount: monthlyCount,
      monthlyAmount: monthlyAmount,
      cashTotal: cashTotal,
      onlineTotal: onlineTotal,
    );

    try {
      final printerType = await detectPrinterType();

      if (printerType == 'pinelabs_builtin') {
        await PineLabsPrintHelper.printLines(lines);
        return;
      }

      if (printerType == 'sumi' || printerType == 'sunmi') {
        final isBound = await _tryBindSunmiPrinter();
        if (!isBound) {
          _showError(context);
          return;
        }
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.setAlignment(0);
        for (final line in lines) {
          await SunmiPrinter.printText(line);
          await SunmiPrinter.lineWrap(1);
        }
        // Bottom spacing - using non-breaking spaces and a dot to completely defeat the printer's whitespace trimmer
        await SunmiPrinter.printText('\u00A0\n\u00A0\n\u00A0\n\u00A0\n.');
        return;
      }

      if (printerType == 'bluetooth') {
        final connected = await connectBluetoothPrinter();
        if (!connected) {
          _showError(context);
          return;
        }

        List<int> bytes = [];
        bytes += [0x1B, 0x40]; // ESC @ init
        bytes += [0x0A]; // top spacing
        for (final line in lines) {
          bytes += line.codeUnits;
          bytes += [0x0A];
        }
        bytes += [0x0A, 0x0A];

        final isConnected = await PrintBluetoothThermal.connectionStatus;
        if (!isConnected) {
          _showError(context);
          return;
        }
        final ok = await PrintBluetoothThermal.writeBytes(bytes);
        if (!ok) {
          _showError(context);
        }
        return;
      }

      _showError(context);
    } catch (e) {
      print('Exception in printSummaryReport: $e');
      _showError(context);
    }
  }

  static Future<bool> _tryBindSunmiPrinter({int maxRetries = 2}) async {
    if (_sunmiBoundAndInited) return true;

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (await _bindAndInitSunmi()) {
        return true;
      }
      if (attempt < maxRetries - 1) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    return false;
  }

  static void _showError(BuildContext context) {
    debugPrint(_printerTroubleshootMsg);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_printerTroubleshootMsg),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
          textColor: Colors.white,
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  static String getPrintAmount(Bookingdata v) {
    // Debug logging to see what values we're getting
    print('=== DEBUG getPrintAmount ===');
    print('Booking ID: ${v.id}');
    print('totalamout: "${v.totalamout}"');
    print('amount: "${v.amount}"');
    print('Amount: "${v.Amount}"');
    print('currentCalculatedAmount: "${v.currentCalculatedAmount}"');

    // Return a placeholder - the actual amount will be fetched from vendor/fet API
    // This method will be updated to call the API
    print('getPrintAmount called - will fetch from vendor/fet API');
    return '0'; // This will be updated with API call
  }

  // New method to fetch amount from vendor/fet API
  static Future<String> getPrintAmountFromAPI(String bookingId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/fet/$bookingId');
      final response = await http.get(url);

      print('=== DEBUG getPrintAmountFromAPI ===');
      print('URL: $url');
      print('Response status: ${response?.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Decoded JSON: $data');

        String? amount;
        if (data is Map<String, dynamic>) {
          // Try top-level first
          amount = _extractAmountFromMap(data);

          // Then try common wrappers
          if (amount == null && data['booking'] is Map<String, dynamic>) {
            amount = _extractAmountFromMap(
              data['booking'] as Map<String, dynamic>,
            );
          }
          if (amount == null && data['data'] is Map<String, dynamic>) {
            amount = _extractAmountFromMap(
              data['data'] as Map<String, dynamic>,
            );
          }
        }

        if (amount != null && amount.trim().isNotEmpty) {
          print('Found amount from vendor/fet: $amount');
          return amount.trim();
        }

        print('No amount field found in vendor/fet response');
      } else {
        print(
          'Failed to fetch amount from vendor/fet: ${response?.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching amount from vendor/fet: $e');
    }

    // Fallback: Try fast-exit-data if vendor/fet was unable to provide amount
    try {
      final fastExitUrl = Uri.parse('${ApiConfig.baseUrl}vendor/fast-exit-data/$bookingId');
      final fastResponse = await http.get(fastExitUrl).timeout(const Duration(seconds: 4));
      if (fastResponse.statusCode == 200) {
        final fData = json.decode(fastResponse.body);
        if (fData is Map<String, dynamic>) {
          final double cap = (fData['maxCap'] as num?)?.toDouble() ?? 0.0;
          final String? raw = fData['amount']?.toString() ?? fData['payableAmount']?.toString();
          if (raw != null && raw.isNotEmpty && raw != '0') {
            final double parsed = double.tryParse(raw) ?? 0.0;
            if (cap > 0 && parsed > cap) {
              return (cap == cap.roundToDouble()) ? cap.round().toString() : cap.toStringAsFixed(2);
            }
            return raw.trim();
          }
        }
      }
    } catch (_) {}

    print('Returning default amount: 0');
    return '0';
  }

  static String _vehicleTypeSymbol(String vehicleType) {
    final t = vehicleType.toUpperCase();
    if (t.contains('CAR')) return '[C]';
    if (t.contains('BIKE')) return '[B]';
    return '[O]';
  }
}

class cardashleft extends StatelessWidget {
  final Bookingdata vehicle; // Expecting Bookingdata type
  final int currentTabIndex; // Add this parameter
  final String vendorId; // Add vendorId parameter
  final String bookType; // Add bookType parameter
  final String? defaultVendorName;
  final VoidCallback? onExitSuccess;
  const cardashleft({
    super.key,
    required this.vehicle,
    required this.currentTabIndex,
    required this.vendorId,
    required this.bookType,
    this.defaultVendorName,
    this.onExitSuccess,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String formatWithSuffix(DateTime date) {
    int day = date.day;
    String suffix = "th";
    if (!(day >= 11 && day <= 13)) {
      switch (day % 10) {
        case 1:
          suffix = "st";
          break;
        case 2:
          suffix = "nd";
          break;
        case 3:
          suffix = "rd";
          break;
      }
    }
    String formattedMonthYear = DateFormat("MMMM yyyy").format(date);
    return "$day$suffix $formattedMonthYear";
  }

  @override
  Widget build(BuildContext context) {
    final formattedPayableDuration =
        vehicle.payableDuration != null
            ? _formatDuration(vehicle.payableDuration)
            : 'N/A';
    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(vehicle.parkingDate);
    String formattedDate = formatWithSuffix(parsedDate);

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom =
        combinebook != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
            : 'N/A';

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat(
        'dd-MM-yyyy hh:mm a',
      ).parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime =
        combinedDateTime != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
            : 'N/A';
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      vehicle.status == 'PARKED'
                          ? ColorUtils.primarycolor()
                          : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    // Moved inside BoxDecoration
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                    5.0,
                  ), // Added padding for better spacing
                  child: Text(
                    'Booked On : $formattedDate, ${vehicle.parkingTime}',
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    // border: Border.all(color: Colors.black, width: 0.5),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  vehicle.status == 'Cancelled'
                                      ? Colors.red
                                      : ColorUtils.primarycolor(), // Your primary color
                              width: 0.5, // Border width
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5.0),
                            topRight: Radius.circular(5.0),
                          ),
                          color:
                              vehicle.status == 'Cancelled'
                                  ? Colors.grey[200]
                                  : Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Vehicle Number
                            Text(
                              vehicle.vehicleNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Spacer to push the status and buttons to the right
                            const Spacer(),

                            // Conditional rendering of status text and buttons
                            if (vehicle.status == "Cancelled")
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.cancelledStatus}",
                                  style: GoogleFonts.poppins(
                                    color:
                                        vehicle.status == 'Cancelled'
                                            ? Colors.red
                                            : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // if (vehicle.cancelledStatus
                            //     ?.isEmpty ??
                            //     true) // Check if cancelledStatus is empty
                            //   Padding(
                            //     padding:
                            //     const EdgeInsets.only(
                            //         right: 12.0),
                            //     child: Text(
                            //       " ${vehicle.status}", // Display vehicle status if cancelledStatus is empty
                            //       style:
                            //       GoogleFonts.poppins(
                            //         color: vehicle.status ==
                            //             'Cancelled'
                            //             ? Colors.red
                            //             : ColorUtils
                            //             .primarycolor(),
                            //         fontWeight:
                            //         FontWeight.bold,
                            //       ),
                            //     ),
                            //   ),
                            //
                            if (vehicle.status == "PARKED")
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 3.0,
                                  bottom: 5.0,
                                ),
                                child: SizedBox(
                                  height: 25,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Print Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Fetch amount from vendor/fet API
                                            String currentAmount =
                                                await UniversalPrintHelper.getPrintAmountFromAPI(
                                                  vehicle.id,
                                                );
                                            if (currentAmount.isEmpty ||
                                                currentAmount == '0' ||
                                                currentAmount == '0.0' ||
                                                currentAmount == '0.00') {
                                              currentAmount =
                                                  (vehicle.currentCalculatedAmount != null &&
                                                          vehicle.currentCalculatedAmount!.isNotEmpty)
                                                      ? vehicle.currentCalculatedAmount!
                                                      : vehicle.amount.toString();
                                            }

                                            UniversalPrintHelper.printTicket(
                                              context: context,
                                              vendorName:
                                                  effectivePrintVendorName(
                                                    vehicle.vendorname,
                                                    defaultVendorName,
                                                  ),
                                              bookingId: vehicle.id,
                                              invoiceId: vehicle.invoiceid,
                                              vehicleType: vehicle.vehicletype,
                                              vehicleNumber:
                                                  vehicle.vehicleNumber,
                                              parkingDate: vehicle.parkingDate,
                                              parkingTime: vehicle.parkingTime,
                                              amount: currentAmount,
                                              personName: vehicle.username,
                                              valetCharge:
                                                  double.tryParse(
                                                    vehicle.valetCharge,
                                                  ) ??
                                                  0.0,
                                              mobileNumber:
                                                  vehicle.mobilenumber,
                                              vendorId: vendorId,
                                              bookType: bookType,
                                              sts: vehicle.sts,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                ColorUtils.primarycolor(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.print,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Print',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Print & Exit Button
                                      if (currentTabIndex == 0 &&
                                          vehicle.sts == 'Instant')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                () => DashQuickExitHelper.handlePrintAndExit(
                                                  context: context,
                                                  vehicle: vehicle,
                                                  vendorId: vendorId,
                                                  bookType: bookType,
                                                  defaultVendorName:
                                                      defaultVendorName,
                                                  paymentMode:
                                                      globalSelectedPaymentModes[vehicle
                                                          .id] ??
                                                      'Online',
                                                  onExitSuccess: onExitSuccess,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  ColorUtils.primarycolor(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              minimumSize: const Size(0, 0),
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.print,
                                                  color: Colors.black,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Print & Exit',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        ColorUtils.primarycolor(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Exit Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) {
                                                return DraggableScrollableSheet(
                                                  expand: false,
                                                  builder: (
                                                    context,
                                                    scrollController,
                                                  ) {
                                                    return Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Exitpage(
                                                        maxCap: GlobalVendorDashCache.vendor?.maxCarAmount,
                                                        paymentMode:
                                                            globalSelectedPaymentModes[vehicle
                                                                .id] ??
                                                            'Online',
                                                        currentTabIndex:
                                                            currentTabIndex,
                                                        userid: vehicle.userid,
                                                        otp: vehicle.otp,
                                                        vehicletype:
                                                            vehicle.vehicletype,
                                                        bookingid: vehicle.id,
                                                        amount: vehicle.amount,
                                                        isValet:
                                                            vehicle.isValet,
                                                        valetCharge:
                                                            vehicle.valetCharge,
                                                        parkingdate:
                                                            vehicle.parkingDate,
                                                        vehiclenumber:
                                                            vehicle
                                                                .vehicleNumber,
                                                        username:
                                                            vehicle.username,
                                                        phoneno:
                                                            vehicle
                                                                .mobilenumber,
                                                        parkingtime:
                                                            vehicle.parkingTime,
                                                        bookingtypetemporary:
                                                            vehicle.status,
                                                        sts: vehicle.sts,
                                                        cartype:
                                                            vehicle.Cartype,
                                                        vendorid: vendorId,
                                                        bookType:
                                                            vehicle.bookType,
                                                        onExitSuccess:
                                                            onExitSuccess,
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              BookingTicketDialog.showForBooking(
                                context,
                                vehicle,
                                vendorId: vendorId,
                                defaultVendorName: defaultVendorName,
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 15.0,
                                top: 6.0,
                                bottom: 6.0,
                              ), // Optional: Adds space inside the container
                              decoration: BoxDecoration(
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20.0),
                                  bottomRight: Radius.circular(20.0),
                                ),
                              ),
                              child: Icon(
                                vehicle.vehicletype == "Car"
                                    ? Icons.directions_car
                                    : vehicle.vehicletype == "Bike"
                                    ? Icons.motorcycle
                                    : Icons
                                        .directions_transit, // Replace with any icon for "Others"
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking From: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      'Payable Time:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(" $formattedPayableDuration"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Payment Mode:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    StatefulBuilder(
                                      builder: (
                                        BuildContext context,
                                        StateSetter setStateRadio,
                                      ) {
                                        globalSelectedPaymentModes[vehicle
                                                .id] ??=
                                            'Online';
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Radio<String>(
                                              value: 'Online',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Online',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Radio<String>(
                                              value: 'Cash',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Cash',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (vehicle.status == 'PARKED' &&
                                    vehicle.currentCalculatedAmount != null)
                                  Row(
                                    children: [
                                      Text(
                                        'Payable Amount: ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "â‚¹${vehicle.currentCalculatedAmount}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.primarycolor(),
                                        ),
                                      ),
                                    ],
                                  ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(height: 10),
                                    if (vehicle.status == "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment.topCenter,
                                      ),
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          VehicleImageThumbnail(
                            images: vehicle.vehicleImages,
                            vehicleNumber: vehicle.vehicleNumber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class bikedashleft extends StatelessWidget {
  final Bookingdata vehicle; // Expecting Bookingdata type
  final int currentTabIndex; // Add this parameter
  final String vendorId; // Add vendorId parameter
  final String bookType; // Add bookType parameter
  final String? defaultVendorName;
  final VoidCallback? onExitSuccess;
  const bikedashleft({
    super.key,
    required this.vehicle,
    required this.currentTabIndex,
    required this.vendorId,
    required this.bookType,
    this.defaultVendorName,
    this.onExitSuccess,
  });
  String formatWithSuffix(DateTime date) {
    int day = date.day;
    String suffix = "th";
    if (!(day >= 11 && day <= 13)) {
      switch (day % 10) {
        case 1:
          suffix = "st";
          break;
        case 2:
          suffix = "nd";
          break;
        case 3:
          suffix = "rd";
          break;
      }
    }
    String formattedMonthYear = DateFormat("MMMM yyyy").format(date);
    return "$day$suffix $formattedMonthYear";
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final formattedPayableDuration =
        vehicle.payableDuration != null
            ? _formatDuration(vehicle.payableDuration)
            : 'N/A';
    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(vehicle.parkingDate);
    String formattedDate = formatWithSuffix(parsedDate);

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom =
        combinebook != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
            : 'N/A';

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat(
        'dd-MM-yyyy hh:mm a',
      ).parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime =
        combinedDateTime != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
            : 'N/A';
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      vehicle.status == 'PARKED'
                          ? ColorUtils.primarycolor()
                          : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    // Moved inside BoxDecoration
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                    5.0,
                  ), // Added padding for better spacing
                  child: Text(
                    'Booked On : $formattedDate, ${vehicle.parkingTime}',
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    // border: Border.all(color: Colors.black, width: 0.5),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  vehicle.status == 'Cancelled'
                                      ? Colors.red
                                      : ColorUtils.primarycolor(), // Your primary color
                              width: 0.5, // Border width
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5.0),
                            topRight: Radius.circular(5.0),
                          ),
                          color:
                              vehicle.status == 'Cancelled'
                                  ? Colors.grey[200]
                                  : Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Vehicle Number
                            Text(
                              vehicle.vehicleNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Spacer to push the status and buttons to the right
                            const Spacer(),

                            // Conditional rendering of status text and buttons
                            if (vehicle.status == "Cancelled")
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.cancelledStatus}",
                                  style: GoogleFonts.poppins(
                                    color:
                                        vehicle.status == 'Cancelled'
                                            ? Colors.red
                                            : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // if (vehicle.cancelledStatus
                            //     ?.isEmpty ??
                            //     true) // Check if cancelledStatus is empty
                            //   Padding(
                            //     padding:
                            //     const EdgeInsets.only(
                            //         right: 12.0),
                            //     child: Text(
                            //       " ${vehicle.status}", // Display vehicle status if cancelledStatus is empty
                            //       style:
                            //       GoogleFonts.poppins(
                            //         color: vehicle.status ==
                            //             'Cancelled'
                            //             ? Colors.red
                            //             : ColorUtils
                            //             .primarycolor(),
                            //         fontWeight:
                            //         FontWeight.bold,
                            //       ),
                            //     ),
                            //   ),
                            //
                            if (vehicle.status == "PARKED")
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 3.0,
                                  bottom: 5.0,
                                ),
                                child: SizedBox(
                                  height: 25,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Print Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Fetch amount from vendor/fet API
                                            String currentAmount =
                                                await UniversalPrintHelper.getPrintAmountFromAPI(
                                                  vehicle.id,
                                                );
                                            if (currentAmount.isEmpty ||
                                                currentAmount == '0' ||
                                                currentAmount == '0.0' ||
                                                currentAmount == '0.00') {
                                              currentAmount =
                                                  (vehicle.currentCalculatedAmount != null &&
                                                          vehicle.currentCalculatedAmount!.isNotEmpty)
                                                      ? vehicle.currentCalculatedAmount!
                                                      : vehicle.amount.toString();
                                            }

                                            UniversalPrintHelper.printTicket(
                                              context: context,
                                              vendorName:
                                                  effectivePrintVendorName(
                                                    vehicle.vendorname,
                                                    defaultVendorName,
                                                  ),
                                              bookingId: vehicle.id,
                                              invoiceId: vehicle.invoiceid,
                                              vehicleType: vehicle.vehicletype,
                                              vehicleNumber:
                                                  vehicle.vehicleNumber,
                                              parkingDate: vehicle.parkingDate,
                                              parkingTime: vehicle.parkingTime,
                                              amount: currentAmount,
                                              personName: vehicle.username,
                                              valetCharge:
                                                  double.tryParse(
                                                    vehicle.valetCharge,
                                                  ) ??
                                                  0.0,
                                              mobileNumber:
                                                  vehicle.mobilenumber,
                                              vendorId: vendorId,
                                              bookType: bookType,
                                              sts: vehicle.sts,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                ColorUtils.primarycolor(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.print,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Print',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Print & Exit Button
                                      if (currentTabIndex == 1 &&
                                          vehicle.sts == 'Instant')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                () => DashQuickExitHelper.handlePrintAndExit(
                                                  context: context,
                                                  vehicle: vehicle,
                                                  vendorId: vendorId,
                                                  bookType: bookType,
                                                  defaultVendorName:
                                                      defaultVendorName,
                                                  paymentMode:
                                                      globalSelectedPaymentModes[vehicle
                                                          .id] ??
                                                      'Online',
                                                  onExitSuccess: onExitSuccess,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  ColorUtils.primarycolor(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              minimumSize: const Size(0, 0),
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.print,
                                                  color: Colors.black,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Print & Exit',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        ColorUtils.primarycolor(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Exit Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) {
                                                return DraggableScrollableSheet(
                                                  expand: false,
                                                  builder: (
                                                    context,
                                                    scrollController,
                                                  ) {
                                                    return Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Exitpage(
                                                        maxCap: GlobalVendorDashCache.vendor?.maxBikeAmount,
                                                        paymentMode:
                                                            globalSelectedPaymentModes[vehicle
                                                                .id] ??
                                                            'Online',
                                                        currentTabIndex:
                                                            currentTabIndex,
                                                        userid: vehicle.userid,
                                                        otp: vehicle.otp,
                                                        vehicletype:
                                                            vehicle.vehicletype,
                                                        bookingid: vehicle.id,
                                                        amount: vehicle.amount,
                                                        isValet:
                                                            vehicle.isValet,
                                                        valetCharge:
                                                            vehicle.valetCharge,
                                                        parkingdate:
                                                            vehicle.parkingDate,
                                                        vehiclenumber:
                                                            vehicle
                                                                .vehicleNumber,
                                                        username:
                                                            vehicle.username,
                                                        phoneno:
                                                            vehicle
                                                                .mobilenumber,
                                                        parkingtime:
                                                            vehicle.parkingTime,
                                                        bookingtypetemporary:
                                                            vehicle.status,
                                                        sts: vehicle.sts,
                                                        cartype:
                                                            vehicle.Cartype,
                                                        vendorid: vendorId,
                                                        bookType:
                                                            vehicle.bookType,
                                                        onExitSuccess:
                                                            onExitSuccess,
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              BookingTicketDialog.showForBooking(
                                context,
                                vehicle,
                                vendorId: vendorId,
                                defaultVendorName: defaultVendorName,
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 15.0,
                                top: 6.0,
                                bottom: 6.0,
                              ), // Optional: Adds space inside the container
                              decoration: BoxDecoration(
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20.0),
                                  bottomRight: Radius.circular(20.0),
                                ),
                              ),
                              child: Icon(
                                vehicle.vehicletype == "Car"
                                    ? Icons.directions_car
                                    : vehicle.vehicletype == "Bike"
                                    ? Icons.motorcycle
                                    : Icons
                                        .directions_transit, // Replace with any icon for "Others"
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking From: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      'Payable Time:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(" $formattedPayableDuration"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Payment Mode:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    StatefulBuilder(
                                      builder: (
                                        BuildContext context,
                                        StateSetter setStateRadio,
                                      ) {
                                        globalSelectedPaymentModes[vehicle
                                                .id] ??=
                                            'Online';
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Radio<String>(
                                              value: 'Online',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Online',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Radio<String>(
                                              value: 'Cash',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Cash',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (vehicle.status == 'PARKED' &&
                                    vehicle.currentCalculatedAmount != null)
                                  Row(
                                    children: [
                                      Text(
                                        'Payable Amount: ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "â‚¹${vehicle.currentCalculatedAmount}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.primarycolor(),
                                        ),
                                      ),
                                    ],
                                  ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(height: 10),
                                    if (vehicle.status == "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment.topCenter,
                                      ),
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          VehicleImageThumbnail(
                            images: vehicle.vehicleImages,
                            vehicleNumber: vehicle.vehicleNumber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class othersdashleft extends StatelessWidget {
  final Bookingdata vehicle; // Expecting Bookingdata type
  final int currentTabIndex; // Add this parameter
  final String vendorId; // Add vendorId parameter
  final String bookType; // Add bookType parameter
  final String? defaultVendorName;
  final VoidCallback? onExitSuccess;
  const othersdashleft({
    super.key,
    required this.vehicle,
    required this.currentTabIndex,
    required this.vendorId,
    required this.bookType,
    this.defaultVendorName,
    this.onExitSuccess,
  });
  String formatWithSuffix(DateTime date) {
    int day = date.day;
    String suffix = "th";
    if (!(day >= 11 && day <= 13)) {
      switch (day % 10) {
        case 1:
          suffix = "st";
          break;
        case 2:
          suffix = "nd";
          break;
        case 3:
          suffix = "rd";
          break;
      }
    }
    String formattedMonthYear = DateFormat("MMMM yyyy").format(date);
    return "$day$suffix $formattedMonthYear";
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final formattedPayableDuration =
        vehicle.payableDuration != null
            ? _formatDuration(vehicle.payableDuration)
            : 'N/A';
    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom =
        combinebook != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
            : 'N/A';
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(vehicle.parkingDate);
    String formattedDate = formatWithSuffix(parsedDate);

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat(
        'dd-MM-yyyy hh:mm a',
      ).parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime =
        combinedDateTime != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
            : 'N/A';
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      vehicle.status == 'PARKED'
                          ? ColorUtils.primarycolor()
                          : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    // Moved inside BoxDecoration
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                    5.0,
                  ), // Added padding for better spacing
                  child: Text(
                    'Booked On : $formattedDate, ${vehicle.parkingTime}',
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    // border: Border.all(color: Colors.black, width: 0.5),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  vehicle.status == 'Cancelled'
                                      ? Colors.red
                                      : ColorUtils.primarycolor(), // Your primary color
                              width: 0.5, // Border width
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5.0),
                            topRight: Radius.circular(5.0),
                          ),
                          color:
                              vehicle.status == 'Cancelled'
                                  ? Colors.grey[200]
                                  : Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Vehicle Number
                            Text(
                              vehicle.vehicleNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Spacer to push the status and buttons to the right
                            const Spacer(),

                            // Conditional rendering of status text and buttons
                            if (vehicle.status == "Cancelled")
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.cancelledStatus}",
                                  style: GoogleFonts.poppins(
                                    color:
                                        vehicle.status == 'Cancelled'
                                            ? Colors.red
                                            : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // if (vehicle.cancelledStatus
                            //     ?.isEmpty ??
                            //     true) // Check if cancelledStatus is empty
                            //   Padding(
                            //     padding:
                            //     const EdgeInsets.only(
                            //         right: 12.0),
                            //     child: Text(
                            //       " ${vehicle.status}", // Display vehicle status if cancelledStatus is empty
                            //       style:
                            //       GoogleFonts.poppins(
                            //         color: vehicle.status ==
                            //             'Cancelled'
                            //             ? Colors.red
                            //             : ColorUtils
                            //             .primarycolor(),
                            //         fontWeight:
                            //         FontWeight.bold,
                            //       ),
                            //     ),
                            //   ),
                            //
                            if (vehicle.status == "PARKED")
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 3.0,
                                  bottom: 5.0,
                                ),
                                child: SizedBox(
                                  height: 25,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Print Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Fetch amount from vendor/fet API
                                            String currentAmount =
                                                await UniversalPrintHelper.getPrintAmountFromAPI(
                                                  vehicle.id,
                                                );
                                            if (currentAmount.isEmpty ||
                                                currentAmount == '0' ||
                                                currentAmount == '0.0' ||
                                                currentAmount == '0.00') {
                                              currentAmount =
                                                  (vehicle.currentCalculatedAmount != null &&
                                                          vehicle.currentCalculatedAmount!.isNotEmpty)
                                                      ? vehicle.currentCalculatedAmount!
                                                      : vehicle.amount.toString();
                                            }

                                            UniversalPrintHelper.printTicket(
                                              context: context,
                                              vendorName:
                                                  effectivePrintVendorName(
                                                    vehicle.vendorname,
                                                    defaultVendorName,
                                                  ),
                                              bookingId: vehicle.id,
                                              invoiceId: vehicle.invoiceid,
                                              vehicleType: vehicle.vehicletype,
                                              vehicleNumber:
                                                  vehicle.vehicleNumber,
                                              parkingDate: vehicle.parkingDate,
                                              parkingTime: vehicle.parkingTime,
                                              amount: currentAmount,
                                              personName: vehicle.username,
                                              valetCharge:
                                                  double.tryParse(
                                                    vehicle.valetCharge,
                                                  ) ??
                                                  0.0,
                                              mobileNumber:
                                                  vehicle.mobilenumber,
                                              vendorId: vendorId,
                                              bookType: bookType,
                                              sts: vehicle.sts,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                ColorUtils.primarycolor(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.print,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Print',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Print & Exit Button
                                      if (currentTabIndex == 2 &&
                                          vehicle.sts == 'Instant')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                () => DashQuickExitHelper.handlePrintAndExit(
                                                  context: context,
                                                  vehicle: vehicle,
                                                  vendorId: vendorId,
                                                  bookType: bookType,
                                                  defaultVendorName:
                                                      defaultVendorName,
                                                  paymentMode:
                                                      globalSelectedPaymentModes[vehicle
                                                          .id] ??
                                                      'Online',
                                                  onExitSuccess: onExitSuccess,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                                  ColorUtils.primarycolor(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              minimumSize: const Size(0, 0),
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.print,
                                                  color: Colors.black,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Print & Exit',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        ColorUtils.primarycolor(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Exit Button
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) {
                                                return DraggableScrollableSheet(
                                                  expand: false,
                                                  builder: (
                                                    context,
                                                    scrollController,
                                                  ) {
                                                    return Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Exitpage(
                                                        maxCap: GlobalVendorDashCache.vendor?.maxOthersAmount,
                                                        paymentMode:
                                                            globalSelectedPaymentModes[vehicle
                                                                .id] ??
                                                            'Online',
                                                        currentTabIndex:
                                                            currentTabIndex,
                                                        userid: vehicle.userid,
                                                        otp: vehicle.otp,
                                                        vehicletype:
                                                            vehicle.vehicletype,
                                                        bookingid: vehicle.id,
                                                        amount: vehicle.amount,
                                                        isValet:
                                                            vehicle.isValet,
                                                        valetCharge:
                                                            vehicle.valetCharge,
                                                        parkingdate:
                                                            vehicle.parkingDate,
                                                        vehiclenumber:
                                                            vehicle
                                                                .vehicleNumber,
                                                        username:
                                                            vehicle.username,
                                                        phoneno:
                                                            vehicle
                                                                .mobilenumber,
                                                        parkingtime:
                                                            vehicle.parkingTime,
                                                        bookingtypetemporary:
                                                            vehicle.status,
                                                        sts: vehicle.sts,
                                                        cartype:
                                                            vehicle.Cartype,
                                                        vendorid: vendorId,
                                                        bookType:
                                                            vehicle.bookType,
                                                        onExitSuccess:
                                                            onExitSuccess,
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              BookingTicketDialog.showForBooking(
                                context,
                                vehicle,
                                vendorId: vendorId,
                                defaultVendorName: defaultVendorName,
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 15.0,
                                top: 6.0,
                                bottom: 6.0,
                              ), // Optional: Adds space inside the container
                              decoration: BoxDecoration(
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20.0),
                                  bottomRight: Radius.circular(20.0),
                                ),
                              ),
                              child: Icon(
                                vehicle.vehicletype == "Car"
                                    ? Icons.directions_car
                                    : vehicle.vehicletype == "Bike"
                                    ? Icons.motorcycle
                                    : Icons
                                        .directions_transit, // Replace with any icon for "Others"
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking From: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      'Payable Time:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(" $formattedPayableDuration"),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Payment Mode:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    StatefulBuilder(
                                      builder: (
                                        BuildContext context,
                                        StateSetter setStateRadio,
                                      ) {
                                        globalSelectedPaymentModes[vehicle
                                                .id] ??=
                                            'Online';
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Radio<String>(
                                              value: 'Online',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Online',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Online'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                            const SizedBox(width: 15),
                                            Radio<String>(
                                              value: 'Cash',
                                              groupValue:
                                                  globalSelectedPaymentModes[vehicle
                                                      .id],
                                              onChanged: (value) {
                                                setStateRadio(() {
                                                  globalSelectedPaymentModes[vehicle
                                                          .id] =
                                                      value!;
                                                });
                                              },
                                              activeColor:
                                                  ColorUtils.primarycolor(),
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal:
                                                        VisualDensity
                                                            .minimumDensity,
                                                    vertical:
                                                        VisualDensity
                                                            .minimumDensity,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            Text(
                                              'Cash',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                color:
                                                    globalSelectedPaymentModes[vehicle
                                                                .id] ==
                                                            'Cash'
                                                        ? ColorUtils.primarycolor()
                                                        : null,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (vehicle.status == 'PARKED' &&
                                    vehicle.currentCalculatedAmount != null &&
                                    vehicle.currentCalculatedAmount!.isNotEmpty)
                                  Row(
                                    children: [
                                      Text(
                                        'Payable Amount:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.primarycolor(),
                                        ),
                                      ),
                                      Text(
                                        " â‚¹${vehicle.currentCalculatedAmount}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: ColorUtils.primarycolor(),
                                        ),
                                      ),
                                    ],
                                  ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(height: 10),
                                    if (vehicle.status == "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment.topCenter,
                                      ),
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          VehicleImageThumbnail(
                            images: vehicle.vehicleImages,
                            vehicleNumber: vehicle.vehicleNumber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class vendordashright extends StatelessWidget {
  final Bookingdata vehicle; // Expecting Bookingdata type
  final String vendorId; // Add vendorId parameter
  final String bookType; // Add bookType parameter
  final String? defaultVendorName;
  const vendordashright({
    super.key,
    required this.vehicle,
    required this.vendorId,
    required this.bookType,
    this.defaultVendorName,
  });

  @override
  Widget build(BuildContext context) {
    final String parkingDate = vehicle.parkingDate; // e.g., '19-02-2025'
    final String parkingTime = vehicle.parkingTime; // e.g., '10:20 PM'
    final String bookedDate = vehicle.bookingDate; // e.g., '19-02-2025'
    final String bookedTime = vehicle.bookingTime; // e.g., '10:20 PM'
    String formatWithSuffix(DateTime date) {
      int day = date.day;
      String suffix = "th";
      if (!(day >= 11 && day <= 13)) {
        switch (day % 10) {
          case 1:
            suffix = "st";
            break;
          case 2:
            suffix = "nd";
            break;
          case 3:
            suffix = "rd";
            break;
        }
      }
      String formattedMonthYear = DateFormat("MMMM yyyy").format(date);
      return "$day$suffix $formattedMonthYear";
    }

    final String combinedDateTimeString = '$parkingDate $parkingTime';
    final String bookingcombine = '$bookedDate $bookedTime';
    DateTime? combinebook;
    try {
      combinebook = DateFormat('dd-MM-yyyy hh:mm a').parse(bookingcombine);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinebook = null;
    }
    String bookcom =
        combinebook != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinebook)
            : 'N/A';
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(vehicle.parkingDate);
    String formattedDate = formatWithSuffix(parsedDate);

    DateTime? combinedDateTime;
    try {
      combinedDateTime = DateFormat(
        'dd-MM-yyyy hh:mm a',
      ).parse(combinedDateTimeString);
    } catch (e) {
      print('Error parsing combined date and time: $e');
      combinedDateTime = null;
    }
    String formattedDateTime =
        combinedDateTime != null
            ? DateFormat('d MMM, yyyy, hh:mm a').format(combinedDateTime)
            : 'N/A';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => vendorParkingDetails(
                  parkeddate: vehicle.parkeddate,
                  parkedtime: vehicle.parkedtime,
                  subscriptionenddate: vehicle.subscriptionenddate,
                  exitdate: vehicle.exitvehicledate,
                  exittime: vehicle.exitvehicletime,
                  invoiceid: vehicle.invoiceid,
                  amount: vehicle.amount,
                  totalamount: vehicle.totalamout,
                  invoice: vehicle.invoice,
                  username: vehicle.username,
                  mobilenumber: vehicle.mobilenumber,
                  sts: vehicle.sts,
                  bookingtype: vehicle.bookingtype,
                  otp: vehicle.otp,
                  vehiclenumber: vehicle.vehicleNumber,
                  vendorname: vehicle.vendorname,
                  vendorid: vendorId,
                  parkingdate: vehicle.parkingDate,
                  parkingtime: vehicle.parkingTime,
                  bookedid: vehicle.id,
                  bookeddate: formattedDateTime,
                  schedule: bookcom,
                  status: vehicle.status,
                  vehicletype: vehicle.vehicletype,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 30,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      vehicle.status == 'PARKED'
                          ? ColorUtils.primarycolor()
                          : ColorUtils.primarycolor(),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    // Moved inside BoxDecoration
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter, // Center the text
                child: Padding(
                  padding: const EdgeInsets.all(
                    5.0,
                  ), // Added padding for better spacing
                  child: Text(
                    'Booked On : $formattedDate, ${vehicle.parkingTime}',
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    // border: Border.all(color: Colors.black, width: 0.5),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  vehicle.status == 'Cancelled'
                                      ? Colors.red
                                      : ColorUtils.primarycolor(), // Your primary color
                              width: 0.5, // Border width
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5.0),
                            topRight: Radius.circular(5.0),
                          ),
                          color:
                              vehicle.status == 'Cancelled'
                                  ? Colors.grey[200]
                                  : Colors.grey[200],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Vehicle Number
                            Text(
                              vehicle.vehicleNumber,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Spacer to push the status and buttons to the right
                            const Spacer(),

                            // Conditional rendering of status text and buttons
                            if (vehicle.status == "Cancelled")
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.cancelledStatus}",
                                  style: GoogleFonts.poppins(
                                    color:
                                        vehicle.status == 'Cancelled'
                                            ? Colors.red
                                            : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (vehicle.cancelledStatus?.isEmpty ??
                                true) // Check if cancelledStatus is empty
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  " ${vehicle.status}", // Display vehicle status if cancelledStatus is empty
                                  style: GoogleFonts.poppins(
                                    color:
                                        vehicle.status == 'Cancelled'
                                            ? Colors.red
                                            : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            if (vehicle.status == "PARKED" ||
                                vehicle.status.toUpperCase() == 'COMPLETED')
                              SizedBox(
                                height: 30,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Print Button (show for PARKED + COMPLETED)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final bool isCompleted =
                                              vehicle.status.toUpperCase() ==
                                              'COMPLETED';

                                          // For completed bookings, use the stored amount directly
                                          String currentAmount;
                                          if (isCompleted) {
                                            currentAmount =
                                                vehicle.totalamout.isNotEmpty
                                                    ? vehicle.totalamout
                                                    : vehicle.amount;
                                            if (currentAmount.isEmpty) {
                                              currentAmount =
                                                  await UniversalPrintHelper.getPrintAmountFromAPI(
                                                    vehicle.id,
                                                  );
                                            }
                                          } else {
                                            currentAmount =
                                                await UniversalPrintHelper.getPrintAmountFromAPI(
                                                  vehicle.id,
                                                );
                                          }

                                          // For completed, show actual parked-in date/time
                                          final String printDate =
                                              isCompleted
                                                  ? (vehicle
                                                          .parkeddate
                                                          .isNotEmpty
                                                      ? vehicle.parkeddate
                                                      : vehicle.parkingDate)
                                                  : vehicle.parkingDate;
                                          final String printTime =
                                              isCompleted
                                                  ? (vehicle
                                                          .parkedtime
                                                          .isNotEmpty
                                                      ? vehicle.parkedtime
                                                      : vehicle.parkingTime)
                                                  : vehicle.parkingTime;

                                          // For completed, calculate duration from parked time to exit time
                                          String? preCalculatedDuration;
                                          if (isCompleted &&
                                              vehicle.parkeddate.isNotEmpty &&
                                              vehicle.parkedtime.isNotEmpty &&
                                              vehicle
                                                  .exitvehicledate
                                                  .isNotEmpty &&
                                              vehicle
                                                  .exitvehicletime
                                                  .isNotEmpty) {
                                            try {
                                              final parkedDT =
                                                  UniversalPrintHelper.tryParseDateTime(
                                                    date: vehicle.parkeddate,
                                                    time: vehicle.parkedtime,
                                                  );
                                              final exitDT =
                                                  UniversalPrintHelper.tryParseDateTime(
                                                    date:
                                                        vehicle.exitvehicledate,
                                                    time:
                                                        vehicle.exitvehicletime,
                                                  );
                                              if (parkedDT != null &&
                                                  exitDT != null) {
                                                final dur = exitDT.difference(
                                                  parkedDT,
                                                );
                                                if (!dur.isNegative) {
                                                  final h = dur.inHours
                                                      .toString()
                                                      .padLeft(2, '0');
                                                  final m = (dur.inMinutes % 60)
                                                      .toString()
                                                      .padLeft(2, '0');
                                                  preCalculatedDuration =
                                                      '$h Hours $m Minutes';
                                                }
                                              }
                                            } catch (_) {}
                                          }

                                          await UniversalPrintHelper.printTicket(
                                            context: context,
                                            vendorName:
                                                effectivePrintVendorName(
                                                  vehicle.vendorname,
                                                  defaultVendorName,
                                                ),
                                            bookingId: vehicle.id,
                                            invoiceId: vehicle.invoiceid,
                                            vehicleType: vehicle.vehicletype,
                                            vehicleNumber:
                                                vehicle.vehicleNumber,
                                            parkingDate: printDate,
                                            parkingTime: printTime,
                                            amount: currentAmount,
                                            personName: vehicle.username,
                                            valetCharge:
                                                double.tryParse(
                                                  vehicle.valetCharge,
                                                ) ??
                                                0.0,
                                            mobileNumber: vehicle.mobilenumber,
                                            vendorId: vendorId,
                                            bookType: bookType,
                                            sts: vehicle.sts,
                                            preCalculatedDuration:
                                                preCalculatedDuration,
                                            isPrintAndExit: isCompleted,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              ColorUtils.primarycolor(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          minimumSize: const Size(0, 0),
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
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.print,
                                              color: ColorUtils.primarycolor(),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Print',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    ColorUtils.primarycolor(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Exit Button (only while still parked)
                                    if (vehicle.status == "PARKED")
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {},
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            minimumSize: const Size(0, 0),
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
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner,
                                                color:
                                                    ColorUtils.primarycolor(),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Exit',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      ColorUtils.primarycolor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              BookingTicketDialog.showForBooking(
                                context,
                                vehicle,
                                vendorId: vendorId,
                                defaultVendorName: defaultVendorName,
                              );
                            },
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                            child: Container(
                              padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 15.0,
                                top: 6.0,
                                bottom: 6.0,
                              ), // Optional: Adds space inside the container
                              decoration: BoxDecoration(
                                color:
                                    vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20.0),
                                  bottomRight: Radius.circular(20.0),
                                ),
                              ),
                              child: Icon(
                                vehicle.vehicletype == "Car"
                                    ? Icons
                                        .directions_car // Car icon
                                    : vehicle.vehicletype == "Bike"
                                    ? Icons
                                        .directions_bike // Bike icon
                                    : Icons
                                        .directions_transit, // Default for Others
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Parking From: ',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14, // Reduced font size
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' ${vehicle.parkingDate}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            vehicle.parkingTime,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ), // Consistent smaller size
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(' ${vehicle.sts}'),
                                  ],
                                ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(height: 10),
                                    if (vehicle.status == "PARKED")
                                      Container(
                                        // height: 50,
                                        alignment: Alignment.topCenter,
                                      ),
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          VehicleImageThumbnail(
                            images: vehicle.vehicleImages,
                            vehicleNumber: vehicle.vehicleNumber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectIndicator extends Decoration {
  final BoxPainter _painter;

  RoundedRectIndicator({required Color color, required double radius})
    : _painter = _RoundedRectPainter(color, radius);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _painter;
}

class _RoundedRectPainter extends BoxPainter {
  final Paint _paint;
  final double radius;

  _RoundedRectPainter(Color color, this.radius)
    : _paint =
          Paint()
            ..color = color
            ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Rect indicator = Rect.fromLTRB(
      rect.left - 43.5, // Adjust the left padding if necessary
      rect.top,
      rect.right + 37, // Adjust the right padding if necessary
      rect.bottom,
    );
    final RRect rRect = RRect.fromRectAndCorners(
      indicator,
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: const Radius.circular(0), // No rounding for bottom-left
      bottomRight: const Radius.circular(0), // No rounding for bottom-right
    );
    canvas.drawRRect(rRect, _paint);
  }
}

class CustomTab extends StatelessWidget {
  final String text;
  final bool isSelected;

  const CustomTab({super.key, required this.text, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.black, // Change text color based on selection
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class Bookingdata {
  final String amount;
  final String totalamout;
  final String id;
  final String mobilenumber;
  final String bookingtype;
  final String username;
  final String vehicleNumber;
  final String bookingDate;
  final String bookingTime;
  final String status;
  final String vehicletype;
  final String Cartype;
  final String parkingTime;
  final String parkingDate;
  final String Approvedate;
  final String Approvedtime;
  final String Amount;
  final String Hour;
  final String Vendorid;
  final String subscriptiontype;
  final String sts;
  final String parkeddate;
  final String parkedtime;
  final String invoiceid;
  final String paymentmode;
  final String? cancelledStatus;
  Duration payableDuration;
  final String exitvehicledate;
  final String exitvehicletime;
  final String bookType;
  final String otp;
  final String invoice;
  final String userid;
  final String vendorname;
  final String subscriptionenddate;
  final bool isValet;
  final String valetCharge;
  String? currentCalculatedAmount;
  String uiPaymentMode = 'Online';
  final List<String> vehicleImages;
  Bookingdata({
    required this.totalamout,
    required this.amount,
    required this.invoiceid,
    this.paymentmode = '',
    required this.subscriptionenddate,
    required this.bookingtype,
    required this.username,
    required this.mobilenumber,
    required this.id,
    required this.vehicleNumber,
    required this.bookingDate,
    required this.bookingTime,
    required this.status,
    required this.vehicletype,
    required this.Cartype,
    required this.parkingTime,
    required this.parkingDate,
    required this.Amount,
    required this.Hour,
    required this.parkeddate,
    required this.parkedtime,
    required this.Vendorid,
    required this.subscriptiontype,
    required this.sts,
    required this.otp,
    this.cancelledStatus,
    required this.exitvehicledate,
    required this.exitvehicletime,
    required this.invoice,
    required this.Approvedate,
    required this.Approvedtime,
    required this.payableDuration,
    required this.bookType,
    required this.userid,
    required this.vendorname,
    this.isValet = false,
    this.valetCharge = "0",
    this.currentCalculatedAmount,
    this.vehicleImages = const [],
  });

  // Factory constructor to parse JSON
  factory Bookingdata.fromJson(Map<String, dynamic> json) {
    final rawAmount =
        json['amount']?.toString() ??
        json['payableamout']?.toString() ??
        json['recievableamount']?.toString() ??
        '';
    final rawTotal =
        json['totalamout']?.toString() ??
        json['totalAmount']?.toString() ??
        json['payableamout']?.toString() ??
        '';
    final parsedVehicleImages =
        (json['vehicleImages'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((url) => url.isNotEmpty)
            .toList() ??
        (json['vehicleImage'] != null &&
                json['vehicleImage'].toString().trim().isNotEmpty
            ? [json['vehicleImage'].toString().trim()]
            : const <String>[]);
    return Bookingdata(
      invoiceid: (json['invoiceid'] ?? json['invoiceId'] ?? '').toString(),
      paymentmode:
          (json['paymentMode'] ?? json['paymentmode'])?.toString() ?? '',
      amount: rawAmount,
      totalamout: rawTotal,
      invoice: json['invoice'] ?? "",
      bookingtype: json['bookType'] ?? "",
      vendorname:
          ((json['vendorName'] ?? json['vendorname']) ?? '').toString().trim(),
      parkeddate: json['parkedDate'] ?? "",
      parkedtime: json['parkedTime'] ?? "",
      Approvedate: json['approvedDate'] ?? "",
      Approvedtime: json['approvedTime'] ?? "",
      username: json['personName'] ?? "",
      mobilenumber: json['mobileNumber'] ?? "",
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      otp: json['otp'] ?? "",
      Vendorid: (json['vendorId'] ?? json['vendorid'] ?? '').toString(),
      status: json['status'] ?? '',
      vehicletype: json['vehicleType'] ?? '',
      Cartype: json['carType'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      bookingDate: json['bookingDate'] ?? '',
      parkingTime: json['parkingTime'] ?? '',
      parkingDate: json['parkingDate'] ?? '',
      bookingTime: json['bookingTime'] ?? '',
      Amount: rawAmount,
      Hour: json['hour'] ?? '',
      sts: json['sts'] ?? '',
      userid: json['userid'] ?? "",
      subscriptiontype: json['subsctiptiontype'] ?? '',
      payableDuration: Duration.zero,
      bookType: json['bookType'] ?? "",
      exitvehicledate: () {
        final raw =
            (json['exitvehicledate'] ??
                    json['exitdate'] ??
                    json['exitDate'] ??
                    '')
                .toString()
                .trim();
        return (raw.isEmpty || raw.toLowerCase() == 'null') ? '' : raw;
      }(),
      exitvehicletime: () {
        final raw =
            (json['exitvehicletime'] ??
                    json['exittime'] ??
                    json['exitTime'] ??
                    '')
                .toString()
                .trim();
        return (raw.isEmpty || raw.toLowerCase() == 'null') ? '' : raw;
      }(),
      isValet: json['isValet'] == true || json['isValet'] == 'true',
      valetCharge: json['valetCharge']?.toString() ?? "0",
      subscriptionenddate: json['subsctiptionenddate'] ?? '',
      cancelledStatus: json['cancelledStatus'],
      vehicleImages: parsedVehicleImages,
      currentCalculatedAmount: null,
    );
  }
}

class Exitcharge {
  final double amount;
  final String type;
  final String fullDayCharge;

  Exitcharge({
    required this.amount,
    required this.type,
    required this.fullDayCharge,
  });

  factory Exitcharge.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    if (json['amount'] is String) {
      parsedAmount = double.tryParse(json['amount']) ?? 0.0;
    } else if (json['amount'] is num) {
      parsedAmount = json['amount'].toDouble();
    }
    return Exitcharge(
      fullDayCharge: json['fullDayCharge'] ?? '',
      amount: parsedAmount,
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'amount': amount, 'type': type, 'fullDayCharge': fullDayCharge};
  }
}

class DashQuickExitHelper {
  static Future<void> handlePrintAndExit({
    required BuildContext context,
    required Bookingdata vehicle,
    required String vendorId,
    required String bookType,
    String? defaultVendorName,
    VoidCallback? onExitSuccess,
    String paymentMode = 'Cash',
  }) async {
    final String bookingId = vehicle.id;
    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Booking ID not found')),
      );
      return;
    }

    try {
      double baseAmt = 0.0;
      if (vehicle.currentCalculatedAmount != null &&
          vehicle.currentCalculatedAmount!.isNotEmpty &&
          vehicle.currentCalculatedAmount != '0' &&
          vehicle.currentCalculatedAmount != '0.0' &&
          vehicle.currentCalculatedAmount != '0.00') {
        baseAmt = double.tryParse(vehicle.currentCalculatedAmount!.trim()) ?? 0.0;
      }

      if (baseAmt <= 0) {
        try {
          final fromApi = await UniversalPrintHelper.getPrintAmountFromAPI(
            bookingId,
          ).timeout(const Duration(seconds: 4));
          baseAmt = double.tryParse(fromApi.trim()) ?? 0.0;
        } catch (_) {}
      }

      if (baseAmt <= 0) {
        baseAmt = double.tryParse(vehicle.amount.toString().trim()) ?? 0.0;
      }

      // Add valet charge if vehicle has valet
      final double valetAmt = (vehicle.isValet ||
              (double.tryParse(vehicle.valetCharge) ?? 0.0) > 0)
          ? (double.tryParse(vehicle.valetCharge) ?? 0.0)
          : 0.0;
      double finalTotal = baseAmt + valetAmt;

      if (GlobalVendorDashCache.vendor == null && vendorId.isNotEmpty) {
        try {
          final vendorResponse = await http
              .get(
                Uri.parse(
                  '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=$vendorId',
                ),
              )
              .timeout(const Duration(seconds: 3));
          if (vendorResponse.statusCode == 200) {
            final Map<String, dynamic> vData = json.decode(vendorResponse.body);
            if (vData['data'] != null) {
              GlobalVendorDashCache.vendor = Vendor.fromJson(vData['data']);
            }
          }
        } catch (_) {}
      }

      if (GlobalVendorDashCache.vendor != null && _isInstantBooking(vehicle)) {
        final v = GlobalVendorDashCache.vendor!;
        final vt = vehicle.vehicletype.toLowerCase();
        double cap = 0.0;
        if (vt.contains('bike')) {
          cap = v.maxBikeAmount;
        } else if (vt.contains('car')) {
          cap = v.maxCarAmount;
        } else {
          cap = v.maxOthersAmount;
        }
        if (cap > 0 && finalTotal > cap) {
          finalTotal = cap;
        }
      }

      final String currentAmount = (finalTotal == finalTotal.roundToDouble())
          ? finalTotal.round().toString()
          : finalTotal.toStringAsFixed(2);

      String durationForReceipt = '';
      final dt = UniversalPrintHelper.tryParseDateTime(
        date: vehicle.parkingDate,
        time: vehicle.parkingTime,
      );
      if (dt != null) {
        final dur = DateTime.now().difference(dt);
        if (!dur.isNegative) {
          final h = dur.inHours.toString().padLeft(2, '0');
          final m = (dur.inMinutes % 60).toString().padLeft(2, '0');
          durationForReceipt = '$h Hours $m Minutes';
        }
      }
      if ((durationForReceipt.isEmpty ||
              durationForReceipt == '00 Hours 00 Minutes') &&
          vehicle.payableDuration != Duration.zero) {
        final h = vehicle.payableDuration.inHours.toString().padLeft(2, '0');
        final m = (vehicle.payableDuration.inMinutes % 60).toString().padLeft(2, '0');
        durationForReceipt = '$h Hours $m Minutes';
      }
      if (durationForReceipt.isEmpty ||
          durationForReceipt == '00 Hours 00 Minutes') {
        durationForReceipt = '00 Hours 01 Minute';
      }

      if (!context.mounted) return;
      try {
        await UniversalPrintHelper.printTicket(
          context: context,
          vendorName: defaultVendorName ?? vehicle.vendorname,
          bookingId: bookingId,
          invoiceId: vehicle.invoiceid,
          vehicleType: vehicle.vehicletype,
          vehicleNumber: vehicle.vehicleNumber,
          parkingDate: vehicle.parkingDate,
          parkingTime: vehicle.parkingTime,
          amount: currentAmount,
          personName: vehicle.username,
          valetCharge: null,
          mobileNumber: vehicle.mobilenumber,
          vendorId: vendorId,
          bookType: bookType,
          sts: vehicle.sts,
          preCalculatedDuration: durationForReceipt,
          fastPrint: true,
          instantParkingReceipt: true,
          isPrintAndExit: true,
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Print failed: $e');
      }

      await _performQuickExit(context, vehicle, currentAmount, paymentMode);

      final now = DateTime.now();
      final exitDate = DateFormat('dd-MM-yyyy').format(now);
      final exitTime = DateFormat('hh:mm a').format(now);

      if (context.mounted) {
        await BookingTicketDialog.show(
          context: context,
          vendorName: defaultVendorName ?? vehicle.vendorname,
          bookingId: bookingId,
          invoiceId: vehicle.invoiceid,
          vehicleType: vehicle.vehicletype,
          vehicleNumber: vehicle.vehicleNumber,
          parkingDate: vehicle.parkingDate,
          parkingTime: vehicle.parkingTime,
          amount: currentAmount,
          personName: vehicle.username,
          mobileNumber: vehicle.mobilenumber,
          receiptSts: vehicle.sts,
          appliedValetAmount: 0.0, // currentAmount already includes valet
          instantParkingReceipt: true,
          vendorId: vendorId,
          bookType: bookType,
          isPrintAndExit: true,
          exitDate: exitDate,
          exitTime: exitTime,
        );
      }

      if (onExitSuccess != null) {
        onExitSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exit failed: $e')));
      }
    }
  }

  static Future<void> _performQuickExit(
    BuildContext context,
    Bookingdata vehicle,
    String amount,
    String paymentMode,
  ) async {
    final String bookingId = vehicle.id;
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId');

    final parkedDateTime =
        UniversalPrintHelper.tryParseDateTime(
          date: vehicle.parkingDate,
          time: vehicle.parkingTime,
        ) ??
        DateTime.now();

    var duration = DateTime.now().difference(parkedDateTime);
    if (duration.isNegative) duration = Duration.zero;
    final formattedDuration = _formatDuration(duration);
    final parkingCharge = double.tryParse(amount.trim()) ?? 0.0;

    final Map<String, dynamic> requestBody = {
      'amount': parkingCharge,
      'hour': formattedDuration,
      'paymentMode': paymentMode,
      'totalamout': parkingCharge,
    };

    final userId = vehicle.userid.trim();
    if (userId.isNotEmpty) {
      try {
        final gstData = await _fetchGstFeeForExit();
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
      } catch (_) {}
    }

    try {
      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        GlobalRecentExits.exitedBookingIds.add(bookingId);
        GlobalVendorDashCache.carsOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.bikesOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.othersOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.carsCompleted = null;
        GlobalVendorDashCache.bikesCompleted = null;
        GlobalVendorDashCache.othersCompleted = null;
        await LocalDbService.markBookingCompletedOffline(
          bookingId,
          amount: parkingCharge,
          paymentMode: paymentMode,
        );
        GlobalVendorSearchCache.allVendors = [];
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vehicle exited successfully ($paymentMode)!'),
            ),
          );
        }
      } else {
        throw Exception('Failed to exit vehicle (${response.statusCode})');
      }
    } catch (e) {
      final isOffline =
          e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException');
      if (isOffline) {
        // Offline Exit Flow
        await LocalDbService.addPendingAction({
          'type': 'EXIT_BOOKING',
          'offline_id': bookingId,
          'payload': {'bookingId': bookingId, ...requestBody},
        });
        await LocalDbService.markBookingCompletedOffline(
          bookingId,
          amount: double.tryParse(
            requestBody['totalamout']?.toString() ??
                requestBody['amount']?.toString() ??
                '0',
          ),
          paymentMode: paymentMode,
        );
        GlobalRecentExits.exitedBookingIds.add(bookingId);
        GlobalVendorDashCache.carsOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.bikesOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.othersOnParking?.removeWhere(
          (v) => v.id == bookingId,
        );
        GlobalVendorDashCache.carsCompleted = null;
        GlobalVendorDashCache.bikesCompleted = null;
        GlobalVendorDashCache.othersCompleted = null;
        GlobalVendorSearchCache.allVendors = [];

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vehicle exited offline ($paymentMode)! Will sync later.',
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to exit vehicle: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> _fetchGstFeeForExit() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}gst-fee/all'),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status'] == true &&
          jsonResponse['data'] is List &&
          jsonResponse['data'].isNotEmpty) {
        return jsonResponse['data'][0];
      }
    }
    return {'gst': 0.0, 'handlingfee': 0.0};
  }

  static double _roundUpToNearestRupeeForExit(double value) {
    if (value <= 0) return 0.0;
    int intPart = value.floor();
    double decimalPart = value - intPart;
    if (decimalPart > 0.001) {
      return (intPart + 1).toDouble();
    }
    return intPart.toDouble();
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
