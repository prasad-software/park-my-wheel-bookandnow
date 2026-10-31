import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http_parser/http_parser.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/addcarviewcar/mycars.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mywheels/services/local_db_service.dart';
import 'package:mywheels/services/pinelabs_print_helper.dart';
import '../customer/parking/bookparking.dart';
import 'menus/parkingchart.dart';
import 'upi_payment_qr.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'vendorsearch.dart';
import 'package:mywheels/services/plutus_smart.dart';

class vendorChooseParkingPage extends StatefulWidget {
  final String vendorid;

  const vendorChooseParkingPage({super.key, required this.vendorid});

  @override
  _ChooseParkingPageState createState() => _ChooseParkingPageState();
}

class _ChooseParkingPageState extends State<vendorChooseParkingPage> {
  Color customTeal = ColorUtils.primarycolor();
  DateTime? selectedDateTime;
  String?
  _selectedSubscriptionType; // Variable to store the selected subscription type
  String? _selectedOption = 'Instant';
  late Future<List<Car>> _futureCars;
  String? _vendorName;
  late Future<List<Vendor>> _vendors;
  String? _selectedVendor;
  Vendor? _vendor;
  List<String> cate = ["Car", "Bike", "Others"];
  Map<String, dynamic>? _availableSlots;
  String? _defaultVehicleType;
  bool _isCheckingSlots = false;

  // Toggle states for Book, Print, Exit, and Vehicle Upload buttons
  bool _bookEnabled = true;
  bool _printEnabled = true;
  bool _exitEnabled = true;
  bool _vehicleUploadEnabled = true;
  bool _slotViewEnabled = true;
  bool _bookAndShowEnabled = true;
  bool _valetEnabled = false;
  double _valetChargeSetting = 0.0;
  bool _showOptionalInfo = false;
  bool _isValetSelected = true;
  int? _selectedPass;
  String _paymentType = 'On Entry';
  String _paymentMode = 'Online';
  String _pinelabsPaymentMethod = 'Card';
  String? _vendorUpiId;
  Map<String, bool> _enabledSettings = {};

  final TextEditingController _valetTokenController = TextEditingController();
  final TextEditingController _valetLocationController =
      TextEditingController();
  final FocusNode _valetTokenFocusNode = FocusNode();
  final FocusNode _valetLocationFocusNode = FocusNode();

  List<dynamic> _valetDrivers = [];
  String? _selectedValetDriverId;
  int _valetDropdownKey = 0;

  Future<void> _fetchValetDrivers() async {
    try {
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/valet-drivers/${widget.vendorid}',
          ).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/valet-drivers/${widget.vendorid}',
          ),
        );
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/valet-drivers/${widget.vendorid}',
              ).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }
      print('Valet Drivers API Status: ${response.statusCode}');
      print('Valet Drivers API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          setState(() {
            _valetDrivers = decoded;
          });
        } else if (decoded is Map && decoded['data'] is List) {
          setState(() {
            _valetDrivers = decoded['data'];
          });
        } else if (decoded is Map && decoded['drivers'] is List) {
          setState(() {
            _valetDrivers = decoded['drivers'];
          });
        } else {
          print('Unrecognized data structure for valet drivers: $decoded');
        }
      }
    } catch (e) {
      print('Error fetching valet drivers: $e');
    }
  }

  // Vehicle images (optional) - captured from camera
  List<File> _vehicleImages = [];
  List<Uint8List> _vehicleImageBytes = [];
  final http.Client _httpClient = http.Client();
  final ImagePicker _imagePicker = ImagePicker();

  // Cached connectivity status to eliminate redundant ~60ms platform channel waits on button press
  bool _isDeviceOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void _initConnectivityMonitoring() {
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isDeviceOnline =
              results.isNotEmpty && results.first != ConnectivityResult.none;
        });
      }
    }).catchError((_) {});

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (mounted) {
        setState(() {
          _isDeviceOnline =
              results.isNotEmpty && results.first != ConnectivityResult.none;
        });
      }
    });
  }

  /// Pre-warms HTTP keep-alive socket so booking API calls skip DNS/TLS handshake overhead
  void _preWarmHttpConnection() {
    try {
      _httpClient
          .get(
            Uri.parse('${ApiConfig.baseUrl}vendor/machinecreatebooking'),
            headers: {'Authorization': 'Bearer your_token'},
          )
          .timeout(const Duration(seconds: 2))
          .catchError((_) => http.Response('', 404));
    } catch (_) {}
  }

  Future<void> _fetchVendorData() async {
    try {
      print('Fetching data for vendor ID: ${widget.vendorid}');

      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
          ).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
          ),
        );
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
              ).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Parsed Response Data: $data');

        // Here we assume the response is structured as you showed
        // Check if 'data' is present and not null
        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _vendorName = data['data']['vendorName'];
            _vendorUpiId = data['data']['upiId']?.toString();
          });
        } else {
          // If 'data' is null, throw an exception with the message from the API
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception(
          'Failed to load vendor data, status code: ${response.statusCode}',
        );
      }
    } catch (error) {
      print('Error fetching vendor ccreate data: $error');

      // Display a user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load vendor data. Please try again later.'),
        ),
      );
    }
  }

  List<ParkingCharge> charges = [];
  int _selectedIndex = 0;
  String? selectedParkingPlace;
  String? selectedCar;
  Future<void> _fetchAvailableSlots() async {
    setState(() {
      _isCheckingSlots = true;
    });

    try {
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/availableslots/${widget.vendorid}',
          ).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          // Offline with no cache: provide generous defaults so bookings aren't blocked
          response = http.Response(
            jsonEncode({'Cars': 999, 'Bikes': 999, 'Others': 999}),
            200,
          );
        }
      } else {
        response = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/availableslots/${widget.vendorid}',
          ),
        );
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/availableslots/${widget.vendorid}',
              ).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        setState(() {
          _availableSlots = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load available slots');
      }
    } catch (e) {
      print('Error fetching available slots: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error checking available slots')),
      );
    } finally {
      setState(() {
        _isCheckingSlots = false;
      });
    }
  }

  bool _parseBool(dynamic value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  // Fetch toggle states from backend
  Future<void> _fetchToggleStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localBookEnabled = prefs.getBool('bookEnabled_${widget.vendorid}');
      final localPrintEnabled = prefs.getBool(
        'printEnabled_${widget.vendorid}',
      );
      final localExitEnabled = prefs.getBool('exitEnabled_${widget.vendorid}');
      final localBookAndShowEnabled = prefs.getBool(
        'bookAndShowEnabled_${widget.vendorid}',
      );

      if (mounted) {
        setState(() {
          if (localBookEnabled != null) _bookEnabled = localBookEnabled;
          if (localPrintEnabled != null) _printEnabled = localPrintEnabled;
          if (localExitEnabled != null) _exitEnabled = localExitEnabled;
          if (localBookAndShowEnabled != null) {
            _bookAndShowEnabled = localBookAndShowEnabled;
          }
        });
      }

      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/get-toggle-states/${widget.vendorid}',
          ).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/get-toggle-states/${widget.vendorid}',
          ),
        );
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/get-toggle-states/${widget.vendorid}',
              ).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final bookVal = _parseBool(
          data['bookEnabled'],
          defaultValue: localBookEnabled ?? true,
        );
        final printVal = _parseBool(
          data['printEnabled'],
          defaultValue: localPrintEnabled ?? true,
        );
        final exitVal = _parseBool(
          data['exitEnabled'],
          defaultValue: localExitEnabled ?? true,
        );
        final bookAndShowVal = _parseBool(
          data['bookAndShowEnabled'],
          defaultValue: localBookAndShowEnabled ?? true,
        );
        final vehicleUploadVal = _parseBool(
          data['vehicleUploadEnabled'],
          defaultValue: true,
        );
        final slotViewVal = _parseBool(
          data['slotViewEnabled'],
          defaultValue: true,
        );
        final valetVal = _parseBool(data['valetEnabled'], defaultValue: false);

        if (mounted) {
          setState(() {
            _bookEnabled = bookVal;
            _printEnabled = printVal;
            _exitEnabled = exitVal;
            _vehicleUploadEnabled = vehicleUploadVal;
            _slotViewEnabled = slotViewVal;
            _bookAndShowEnabled = bookAndShowVal;
            _valetEnabled = valetVal;
            _valetChargeSetting =
                double.tryParse(data['valetCharge']?.toString() ?? '0') ?? 0.0;
            _isValetSelected = _valetEnabled;
          });
        }

        await prefs.setBool('bookEnabled_${widget.vendorid}', bookVal);
        await prefs.setBool('printEnabled_${widget.vendorid}', printVal);
        await prefs.setBool('exitEnabled_${widget.vendorid}', exitVal);
        await prefs.setBool(
          'bookAndShowEnabled_${widget.vendorid}',
          bookAndShowVal,
        );

        final savedValetCharge = prefs.getString(
          'valetCharge_${widget.vendorid}',
        );
        if (savedValetCharge != null) {
          setState(() {
            _valetChargeSetting =
                double.tryParse(savedValetCharge) ?? _valetChargeSetting;
          });
        }

        setState(() {
          _isPineLabsEnabled = prefs.getBool('isPineLabsEnabled') ?? false;
        });

        if (_valetEnabled) {
          _fetchValetDrivers();
        }
      } else {
        // If API doesn't exist yet or returns error, use default values
        print('Failed to fetch toggle states: ${response.statusCode}');
      }
    } catch (error) {
      // If API doesn't exist yet, use default values (false)
      print('Error fetching toggle states: $error');
    }
  }

  Future<void> _updateValetGlobalState(bool isEnabled) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/update-toggle-states/${widget.vendorid}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bookEnabled': _bookEnabled,
          'printEnabled': _printEnabled,
          'exitEnabled': _exitEnabled,
          'vehicleUploadEnabled': _vehicleUploadEnabled,
          'slotViewEnabled': _slotViewEnabled,
          'bookAndShowEnabled': _bookAndShowEnabled,
          'valetEnabled': isEnabled,
          'valetCharge': _valetChargeSetting.toString(),
        }),
      );
      if (response.statusCode == 200) {
        print('Valet global state updated successfully');
      } else {
        print('Failed to update valet global state: ${response.statusCode}');
      }
    } catch (error) {
      print('Error updating valet global state: $error');
    }
  }

  int _defaultVehicleIndex(String? defaultType) {
    final carOn = _enabledSettings['carEnabled'] ?? true;
    final bikeOn = _enabledSettings['bikeEnabled'] ?? true;
    final othersOn = _enabledSettings['othersEnabled'] ?? true;

    if (defaultType == 'Car' && carOn) return 0;
    if (defaultType == 'Bike' && bikeOn) return 1;
    if (defaultType == 'Others' && othersOn) return 2;

    if (carOn) return 0;
    if (bikeOn) return 1;
    if (othersOn) return 2;
    return 0; // Car (default when all off)
  }

  Future<void> _fetchEnabledSettings() async {
    try {
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchenable/${widget.vendorid}',
          ).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchenable/${widget.vendorid}',
          ),
        );
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/fetchenable/${widget.vendorid}',
              ).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final prefs = await SharedPreferences.getInstance();
        final defaultType = prefs.getString(
          'defaultVehicleType_${widget.vendorid}',
        );

        setState(() {
          _defaultVehicleType = defaultType;
          _enabledSettings = data.map(
            (key, value) => MapEntry(key, value as bool),
          );
          _selectedIndex = _defaultVehicleIndex(_defaultVehicleType);
        });
      }
    } catch (e) {
      print('Error fetching enabled settings: $e');
    }
  }

  Future<List<ParkingCharge>> fetchParkingCharges(String vendorId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId',
    ); // Replace with your actual API URL

    try {
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(url.toString());
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(url);
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              url.toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }

      // Print response status and body for debugging
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Print the decoded JSON to check the structure
        print('Decoded JSON: $data');

        // Check if the 'vendor' object and its 'charges' field exist
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges'].map(
              (item) => ParkingCharge.fromJson(item),
            ),
          );

          // Print the charges list to verify it's populated
          print('Charges: $charges');

          return charges;
        } else {
          throw Exception('Charges data not found');
        }
      } else {
        throw Exception('Failed to load parking charges');
      }
    } catch (e) {
      // Print the error message for debugging
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  bool isHourly = true;
  List<String> cars = [];
  bool isLoading = false;
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController carController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();
  final TextEditingController datTimeController = TextEditingController();
  final TextEditingController subscriptionController = TextEditingController();
  final TextEditingController dateeTimeController = TextEditingController();
  final TextEditingController CartypeController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController checkout = TextEditingController();
  final TextEditingController subscriptionDateTimeController =
      TextEditingController();
  final FocusNode _checkout = FocusNode();
  final FocusNode _subscriptionFocusNode = FocusNode();
  final FocusNode _dateeTimeFocusNode = FocusNode();
  final FocusNode _CartypeFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();
  final FocusNode _carFocusNode = FocusNode();
  final FocusNode _dateTimeFocusNode = FocusNode();
  late Timer _timer;
  final String apiUrl = '${ApiConfig.baseUrl}get-slot-details-vendor';
  bool _isLoading = false;
  bool _isPineLabsEnabled = false;
  String _activeLoadingButton = '';
  String? _selectedSubscription;
  String? dropdownValue;
  final List<String> subscriptionOptions = [
    "Weekly Subscription",
    "15 Days Subscription",
    "Monthly Subscription",
  ];

  String? _cachedOperationalTimings;

  void _fetchBusinessHoursForCache() {
    http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}vendor/fetchbusinesshours/${widget.vendorid}',
          ),
        )
        .then((response) {
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

                _cachedOperationalTimings =
                    '${formatTime(todayTiming['openTime'])} to ${formatTime(todayTiming['closeTime'])}';
              }
            }
          }
        })
        .catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _initConnectivityMonitoring();
    _preWarmHttpConnection();
    _fetchVendorData();
    _fetchAvailableSlots();
    _fetchToggleStates();
    _fetchEnabledSettings();
    _fetchBusinessHoursForCache();
    fetchParkingCharges(widget.vendorid)
        .then((fetchedCharges) {
          setState(() {
            charges = fetchedCharges;
            isLoading = false; // Update to stop loading spinner
          });
        })
        .catchError((e) {
          print('Error fetching charges: $e');
          setState(() {
            isLoading = false; // Stop loading spinner even on error
          });
        });
    _vendors = fetchVendors();
    _futureCars = fetchCars(widget.vendorid);
    final now = DateTime.now();
    datTimeController.text = _formatDateTime(now);
    dateTimeController.text = _getFormattedCurrentDateTime();
    selectedDateTime = now;
    _setSelectedIndex("Car");
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _selectedOption != 'Instant') return;
      final liveNow = DateTime.now();
      setState(() {
        selectedDateTime = liveNow;
        dateTimeController.text = _getFormattedCurrentDateTime();
      });
    });
    dropdownValue = subscriptionOptions.first;
    if (Platform.isAndroid) {
      UniversalPrintHelper.warmUpPrinter();
      _checkLostImageData();
    }
  }

  // Function to get the current date and time formatted as "yyyy-MM-dd hh:mm:ss a"
  String _getFormattedCurrentDateTime() {
    DateTime now = DateTime.now();
    DateFormat formatter = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ); // 12-hour format with AM/PM
    return formatter.format(now);
  }

  void _setSelectedIndex(String value) {
    setState(() {
      _selectedIndex = cate.indexOf(value);
    });
  }

  // String _getFormattedCurrentDateTime() {
  //   DateTime now = DateTime.now();
  //   DateFormat formatter = DateFormat('yyyy-MM-dd hh:mm:ss a');
  //   return formatter.format(now);
  // }
  void _showDateTimePicker() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(
                now.year,
                now.month,
                now.day,
              ), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                setState(() {
                  selectedDateTime = dateTime;
                  dateController.text = DateFormat(
                    "dd-MM-yyyy",
                  ).format(dateTime); // Set date
                  timeController.text = DateFormat(
                    "hh:mm a",
                  ).format(dateTime); // Set time
                  datTimeController.text = _formatDateTime(
                    dateTime,
                  ); // Set date and time in the text box

                  // Update the correct controller based on selected option
                  if (_selectedOption == 'Schedule') {
                    dateeTimeController.text = _formatDateTime(
                      dateTime,
                    ); // Set for scheduled parking
                  } else if (_selectedOption == 'Instant') {
                    dateTimeController.text = _formatDateTime(
                      dateTime,
                    ); // Set for instant parking
                  } else if (_selectedOption == 'Subscription') {
                    subscriptionDateTimeController.text = _formatDateTime(
                      dateTime,
                    );
                    dateTimeController.text = _formatDateTime(dateTime);
                  }

                  print(
                    "Selected Date: ${dateController.text}, Selected Time: ${timeController.text}",
                  ); // Debugging line
                });
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }

  void _showDateTimePickerForSubscription() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(
                now.year,
                now.month,
                now.day,
              ), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                setState(() {
                  selectedDateTime = dateTime;
                  subscriptionDateTimeController.text = _formatDateTime(
                    dateTime,
                  );
                  dateTimeController.text = _formatDateTime(dateTime);
                  print(
                    "Selected Subscription Date: ${subscriptionDateTimeController.text}",
                  ); // Debugging line
                });
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }

  void _tenditivecheckout() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(
                now.year,
                now.month,
                now.day,
              ), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                setState(() {
                  selectedDateTime = dateTime;
                  dateController.text = DateFormat(
                    "dd-MM-yyyy",
                  ).format(dateTime); // Set date
                  timeController.text = DateFormat(
                    "hh:mm a",
                  ).format(dateTime); // Set time
                  checkout.text = _formatDateTime(
                    dateTime,
                  ); // Set date and time in the text box
                  print(
                    "Selected Date: ${checkout.text}, Selected Time: ${timeController.text}",
                  ); // Debugging line
                });
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }

  /// Compresses vehicle image to ultra-light (~3-4KB) thumbnail immediately.
  /// 200x200 at quality 20 produces a clean ~3KB thumbnail that uploads in ~20ms,
  /// matching the exact same speed as direct booking without photo.
  Future<File> _compressVehicleImage(File file) async {
    try {
      final targetPath =
          '${file.parent.path}/veh_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 20,
        minWidth: 200,
        minHeight: 200,
      );
      if (result != null) {
        return File(result.path);
      }
      return file;
    } catch (e) {
      debugPrint('Image compression error: $e');
      return file;
    }
  }

  String? _extractVehicleNumberFromRecognizedText(
    RecognizedText recognizedText,
  ) {
    if (recognizedText.text.trim().isEmpty) return null;

    const validStates = {
      'AN',
      'AP',
      'AR',
      'AS',
      'BR',
      'CG',
      'CH',
      'DD',
      'DN',
      'DL',
      'GA',
      'GJ',
      'HR',
      'HP',
      'JH',
      'JK',
      'KA',
      'KL',
      'LA',
      'LD',
      'MP',
      'MH',
      'MN',
      'ML',
      'MZ',
      'NL',
      'OD',
      'OR',
      'PB',
      'PY',
      'RJ',
      'SK',
      'TN',
      'TS',
      'TR',
      'UP',
      'UK',
      'UA',
      'WB',
    };

    const noiseWords = [
      'INDIA',
      'IND',
      'HERO',
      'HONDA',
      'BAJAJ',
      'TVS',
      'YAMAHA',
      'SUZUKI',
      'ROYAL',
      'ENFIELD',
      'KTM',
      'KAWASAKI',
      'HYUNDAI',
      'MARUTI',
      'TATA',
      'MAHINDRA',
      'TOYOTA',
      'KIA',
      'RTO',
      'DEALER',
      'MOTORS',
      'MOTOR',
      'PARKING',
      'TICKET',
      'PUNE',
      'MUMBAI',
      'DELHI',
      'BANGALORE',
      'CHENNAI',
      'THANK',
      'YOU',
      'GOVT',
      'POLICE',
    ];

    String correctToDigits(String str) {
      final sb = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        final ch = str[i];
        switch (ch) {
          case 'O':
          case 'D':
          case 'Q':
            sb.write('0');
            break;
          case 'I':
          case 'L':
            sb.write('1');
            break;
          case 'Z':
            sb.write('2');
            break;
          case 'S':
            sb.write('5');
            break;
          case 'B':
            sb.write('8');
            break;
          case 'G':
            sb.write('6');
            break;
          case 'T':
            sb.write('7');
            break;
          default:
            if (RegExp(r'[0-9]').hasMatch(ch)) {
              sb.write(ch);
            }
        }
      }
      return sb.toString();
    }

    String correctToLetters(String str) {
      final sb = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        final ch = str[i];
        switch (ch) {
          case '0':
            sb.write('O');
            break;
          case '1':
            sb.write('I');
            break;
          case '8':
            sb.write('B');
            break;
          case '5':
            sb.write('S');
            break;
          case '2':
            sb.write('Z');
            break;
          default:
            if (RegExp(r'[A-Z]').hasMatch(ch)) {
              sb.write(ch);
            }
        }
      }
      return sb.toString();
    }

    String correctToDelhiRto(String str) {
      if (str.length >= 2 && RegExp(r'[A-Z]$').hasMatch(str)) {
        final digits = correctToDigits(str.substring(0, str.length - 1));
        return '$digits${str[str.length - 1]}';
      }
      return correctToDigits(str);
    }

    // 1. Gather all TextLines across all blocks and sort vertically by boundingBox.top
    // This handles stacked two-line bike plates (e.g. MH 14 on top, DZ 8899 on bottom)
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rawLinesList =
        allLines.isNotEmpty
            ? allLines.map((l) => l.text).toList()
            : recognizedText.text.split('\n');

    // 2. Clean lines, remove punctuation and known noise tokens (like IND, vehicle brands)
    final cleanedLines = <String>[];
    for (final line in rawLinesList) {
      String l = line.toUpperCase().trim();
      if (l.isEmpty) continue;
      l = l.replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ');

      for (final noise in noiseWords) {
        l = l.replaceAll(RegExp(r'\b' + noise + r'\b'), ' ');
      }

      // Handle glued "IND" e.g. "INDMH12AB1234" -> "MH12AB1234"
      if (l.startsWith('IND') && l.length > 5) {
        final sub = l.substring(3).trim();
        if (validStates.any((st) => sub.startsWith(st))) {
          l = sub;
        }
      }

      l = l.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (l.isNotEmpty) {
        cleanedLines.add(l);
      }
    }

    if (cleanedLines.isEmpty) return null;

    // 3. Build candidate strings:
    //    A. All lines joined with space & without space (multi-line bike plates)
    //    B. Pairs and triplets of consecutive lines
    //    C. Individual cleaned lines
    final candidates = <String>[];
    candidates.add(cleanedLines.join(' '));
    candidates.add(cleanedLines.join(''));

    for (int i = 0; i < cleanedLines.length - 1; i++) {
      candidates.add('${cleanedLines[i]} ${cleanedLines[i + 1]}');
      candidates.add('${cleanedLines[i]}${cleanedLines[i + 1]}');
    }

    for (int i = 0; i < cleanedLines.length - 2; i++) {
      candidates.add(
        '${cleanedLines[i]} ${cleanedLines[i + 1]} ${cleanedLines[i + 2]}',
      );
      candidates.add(
        '${cleanedLines[i]}${cleanedLines[i + 1]}${cleanedLines[i + 2]}',
      );
    }

    candidates.addAll(cleanedLines);

    // --- Step A: Check Bharat (BH) series (e.g. 22BH1234AA) ---
    final bhRegex = RegExp(
      r'\b([0-9]{2})[ -]?(BH)[ -]?([0-9]{4})[ -]?([A-Z]{1,2})\b',
      caseSensitive: false,
    );
    for (final c in candidates) {
      final m = bhRegex.firstMatch(c);
      if (m != null) {
        return '${m.group(1)}BH${m.group(3)}${m.group(4)}'.toUpperCase();
      }
    }

    // --- Step B: Strict Matching with Known State Codes ---
    for (final state in validStates) {
      final isDelhi = (state == 'DL');

      for (final c in candidates) {
        // Standard clean 3-4 digit registration number
        final standardCleanRegex =
            isDelhi
                ? RegExp(
                  r'\bDL[ -]?([0-9]{1,2}[A-Z]?)[ -]?([A-Z]{1,3})?[ -]?([0-9]{3,4})\b',
                  caseSensitive: false,
                )
                : RegExp(
                  r'\b' +
                      state +
                      r'[ -]?([0-9]{1,2})[ -]?([A-Z]{1,3})?[ -]?([0-9]{3,4})\b',
                  caseSensitive: false,
                );

        final cleanMatch = standardCleanRegex.firstMatch(c);
        if (cleanMatch != null) {
          final rto = cleanMatch.group(1)!;
          final series = cleanMatch.group(2) ?? '';
          final num = cleanMatch.group(3)!;
          return '$state$rto$series$num';
        }

        // Tolerance for OCR character substitutions
        final standardOcrRegex =
            isDelhi
                ? RegExp(
                  r'\bDL[ -]?([0-9OIZSBDGQ]{1,2}[A-Z]?)[ -]?([A-Z0-9]{1,3})?[ -]?([0-9OIZSBDGQ]{3,4})\b',
                  caseSensitive: false,
                )
                : RegExp(
                  r'\b' +
                      state +
                      r'[ -]?([0-9OIZSBDGQ]{1,2})[ -]?([A-Z0-9]{1,3})?[ -]?([0-9OIZSBDGQ]{3,4})\b',
                  caseSensitive: false,
                );

        final ocrMatch = standardOcrRegex.firstMatch(c);
        if (ocrMatch != null) {
          final rtoRaw = ocrMatch.group(1)!;
          final seriesRaw = ocrMatch.group(2);
          final numRaw = ocrMatch.group(3)!;

          final rto =
              isDelhi ? correctToDelhiRto(rtoRaw) : correctToDigits(rtoRaw);
          final series = seriesRaw != null ? correctToLetters(seriesRaw) : '';
          final num = correctToDigits(numRaw);

          if (rto.isNotEmpty && num.length >= 3) {
            return '$state$rto$series$num';
          }
        }

        // 1 to 2 digit VIP numbers
        final vipCleanRegex =
            isDelhi
                ? RegExp(
                  r'\bDL[ -]?([0-9]{1,2}[A-Z]?)[ -]?([A-Z]{1,3})[ -]?([0-9]{1,2})\b',
                  caseSensitive: false,
                )
                : RegExp(
                  r'\b' +
                      state +
                      r'[ -]?([0-9]{1,2})[ -]?([A-Z]{1,3})[ -]?([0-9]{1,2})\b',
                  caseSensitive: false,
                );

        final vipMatch = vipCleanRegex.firstMatch(c);
        if (vipMatch != null) {
          final rto = vipMatch.group(1)!;
          final series = vipMatch.group(2)!;
          final num = vipMatch.group(3)!;
          return '$state$rto$series$num';
        }
      }
    }

    // --- Step C: Generic 2-letter state code ---
    final genericRegex = RegExp(
      r'\b([A-Z]{2})[ -]?([0-9]{1,2}[A-Z]?)[ -]?([A-Z]{1,3})?[ -]?([0-9]{3,4})\b',
      caseSensitive: false,
    );
    for (final c in candidates) {
      final m = genericRegex.firstMatch(c);
      if (m != null) {
        final st = m.group(1)!.toUpperCase();
        final rto = m.group(2)!;
        final series = m.group(3) ?? '';
        final num = m.group(4)!;
        return '$st$rto$series$num';
      }
    }

    // --- Step D: Compact alphanumeric check without spaces ---
    for (final c in candidates) {
      final compact = c.replaceAll(RegExp(r'\s+'), '');
      final match = RegExp(
        r'([A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{3,4})',
      ).firstMatch(compact);
      if (match != null) {
        return match.group(1);
      }
    }

    // --- Step E: Fallback to trailing 4 digits ---
    final fourDigitRegex = RegExp(r'\b([0-9]{4})\b');
    final fourMatch = fourDigitRegex.firstMatch(recognizedText.text);
    if (fourMatch != null) {
      return fourMatch.group(1);
    }

    return null;
  }

  Future<void> _checkLostImageData() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) {
        return;
      }
      final XFile? file = response.file;
      if (file != null) {
        await _processCapturedPhoto(file);
      }
    } catch (e) {
      debugPrint('Error retrieving lost image data: $e');
    }
  }

  Future<void> _captureVehicleImage() async {
    // Unfocus text fields and dismiss soft keyboard before launching camera
    _carFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    try {
      // 1. Verify camera permission before opening camera
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required to capture photo'),
              ),
            );
          }
          return;
        }
      }

      // 2. Pick image with explicit max dimensions & quality to prevent memory spikes / LMK restart
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 50,
      );

      if (photo != null) {
        await _processCapturedPhoto(photo);
      }
    } catch (e) {
      debugPrint('Failed to capture image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
      }
    } finally {
      // Ensure soft keyboard remains dismissed when returning from camera
      _carFocusNode.unfocus();
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      if (Platform.isAndroid) {
        UniversalPrintHelper.warmUpPrinter();
      }
    }
  }

  Future<void> _processCapturedPhoto(XFile photo) async {
    TextRecognizer? textRecognizer;

    // Run OCR text recognition and ultra-light thumbnail compression in parallel
    final ocrTask = () async {
      try {
        final inputImage = InputImage.fromFilePath(photo.path);
        textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText =
            await textRecognizer!.processImage(inputImage);
        return _extractVehicleNumberFromRecognizedText(recognizedText);
      } catch (ocrError) {
        debugPrint('OCR error: $ocrError');
        return null;
      } finally {
        try {
          await textRecognizer?.close();
        } catch (_) {}
      }
    }();

    final compressionTask = () async {
      try {
        final compressedFile = await _compressVehicleImage(File(photo.path));
        final bytes = await compressedFile.readAsBytes();
        return (compressedFile, bytes);
      } catch (e) {
        debugPrint('Failed to compress image: $e');
        return null;
      }
    }();

    final results = await Future.wait([ocrTask, compressionTask]);
    final detectedVehicleNumber = results[0] as String?;
    final compressedResult = results[1] as (File, Uint8List)?;

    if (mounted) {
      setState(() {
        if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
          carController.text = detectedVehicleNumber;
        } else {
          carController.clear();
        }
        if (compressedResult != null) {
          _vehicleImages = [compressedResult.$1];
          _vehicleImageBytes = [compressedResult.$2];
        }
      });

      // Keep HTTP keep-alive connection warm while operator confirms details
      _preWarmHttpConnection();

      // Explicitly dismiss keyboard and remove focus to avoid blank keyboard
      _carFocusNode.unfocus();
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

      if (detectedVehicleNumber != null && detectedVehicleNumber.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vehicle No: $detectedVehicleNumber entered',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo updated. Number plate not detected automatically - please enter manually.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeVehicleImage(int index) {
    setState(() {
      _vehicleImages.removeAt(index);
      if (index < _vehicleImageBytes.length) {
        _vehicleImageBytes.removeAt(index);
      }
    });
  }

  // Helper function to format date (day, month, year) and time (hour, minute, AM/PM)
  String _formatDateTime(DateTime dateTime) {
    return DateFormat(
      "dd-MM-yyyy hh:mm a",
    ).format(dateTime); // Full date + time with AM/PM
  }

  Future<List<Car>> fetchCars(String userId) async {
    late http.Response response;
    var connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;
    if (!isOnline) {
      var cached = LocalDbService.getCachedApiResponse(
        Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId').toString(),
      );
      if (cached != null) {
        response = http.Response(jsonEncode(cached), 200);
      } else {
        response = http.Response('{}', 500);
      }
    } else {
      response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId'),
      );
      if (response.statusCode == 200) {
        try {
          LocalDbService.cacheApiResponse(
            Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId').toString(),
            jsonDecode(response.body),
          );
        } catch (_) {}
      }
    }

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<dynamic> vehiclesJson = jsonResponse['vehicles'] ?? [];
      return vehiclesJson.map((car) => Car.fromJson(car)).toList();
    } else {
      throw Exception('Failed to load cars');
    }
  }

  Future<List<Vendor>> fetchVendors() async {
    try {
      late http.Response response;
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
      if (!isOnline) {
        var cached = LocalDbService.getCachedApiResponse(
          Uri.parse(apiUrl).toString(),
        );
        if (cached != null) {
          response = http.Response(jsonEncode(cached), 200);
        } else {
          response = http.Response('{}', 500);
        }
      } else {
        response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          try {
            LocalDbService.cacheApiResponse(
              Uri.parse(apiUrl).toString(),
              jsonDecode(response.body),
            );
          } catch (_) {}
        }
      }
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> vendorData = data['vendorData'];
        List<Vendor> vendors =
            vendorData.map((json) => Vendor.fromJson(json)).toList();
        return vendors;
      } else {
        throw Exception('Failed to load vendors');
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching vendor create booking')),
      );
      throw Exception('Failed to load vendors');
    }
  }

  void _resetFields() {
    CartypeController.clear();
    nameController.clear();
    mobileController.clear();
    carController.clear();
    subscriptionDateTimeController.clear();
    dateeTimeController.clear();
    _valetTokenController.clear();
    _valetLocationController.clear();
    checkout.clear();
    dateTimeController.text = _getFormattedCurrentDateTime();
    setState(() {
      _selectedSubscriptionType = null;
      _vehicleImages.clear();
      _vehicleImageBytes.clear();
      _selectedOption = 'Instant';
      _selectedPass = null;
      _selectedIndex = _defaultVehicleIndex(_defaultVehicleType);
      selectedDateTime = DateTime.now();
      _selectedValetDriverId = null;
      _valetDropdownKey++;
    });
  }

  void _registerParking() async {
    // Determine vehicle type
    String vehicleType;
    switch (_selectedIndex) {
      case 0:
        vehicleType = 'Car';
        break;
      case 1:
        vehicleType = 'Bike';
        break;
      case 2:
        vehicleType = 'Others';
        break;
      default:
        vehicleType = 'Unknown';
    }

    // Check available slots (skip when offline and slots not loaded)
    bool _isOnlineForSlots = _isDeviceOnline;
    if (_availableSlots != null) {
      int available = 0;
      if (vehicleType == 'Car') {
        available = _availableSlots!['Cars'] ?? 0;
      } else if (vehicleType == 'Bike') {
        available = _availableSlots!['Bikes'] ?? 0;
      } else {
        available = _availableSlots!['Others'] ?? 0;
      }

      if (available <= 0 && _isOnlineForSlots) {
        _showError(
          'No space available for $vehicleType. Please try another vehicle type or check back later.',
        );
        return;
      }
    } else if (_isOnlineForSlots) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

    // Validation for empty fields
    if (carController.text.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }

    // if (_selectedOption == 'Subscription' && _selectedSubscriptionType == null) {
    //   _showError('Please select a subscription type');
    //   return;
    // }

    if (_selectedOption == 'Subscription' &&
        subscriptionDateTimeController.text.isEmpty) {
      _showError('Please select a parking date and time for the subscription');
      return;
    }

    if (_selectedOption == 'Schedule' && dateeTimeController.text.isEmpty) {
      _showError(
        'Please select a parking date and time for the scheduled booking',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeLoadingButton = 'bookNow';
    });

    print('API: machinecreatebooking'); // Book Now uses machine API
    print(
      'Selected vehicle type: $vehicleType',
    ); // Debugging selected vehicle type

    // For Instant/Schedule: car is being parked now -> use PARKED so it shows in "On Parking" car list
    // For Subscription: use COMPLETED
    String status =
        (_selectedOption == 'Instant' || _selectedOption == 'Schedule')
            ? 'PARKED'
            : 'COMPLETED';

    DateTime now = DateTime.now();
    String approvedDate = '';
    String approvedTime = '';
    String parkingDate = '';
    String parkingTime = '';
    String amount = '';
    String subscriptionEndDate = ''; // Variable to store subscription end date

    if (_selectedOption == 'Subscription') {
      amount = _selectedAmountForBooking(vehicleType);

      // Parse the selected subscription date and time
      try {
        DateTime subscriptionDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse(subscriptionDateTimeController.text);

        // Format the dates and times
        approvedDate = DateFormat("dd-MM-yyyy").format(subscriptionDateTime);
        approvedTime = DateFormat("hh:mm a").format(subscriptionDateTime);
        parkingDate = approvedDate;
        parkingTime = approvedTime;

        // Format the subscription end date (Weekly=+7 days, Monthly=+30 days)
        subscriptionEndDate = _computeSubscriptionEndDate(
          subscriptionDateTimeController.text,
        );

        print("Subscription Start Date: $approvedDate $approvedTime");
        print("Subscription End Date: $subscriptionEndDate");
      } catch (e) {
        _showError('Invalid subscription date and time format');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else if (_selectedOption == 'Instant' || _selectedOption == 'Schedule') {
      amount = _selectedAmountForBooking(vehicleType);

      if (_selectedOption == 'Instant') {
        approvedDate = DateFormat("dd-MM-yyyy").format(now);
        approvedTime = DateFormat("hh:mm a").format(now);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
      } else if (_selectedOption == 'Schedule') {
        try {
          DateTime scheduleDateTime = DateFormat(
            "dd-MM-yyyy hh:mm a",
          ).parse(dateeTimeController.text);
          parkingDate = DateFormat("dd-MM-yyyy").format(scheduleDateTime);
          parkingTime = DateFormat("hh:mm a").format(scheduleDateTime);
        } catch (e) {
          _showError('Invalid schedule date and time format');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    // Valet charge is handled at exit, so we do not add it to the base amount here.
    // Base amount should remain the pure parking rate.
    final data = {
      'carType': CartypeController.text,
      'personName': nameController.text,
      'mobileNumber': mobileController.text,
      'vehicleNumber': _getCombinedVehicleNumber(),
      'vendorName': _vendor?.vendorName ?? '',
      'sts': _stsForBookingRequest(),
      'bookingDate': DateFormat("dd-MM-yyyy").format(now),
      'vendorId': widget.vendorid,
      'amount': amount,
      'hour': "", // TODO: Set for hourly bookings
      'status': status,
      'vehicleType': vehicleType,
      'parkingDate': parkingDate,
      'parkingTime': parkingTime,
      'bookingTime': DateFormat("hh:mm a").format(now),
      'cancelledStatus': "",
      'subsctiptiontype': _selectedSubscriptionType ?? '',
      'approvedDate': approvedDate,
      'approvedTime': approvedTime,
      'parkedDate': approvedDate,
      'subsctiptionenddate':
          subscriptionEndDate, // Include subscription end date
      'parkedTime': approvedTime,
      'tenditivecheckout': checkout.text,
      'paymentType': _paymentType,
      'paymentMode': _paymentMode,
      'bookType': isHourly ? 'Hourly' : '24 Hours',
      'valetToken': _valetTokenController.text,
      'valetLocation': _valetLocationController.text,
      'valetDriverId': _selectedValetDriverId ?? '',
      'isValet': _valetEnabled && _isValetSelected && _isValetUIApplicable(),
      'valetCharge':
          (_valetEnabled && _isValetSelected && _isValetChargeApplicable())
              ? _getValetChargeAmount().toString()
              : "0",
    };

    print('Request body: ${jsonEncode(data)}'); // Debugging request body

    try {
      final response = await _sendBookingRequest(data);

      print(
        'Response status: ${response.statusCode}',
      ); // Debugging response status
      print('Response body: ${response.body}'); // Debugging response body

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print(
          'Response success: ${responseBody['message']}',
        ); // Debugging success message

        if (responseBody['message'] == 'Booking created successfully') {
          setState(() {
            _isLoading = false;
            _activeLoadingButton = '';
          });

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentType != 'On Exit' &&
              _paymentMode == 'Online' &&
              upiUri is String &&
              upiUri.trim().isNotEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => UpiPaymentQrPage(
                      title: 'UPI Payment',
                      upiUri: upiUri.trim(),
                      amount: upiAmount,
                      vendorName: _vendor?.vendorName ?? '',
                    ),
              ),
            );
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parking successfully registered!')),
          );
          _resetFields();
          _preWarmHttpConnection();
        } else {
          _showError('${responseBody['message']}');
        }
      } else {
        String errMsg = 'Failed to register parking. Please try again.';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errBody['error'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        if (response.statusCode == 413) {
          errMsg = 'Image too large. Please try with fewer or smaller images.';
        }
        _showError(errMsg);
      }
    } catch (e) {
      print('Exception occurred: $e');
      _showError('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _activeLoadingButton = '';
      });
    }
  }

  /// Sends booking request - uses JSON when no images, multipart when vehicle images are present.
  /// Uses machinecreatebooking for all booking flows. Vehicle images are compressed before add.
  Future<http.Response> _sendBookingRequest(Map<String, dynamic> data) async {
    bool isOnline = _isDeviceOnline;
    if (!isOnline) {
      final connectivityResult = await (Connectivity().checkConnectivity());
      isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
    }

    if (!isOnline) {
      // Generate a temp booking ID that looks like the backend online ID (e.g. PMW300920261188)
      final now = DateTime.now();
      String msStr = now.millisecondsSinceEpoch.toString();
      String shortMs =
          msStr.length > 4 ? msStr.substring(msStr.length - 4) : msStr;
      String tempId = 'PMW${DateFormat("ddMMyyyy").format(now)}$shortMs';

      // Assign the generated ID into the payload so the backend permanently honors it upon sync
      data['invoiceid'] = tempId;

      await LocalDbService.addPendingAction({
        'offline_id': tempId,
        'type': 'CREATE_BOOKING',
        'payload': data,
      });

      // Cache the booking in the dashboard's API cache so it shows in the booking list offline
      final bookingCacheData = Map<String, dynamic>.from(data);
      bookingCacheData['_id'] = tempId;
      bookingCacheData['invoiceid'] = tempId;
      bookingCacheData['isOffline'] = true;
      if (_vehicleImages.isNotEmpty) {
        bookingCacheData['vehicleImages'] =
            _vehicleImages.map((f) => f.path).toList();
      }

      final String vehicleType = data['vehicleType'] ?? 'Car';
      final String vendorId = data['vendorId'] ?? widget.vendorid;
      final String status = (data['status'] ?? '').toString().toUpperCase();

      // Add to the general booking list cache
      final generalUrl =
          '${ApiConfig.baseUrl}vendor/getbookingdata/$vendorId/$vehicleType';
      await LocalDbService.addOfflineBookingToCache(
        generalUrl,
        bookingCacheData,
      );

      // Add to the appropriate filtered list (onparking or completed)
      final String filterSuffix =
          status == 'PARKED' ? 'onparking' : 'completed';
      final filteredUrl =
          '${ApiConfig.baseUrl}vendor/getbookingdata/$vendorId/$vehicleType/$filterSuffix';
      await LocalDbService.addOfflineBookingToCache(
        filteredUrl,
        bookingCacheData,
      );

      return http.Response(
        jsonEncode({
          'message': 'Booking created successfully',
          'bookingId': tempId,
          'invoiceId': tempId,
          'data': {'_id': tempId, ...data},
        }),
        200,
      );
    }

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/machinecreatebooking');
    if (_vehicleImages.isEmpty) {
      return await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer your_token',
        },
        body: jsonEncode(data),
      );
    }
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer your_token';
    for (var entry in data.entries) {
      request.fields[entry.key] = entry.value?.toString() ?? '';
    }
    for (int i = 0; i < _vehicleImages.length; i++) {
      if (i < _vehicleImageBytes.length && _vehicleImageBytes[i].isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'vehicleImages',
            _vehicleImageBytes[i],
            filename: 'vehicle_$i.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'vehicleImages',
            _vehicleImages[i].path,
            filename: 'vehicle_$i.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    }
    var streamedResponse = await _httpClient.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  // Function to display error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.red)),
      ),
    );
    print('Error displayed: $message');
  }

  // Function to book and print ticket
  Future<void> _bookAndPrint() async {
    // Determine vehicle type
    String vehicleType;
    switch (_selectedIndex) {
      case 0:
        vehicleType = 'Car';
        break;
      case 1:
        vehicleType = 'Bike';
        break;
      case 2:
        vehicleType = 'Others';
        break;
      default:
        vehicleType = 'Unknown';
    }

    // Check available slots (skip when offline and slots not loaded)
    bool _isOnlineForSlots = _isDeviceOnline;
    if (_availableSlots != null) {
      int available = 0;
      if (vehicleType == 'Car') {
        available = _availableSlots!['Cars'] ?? 0;
      } else if (vehicleType == 'Bike') {
        available = _availableSlots!['Bikes'] ?? 0;
      } else {
        available = _availableSlots!['Others'] ?? 0;
      }

      if (available <= 0 && _isOnlineForSlots) {
        _showError(
          'No space available for $vehicleType. Please try another vehicle type or check back later.',
        );
        return;
      }
    } else if (_isOnlineForSlots) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

    // Validation for empty fields
    if (carController.text.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }

    if (_selectedOption == 'Subscription' &&
        subscriptionDateTimeController.text.isEmpty) {
      _showError('Please select a parking date and time for the subscription');
      return;
    }

    if (_selectedOption == 'Schedule' && dateeTimeController.text.isEmpty) {
      _showError(
        'Please select a parking date and time for the scheduled booking',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeLoadingButton = 'bookAndPrint';
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/vendorcreatebooking');
    String status =
        'PARKED'; // Set status as PARKED for book and print (vehicle is currently parked)

    DateTime now = DateTime.now();
    String approvedDate = '';
    String approvedTime = '';
    String parkingDate = '';
    String parkingTime = '';
    String amount = '';
    String subscriptionEndDate = '';

    if (_selectedOption == 'Subscription') {
      amount = _selectedAmountForBooking(vehicleType);

      try {
        DateTime subscriptionDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse(subscriptionDateTimeController.text);
        approvedDate = DateFormat("dd-MM-yyyy").format(subscriptionDateTime);
        approvedTime = DateFormat("hh:mm a").format(subscriptionDateTime);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
        subscriptionEndDate = _computeSubscriptionEndDate(
          subscriptionDateTimeController.text,
        );
      } catch (e) {
        _showError('Invalid subscription date and time format');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else if (_selectedOption == 'Instant' || _selectedOption == 'Schedule') {
      amount = _selectedAmountForBooking(vehicleType);

      if (_selectedOption == 'Instant') {
        approvedDate = DateFormat("dd-MM-yyyy").format(now);
        approvedTime = DateFormat("hh:mm a").format(now);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
      } else if (_selectedOption == 'Schedule') {
        try {
          DateTime scheduleDateTime = DateFormat(
            "dd-MM-yyyy hh:mm a",
          ).parse(dateeTimeController.text);
          parkingDate = DateFormat("dd-MM-yyyy").format(scheduleDateTime);
          parkingTime = DateFormat("hh:mm a").format(scheduleDateTime);
        } catch (e) {
          _showError('Invalid schedule date and time format');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    double appliedValetAmount = 0.0;
    if (_valetEnabled && _isValetSelected && _isValetChargeApplicable()) {
      double valetAmount = _getValetChargeAmount();
      if (valetAmount > 0) {
        appliedValetAmount = valetAmount;
      }
    }

    // Valet charge is handled at exit, so we do not add it to the base amount here.
    // Base amount should remain the pure parking rate.

    final String stsSnapshot = _stsForBookingRequest();
    final data = {
      'carType': CartypeController.text,
      'personName': nameController.text,
      'mobileNumber': mobileController.text,
      'vehicleNumber': _getCombinedVehicleNumber(),
      'vendorName': _vendor?.vendorName ?? '',
      'sts': stsSnapshot,
      'bookingDate': DateFormat("dd-MM-yyyy").format(now),
      'vendorId': widget.vendorid,
      'amount': amount,
      'hour': "",
      'status': status,
      'vehicleType': vehicleType,
      'parkingDate': parkingDate,
      'parkingTime': parkingTime,
      'bookingTime': DateFormat("hh:mm a").format(now),
      'cancelledStatus': "",
      'subsctiptiontype': _selectedSubscriptionType ?? '',
      'approvedDate': approvedDate,
      'approvedTime': approvedTime,
      'parkedDate': approvedDate,
      'subsctiptionenddate': subscriptionEndDate,
      'parkedTime': approvedTime,
      'tenditivecheckout': checkout.text,
      'paymentType': _paymentType,
      'paymentMode': _paymentMode,
      'bookType': isHourly ? 'Hourly' : '24 Hours',
      'valetToken': _valetTokenController.text,
      'valetLocation': _valetLocationController.text,
      'valetDriverId': _selectedValetDriverId ?? '',
      'isValet': _valetEnabled && _isValetSelected && _isValetUIApplicable(),
      'valetCharge':
          (_valetEnabled && _isValetSelected && _isValetChargeApplicable())
              ? _getValetChargeAmount().toString()
              : "0",
    };

    try {
      final response = await _sendBookingRequest(data);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          _showError('Invalid server response');
          return;
        }
        final Map<String, dynamic> responseBody = Map<String, dynamic>.from(
          decoded,
        );
        if (responseBody['message'] == 'Booking created successfully') {
          final String bookingId = responseBody['bookingId']?.toString() ?? '';
          final String invoiceId =
              UniversalPrintHelper.extractInvoiceIdFromJson(responseBody);
          final String vendorName = _vendor?.vendorName ?? '';
          final String receiptAmount = _amountFromResponse(
            responseBody,
            amount,
          );
          final bool instantReceipt =
              _selectedOption == 'Instant' &&
              (vehicleType == 'Car' ||
                  vehicleType == 'Bike' ||
                  vehicleType == 'Others' ||
                  vehicleType == 'other' ||
                  vehicleType == 'Other') &&
              _selectedPass == null &&
              isHourly;

          final String printVehicleNumber = _getCombinedVehicleNumber();
          final String printPersonName = nameController.text;
          final String printMobileNumber = mobileController.text;
          final double? printValetAmount =
              appliedValetAmount > 0 ? appliedValetAmount : null;

          // Immediately clear loading spinner and reset fields so UI is ready for next vehicle in ~0.15s
          setState(() {
            _isLoading = false;
            _activeLoadingButton = '';
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking successfully registered and printed!'),
              duration: Duration(seconds: 2),
            ),
          );

          _resetFields();
          _preWarmHttpConnection();

          // Non-blocking thermal print: hardware prints in background without stalling UI
          unawaited(_printTicket(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: printVehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: receiptAmount,
            personName: printPersonName,
            mobileNumber: printMobileNumber,
            includeDuration: false,
            receiptSts: stsSnapshot,
            instantParkingReceipt: instantReceipt,
            valetChargeAmount: printValetAmount,
          ));

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentType != 'On Exit' &&
              _paymentMode == 'Online' &&
              upiUri is String &&
              upiUri.trim().isNotEmpty) {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => UpiPaymentQrPage(
                      title: 'UPI Payment',
                      upiUri: upiUri.trim(),
                      amount: upiAmount,
                      vendorName: vendorName,
                    ),
              ),
            );
          }
        } else {
          _showError('${responseBody['message']}');
        }
      } else {
        String errMsg = 'Failed to register parking. Please try again.';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errBody['error'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        if (response.statusCode == 413) {
          errMsg = 'Image too large. Please try with fewer or smaller images.';
        }
        _showError(errMsg);
      }
    } catch (e) {
      print('Exception occurred: $e');
      _showError('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _activeLoadingButton = '';
      });
    }
  }

  // Function to book parking and show digital ticket & QR code on screen
  Future<void> _bookAndShow() async {
    // Determine vehicle type
    String vehicleType;
    switch (_selectedIndex) {
      case 0:
        vehicleType = 'Car';
        break;
      case 1:
        vehicleType = 'Bike';
        break;
      case 2:
        vehicleType = 'Others';
        break;
      default:
        vehicleType = 'Unknown';
    }

    // Check available slots (skip when offline and slots not loaded)
    bool _isOnlineForSlots = _isDeviceOnline;
    if (_availableSlots != null) {
      int available = 0;
      if (vehicleType == 'Car') {
        available = _availableSlots!['Cars'] ?? 0;
      } else if (vehicleType == 'Bike') {
        available = _availableSlots!['Bikes'] ?? 0;
      } else {
        available = _availableSlots!['Others'] ?? 0;
      }

      if (available <= 0 && _isOnlineForSlots) {
        _showError(
          'No space available for $vehicleType. Please try another vehicle type or check back later.',
        );
        return;
      }
    } else if (_isOnlineForSlots) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

    // Validation for empty fields
    if (carController.text.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }

    if (_selectedOption == 'Subscription' &&
        subscriptionDateTimeController.text.isEmpty) {
      _showError('Please select a parking date and time for the subscription');
      return;
    }

    if (_selectedOption == 'Schedule' && dateeTimeController.text.isEmpty) {
      _showError(
        'Please select a parking date and time for the scheduled booking',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeLoadingButton = 'bookAndShow';
    });

    String status =
        (_selectedOption == 'Instant' || _selectedOption == 'Schedule')
            ? 'PARKED'
            : 'COMPLETED';

    DateTime now = DateTime.now();
    String approvedDate = '';
    String approvedTime = '';
    String parkingDate = '';
    String parkingTime = '';
    String amount = '';
    String subscriptionEndDate = '';

    if (_selectedOption == 'Subscription') {
      amount = _selectedAmountForBooking(vehicleType);

      try {
        DateTime subscriptionDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse(subscriptionDateTimeController.text);
        approvedDate = DateFormat("dd-MM-yyyy").format(subscriptionDateTime);
        approvedTime = DateFormat("hh:mm a").format(subscriptionDateTime);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
        subscriptionEndDate = _computeSubscriptionEndDate(
          subscriptionDateTimeController.text,
        );
      } catch (e) {
        _showError('Invalid subscription date and time format');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else if (_selectedOption == 'Instant' || _selectedOption == 'Schedule') {
      amount = _selectedAmountForBooking(vehicleType);

      if (_selectedOption == 'Instant') {
        approvedDate = DateFormat("dd-MM-yyyy").format(now);
        approvedTime = DateFormat("hh:mm a").format(now);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
      } else if (_selectedOption == 'Schedule') {
        try {
          DateTime scheduleDateTime = DateFormat(
            "dd-MM-yyyy hh:mm a",
          ).parse(dateeTimeController.text);
          parkingDate = DateFormat("dd-MM-yyyy").format(scheduleDateTime);
          parkingTime = DateFormat("hh:mm a").format(scheduleDateTime);
        } catch (e) {
          _showError('Invalid schedule date and time format');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    double appliedValetAmount = 0.0;
    if (_valetEnabled && _isValetSelected && _isValetChargeApplicable()) {
      double valetAmount = _getValetChargeAmount();
      if (valetAmount > 0) {
        appliedValetAmount = valetAmount;
      }
    }

    final String stsSnapshot = _stsForBookingRequest();
    final String combinedVehicleNumber = _getCombinedVehicleNumber();
    final String personName = nameController.text;
    final String mobileNumber = mobileController.text;

    final data = {
      'carType': CartypeController.text,
      'personName': personName,
      'mobileNumber': mobileNumber,
      'vehicleNumber': combinedVehicleNumber,
      'vendorName': _vendor?.vendorName ?? '',
      'sts': stsSnapshot,
      'bookingDate': DateFormat("dd-MM-yyyy").format(now),
      'vendorId': widget.vendorid,
      'amount': amount,
      'hour': "",
      'status': status,
      'vehicleType': vehicleType,
      'parkingDate': parkingDate,
      'parkingTime': parkingTime,
      'bookingTime': DateFormat("hh:mm a").format(now),
      'cancelledStatus': "",
      'subsctiptiontype': _selectedSubscriptionType ?? '',
      'approvedDate': approvedDate,
      'approvedTime': approvedTime,
      'parkedDate': approvedDate,
      'subsctiptionenddate': subscriptionEndDate,
      'parkedTime': approvedTime,
      'tenditivecheckout': checkout.text,
      'paymentType': _paymentType,
      'paymentMode': _paymentMode,
      'bookType': isHourly ? 'Hourly' : '24 Hours',
      'valetToken': _valetTokenController.text,
      'valetLocation': _valetLocationController.text,
      'valetDriverId': _selectedValetDriverId ?? '',
      'isValet': _valetEnabled && _isValetSelected && _isValetUIApplicable(),
      'valetCharge':
          (_valetEnabled && _isValetSelected && _isValetChargeApplicable())
              ? _getValetChargeAmount().toString()
              : "0",
    };

    try {
      final response = await _sendBookingRequest(data);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          _showError('Invalid server response');
          return;
        }
        final Map<String, dynamic> responseBody = Map<String, dynamic>.from(
          decoded,
        );
        if (responseBody['message'] == 'Booking created successfully') {
          // Immediately dismiss button loading spinner so digital ticket opens instantly (~0.15s)
          setState(() {
            _isLoading = false;
            _activeLoadingButton = '';
          });

          final String bookingId = responseBody['bookingId']?.toString() ?? '';
          final String invoiceId =
              UniversalPrintHelper.extractInvoiceIdFromJson(responseBody);
          final String vendorName = _vendor?.vendorName ?? '';
          final String receiptAmount = _amountFromResponse(
            responseBody,
            amount,
          );
          final bool instantReceipt =
              _selectedOption == 'Instant' &&
              (vehicleType == 'Car' ||
                  vehicleType == 'Bike' ||
                  vehicleType == 'Others' ||
                  vehicleType == 'other' ||
                  vehicleType == 'Other') &&
              _selectedPass == null &&
              isHourly;

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentType != 'On Exit' &&
              _paymentMode == 'Online' &&
              upiUri is String &&
              upiUri.trim().isNotEmpty) {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => UpiPaymentQrPage(
                      title: 'UPI Payment',
                      upiUri: upiUri.trim(),
                      amount: upiAmount,
                      vendorName: vendorName,
                    ),
              ),
            );
          }

          if (!mounted) return;
          final List<String> capturedPhotoPaths =
              _vehicleImages.map((f) => f.path).toList();
          await _showTicketDialog(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: combinedVehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: receiptAmount,
            personName: personName,
            mobileNumber: mobileNumber,
            receiptSts: stsSnapshot,
            appliedValetAmount: appliedValetAmount,
            instantParkingReceipt: instantReceipt,
            vehicleImages: capturedPhotoPaths,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parking successfully registered!')),
          );

          _resetFields();
          _preWarmHttpConnection();
        } else {
          _showError('${responseBody['message']}');
        }
      } else {
        String errMsg = 'Failed to register parking. Please try again.';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errBody['error'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        if (response.statusCode == 413) {
          errMsg = 'Image too large. Please try with fewer or smaller images.';
        }
        _showError(errMsg);
      }
    } catch (e) {
      print('Exception occurred: $e');
      _showError('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeLoadingButton = '';
        });
      }
    }
  }

  Widget _buildTicketInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double labelFontSize = 12,
    double valueFontSize = 12,
    EdgeInsetsGeometry? padding,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: labelFontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: (isBold && labelFontSize > 12)
                  ? Colors.black87
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: valueFontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTicketDialog({
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
    String? receiptSts,
    double appliedValetAmount = 0.0,
    bool instantParkingReceipt = false,
    List<String> vehicleImages = const [],
    bool isPrintAndExit = false,
    String? exitDate,
    String? exitTime,
  }) async {
    final String displayId =
        (invoiceId != null && invoiceId.isNotEmpty) ? invoiceId : bookingId;
    final String snap = (receiptSts ?? '').trim().toLowerCase();
    final int? passHours =
        snap.isNotEmpty ? _passHoursFromSts(snap) : _selectedPass;
    final bool isPass = passHours != null;
    final bool isSubscription =
        snap == 'weekly' ||
        snap == '15day' ||
        snap == 'monthly' ||
        _selectedOption == 'Subscription';

    String planLabel = '';
    if (isPass) {
      planLabel = passHours == 24 ? 'Full Day Pass' : '$passHours Hr Pass';
    } else if (isSubscription) {
      if (snap == 'weekly') {
        planLabel = 'Weekly Subscription';
      } else if (snap == '15day') {
        planLabel = '15 Days Subscription';
      } else {
        planLabel = 'Monthly Subscription';
      }
    } else if (!isHourly) {
      planLabel = '24 Hours';
    } else {
      planLabel = 'Hourly Parking';
    }

    final double baseAmt =
        double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final double totalWithValet = isPrintAndExit
        ? baseAmt
        : (baseAmt + (appliedValetAmount > 0 ? appliedValetAmount : 0.0));
    final String cleanedTotalAmt = _cleanAmountForReceipt(
      totalWithValet > 0 ? totalWithValet.toString() : amount,
    );
    final String displayAmount =
        (cleanedTotalAmt.isNotEmpty && cleanedTotalAmt != '0')
            ? '₹$cleanedTotalAmt'
            : (amount.trim().isNotEmpty && amount.trim() != '0'
                ? (amount.startsWith('₹') ? amount : '₹$amount')
                : 'Free');

    IconData vehicleIcon;
    if (vehicleType.toLowerCase().contains('bike')) {
      vehicleIcon = Icons.two_wheeler;
    } else if (vehicleType.toLowerCase().contains('car')) {
      vehicleIcon = Icons.directions_car;
    } else {
      vehicleIcon = Icons.local_shipping;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.40),
                  blurRadius: 28,
                  spreadRadius: 3,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset.zero,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPrintAndExit
                                  ? 'Exit Completed'
                                  : 'Booking Confirmed',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (vendorName.trim().isNotEmpty)
                              Text(
                                vendorName.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey.shade500,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Ticket Details Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Vehicle Number Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor().withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ColorUtils.primarycolor().withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                vehicleIcon,
                                color: ColorUtils.primarycolor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  vehicleNumber.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: ColorUtils.primarycolor(),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (vehicleImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(vehicleImages.first),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                  if (vehicleImages.length > 1)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '+${vehicleImages.length} photos',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Booking ID
                        _buildTicketInfoRow('Token / ID', displayId),
                        const Divider(height: 12),

                        // Vehicle Type
                        _buildTicketInfoRow('Vehicle Type', vehicleType),
                        const Divider(height: 12),

                        // Date & Time
                        _buildTicketInfoRow(
                          'Parked At',
                          '$parkingDate, $parkingTime',
                        ),
                        const Divider(height: 12),

                        if (isPrintAndExit &&
                            exitDate != null &&
                            exitDate.isNotEmpty) ...[
                          _buildTicketInfoRow(
                            'Exit At',
                            '$exitDate${(exitTime != null && exitTime.isNotEmpty) ? ', $exitTime' : ''}',
                          ),
                          const Divider(height: 12),
                        ],
                        // Plan
                        _buildTicketInfoRow('Plan', planLabel),

                        const Divider(height: 12),

                        // Total Amount (including valet if applicable)
                        if (isPrintAndExit) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.12),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      displayAmount,
                                      style: GoogleFonts.poppins(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildTicketInfoRow(
                            'Total Amount',
                            displayAmount,
                            valueColor: Colors.green.shade700,
                            isBold: true,
                          ),
                        ],
                        if (personName.trim().isNotEmpty) ...[
                          const Divider(height: 12),
                          _buildTicketInfoRow('Customer', personName.trim()),
                        ],

                        if (mobileNumber.trim().isNotEmpty) ...[
                          const Divider(height: 12),
                          _buildTicketInfoRow('Mobile', mobileNumber.trim()),
                        ],
                      ],
                    ),
                  ),

                  // QR Code (suppressed on Print and Exit as the vehicle is already exiting)
                  if (!isPrintAndExit && bookingId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: PrettyQrView.data(
                            data: bookingId,
                            errorCorrectLevel: QrErrorCorrectLevel.M,
                            decoration: PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(
                                color: ColorUtils.primarycolor(),
                              ),
                              background: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons: Print Ticket & Done
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Printing ticket...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            await _printTicket(
                              vendorName: vendorName,
                              bookingId: bookingId,
                              invoiceId: invoiceId,
                              vehicleType: vehicleType,
                              vehicleNumber: vehicleNumber,
                              parkingDate: parkingDate,
                              parkingTime: parkingTime,
                              amount: amount,
                              personName: personName,
                              mobileNumber: mobileNumber,
                              includeDuration: isPrintAndExit,
                              receiptSts: receiptSts,
                              instantParkingReceipt: instantParkingReceipt,
                              isPrintAndExit: isPrintAndExit,
                              valetChargeAmount: isPrintAndExit
                                  ? null
                                  : (appliedValetAmount > 0
                                      ? appliedValetAmount
                                      : null),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: Text(
                            'Print',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ColorUtils.primarycolor(),
                            side: BorderSide(color: ColorUtils.primarycolor()),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primarycolor(),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
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
      ),
    );
  },
    );
  }

  static const String _printerTroubleshootMsg =
      'Printer unavailable. Check: (1) Device is Sunmi with built-in printer, '
      '(2) Enable Mobile Printer in Settings > Local Services, (3) Restart app after enabling.';

  String _vehicleTypeSymbol(String vehicleType) {
    final t = vehicleType.toUpperCase();
    if (t.contains('CAR')) return '[C]';
    if (t.contains('BIKE')) return '[B]';
    return '[O]';
  }

  /// Charge ID for entry/print amount by vehicle: Car=A, Bike=E, Others=I (per getchargesdata API).
  String _amountByChargeIdForVehicle(String vehicleType) {
    final String chargeId =
        vehicleType.toUpperCase().contains('CAR')
            ? 'A'
            : vehicleType.toUpperCase().contains('BIKE')
            ? 'E'
            : 'I';
    try {
      final charge = charges.firstWhere(
        (c) => c.chargeid.toUpperCase() == chargeId,
        orElse:
            () => ParkingCharge(
              category: vehicleType,
              type: '',
              amount: '0',
              id: '',
              chargeid: '',
            ),
      );
      return charge.amount;
    } catch (_) {
      return '0';
    }
  }

  /// Extracts amount from vendor create-booking API response (booking or top-level).
  String _amountFromResponse(
    Map<String, dynamic> responseBody,
    String fallbackAmount,
  ) {
    final booking = responseBody['booking'];
    if (booking != null && booking is Map<String, dynamic>) {
      final fromBooking =
          booking['totalamout'] ?? booking['totalAmount'] ?? booking['amount'];
      if (fromBooking != null) {
        final s = fromBooking.toString().trim();
        if (s.isNotEmpty && s != '0' && s != '0.0' && s != '0.00') return s;
      }
    }
    final fromRoot =
        responseBody['totalamout'] ??
        responseBody['totalAmount'] ??
        responseBody['amount'] ??
        responseBody['recievableamount'];
    if (fromRoot != null) {
      final s = fromRoot.toString().trim();
      if (s.isNotEmpty && s != '0' && s != '0.0' && s != '0.00') return s;
    }
    return fallbackAmount;
  }

  String _cleanAmountForReceipt(String amount) {
    final v = double.tryParse(amount.toString().trim());
    if (v == null) return amount;
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\\.00$'), '');
  }

  String _currentVehicleTypeForPricing() {
    switch (_selectedIndex) {
      case 0:
        return 'Car';
      case 1:
        return 'Bike';
      case 2:
        return 'Others';
      default:
        return 'Car';
    }
  }

  bool _categoryMatchesVehicleType(String chargeCategory, String vehicleType) {
    final cc = chargeCategory.trim().toLowerCase();
    final vt = vehicleType.trim().toLowerCase();
    if (cc == vt) return true;
    // Backend might use "Other" vs "Others".
    if (vt == 'others' && cc == 'other') return true;
    if (vt == 'other' && cc == 'others') return true;
    return false;
  }

  List<Map<String, dynamic>> _getHourlySlabEntriesForVehicle(
    String vehicleType,
  ) {
    final slabRe = RegExp(
      r'^0\s*(?:to|-)\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
      caseSensitive: false,
    );
    final slabs = <Map<String, dynamic>>[];
    for (final c in charges) {
      if (!_categoryMatchesVehicleType(c.category, vehicleType)) continue;
      final t = c.type.toString().trim();
      final m = slabRe.firstMatch(t);
      if (m == null) continue;
      final endHour = int.tryParse(m.group(1) ?? '');
      if (endHour == null || endHour <= 0) continue;
      slabs.add({'endHour': endHour, 'amount': c.amount.toString()});
    }
    slabs.sort((a, b) => (a['endHour'] as int).compareTo(b['endHour'] as int));
    return slabs;
  }

  String? _getAdditionalPerHourAmountForVehicle(String vehicleType) {
    double? additionalPerHourRate;

    // If backend already provides "Additional per hour", use it directly.
    try {
      final perHour = charges.firstWhere(
        (c) =>
            _categoryMatchesVehicleType(c.category, vehicleType) &&
            c.type.toLowerCase().contains('additional') &&
            c.type.toLowerCase().contains('per hour'),
      );
      additionalPerHourRate = double.tryParse(perHour.amount.toString().trim());
    } catch (_) {}

    // Fallback: use any additional charge amount as-is (no per-hour conversion).
    if (additionalPerHourRate == null) {
      try {
        final anyAdditional = charges.firstWhere(
          (c) =>
              _categoryMatchesVehicleType(c.category, vehicleType) &&
              c.type.toLowerCase().contains('additional'),
        );
        additionalPerHourRate = double.tryParse(
          anyAdditional.amount.toString().trim(),
        );
      } catch (_) {}
    }

    if (additionalPerHourRate == null) return null;
    return _cleanAmountForReceipt(additionalPerHourRate.toString());
  }

  String? _getChargeAmountByTypePattern(
    String vehicleType,
    RegExp typePattern,
  ) {
    try {
      final match = charges.firstWhere(
        (c) =>
            _categoryMatchesVehicleType(c.category, vehicleType) &&
            typePattern.hasMatch(c.type.trim()),
      );
      return _cleanAmountForReceipt(match.amount.toString());
    } catch (_) {
      return null;
    }
  }

  String? _getFullDayAmountForVehicle(String vehicleType) {
    return _getChargeAmountByTypePattern(
      vehicleType,
      RegExp(r'^full\s*day$|full\s*day', caseSensitive: false),
    );
  }

  String? _getPassAmountForVehicle(String vehicleType, int hours) {
    final include1 = RegExp(
      r'\b' + hours.toString() + r'\b.*(?:hour|hours|hr|hrs)\b',
      caseSensitive: false,
    );
    final include2 = RegExp(
      r'(?:hour|hours|hr|hrs)\b.*\b' + hours.toString() + r'\b',
      caseSensitive: false,
    );
    final exclude = RegExp(
      r'^(?:0\s*(?:to|-)\s*\d+)|additional',
      caseSensitive: false,
    );

    try {
      final match = charges.firstWhere((c) {
        if (!_categoryMatchesVehicleType(c.category, vehicleType)) return false;
        final t = c.type.trim();
        if (exclude.hasMatch(t)) return false;
        return include1.hasMatch(t) || include2.hasMatch(t);
      });
      return _cleanAmountForReceipt(match.amount.toString());
    } catch (_) {
      return null;
    }
  }

  bool _isWeeklySubscriptionSelected() {
    return (_selectedOption == 'Subscription') &&
        (dropdownValue == "Weekly Subscription");
  }

  bool _isValetUIApplicable() {
    return _currentVehicleTypeForPricing() == 'Car';
  }

  bool _isValetChargeApplicable() {
    return _isValetUIApplicable() &&
        _selectedPass == null &&
        _selectedOption != 'Subscription';
  }

  bool _is15DaySubscriptionSelected() {
    return (_selectedOption == 'Subscription') &&
        (dropdownValue == "15 Days Subscription");
  }

  bool _isMonthlySubscriptionSelected() {
    return (_selectedOption == 'Subscription') &&
        (dropdownValue == "Monthly Subscription");
  }

  /// Single source of truth for request `amount` across all actions.
  /// - Instant + pass selected: uses pass amount (12/24/48/72).
  /// - Instant/Schedule (no pass): uses chargeId fallback (A/E/I).
  /// - Subscription: uses Weekly/Monthly based on dropdown selection.
  String _selectedAmountForBooking(String vehicleType) {
    if (_selectedOption == 'Subscription') {
      final weekly = _getChargeAmountByTypePattern(
        vehicleType,
        RegExp(r'weekly', caseSensitive: false),
      );
      final day15 = _getChargeAmountByTypePattern(
        vehicleType,
        RegExp(r'15.?days?', caseSensitive: false),
      );
      final monthly = _getChargeAmountByTypePattern(
        vehicleType,
        RegExp(r'^monthly$|monthly', caseSensitive: false),
      );

      final picked =
          _isWeeklySubscriptionSelected()
              ? weekly
              : _is15DaySubscriptionSelected()
              ? day15
              : _isMonthlySubscriptionSelected()
              ? monthly
              : (monthly ?? day15 ?? weekly);
      return (picked == null || picked.trim().isEmpty) ? '0' : picked;
    }

    if (_selectedOption == 'Instant' && _selectedPass != null) {
      if (_selectedPass == 24) {
        // 24h pass uses the Full Day charge from the charges list.
        final fullDayAmt = _getFullDayAmountForVehicle(vehicleType);
        if (fullDayAmt != null &&
            fullDayAmt.trim().isNotEmpty &&
            fullDayAmt != '0')
          return fullDayAmt;
      }
      final passAmt = _getPassAmountForVehicle(vehicleType, _selectedPass!);
      if (passAmt != null && passAmt.trim().isNotEmpty) return passAmt;
    }

    // Default for Instant/Schedule (and any other flow): keep legacy chargeId amount.
    return _amountByChargeIdForVehicle(vehicleType);
  }

  String? _buildUpiQrUri() {
    final upiId = (_vendorUpiId ?? '').trim();
    if (upiId.isEmpty) return null;
    final carType = CartypeController.text.trim();
    String vehicleType;
    if (carType.toLowerCase().contains('car')) {
      vehicleType = 'Car';
    } else if (carType.toLowerCase().contains('bike')) {
      vehicleType = 'Bike';
    } else if (carType.isNotEmpty) {
      vehicleType = 'Others';
    } else {
      vehicleType = 'Car';
    }
    final amount = _selectedAmountForBooking(vehicleType);
    final name = Uri.encodeComponent((_vendorName ?? '').trim());
    final tn = Uri.encodeComponent('ParkMyWheels Parking');
    return 'upi://pay?pa=$upiId&pn=$name&am=$amount&cu=INR&tn=$tn';
  }

  Widget _buildInlineUpiQr() {
    final uri = _buildUpiQrUri();
    if (uri == null) return const SizedBox.shrink();
    final carType = CartypeController.text.trim();
    String vehicleType =
        carType.toLowerCase().contains('car')
            ? 'Car'
            : carType.toLowerCase().contains('bike')
            ? 'Bike'
            : carType.isNotEmpty
            ? 'Others'
            : 'Car';
    final amount = _selectedAmountForBooking(vehicleType);
    return Column(
      children: [
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.primarycolor(), width: 1),
          ),
          child: Column(
            children: [
              Text(
                'Scan to Pay via UPI',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.primarycolor(),
                ),
              ),
              if ((_vendorName ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    (_vendorName ?? '').trim(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),
              if (amount.isNotEmpty && amount != '0')
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    'Amount: ₹$amount',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                )
              else
                const SizedBox(height: 5),
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: PrettyQrView.data(
                    data: uri,
                    errorCorrectLevel: QrErrorCorrectLevel.H,
                    decoration: PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: ColorUtils.primarycolor(),
                      ),
                      background: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Value sent as API field `sts` (weekly/monthly, pass hours, Instant, Schedule).
  String _stsForBookingRequest() {
    if (_selectedOption == 'Subscription') {
      if (_isWeeklySubscriptionSelected()) return 'weekly';
      if (_is15DaySubscriptionSelected()) return '15day';
      if (_isMonthlySubscriptionSelected()) return 'monthly';
      if ((dropdownValue ?? '') == 'Weekly Subscription') return 'weekly';
      if ((dropdownValue ?? '') == '15 Days Subscription') return '15day';
      if ((dropdownValue ?? '') == 'Monthly Subscription') return 'monthly';
      return 'monthly';
    }
    if (_selectedOption == 'Schedule') return 'Schedule';
    if (_selectedOption == 'Instant') {
      if (_selectedPass != null) return '${_selectedPass}hr';
      return 'Instant';
    }
    return _selectedOption ?? 'Instant';
  }

  /// Fixed hour-pass value from `sts` (e.g. `48hr`), or null if not a pass booking.
  int? _passHoursFromSts(String sts) {
    final m = RegExp(r'^(\d+)hr$', caseSensitive: false).firstMatch(sts.trim());
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  /// Computes subscription end date based on Weekly vs Monthly selection.
  /// Returns formatted `dd-MM-yyyy hh:mm a`.
  String _computeSubscriptionEndDate(String subscriptionStartText) {
    final start = DateFormat("dd-MM-yyyy hh:mm a").parse(subscriptionStartText);
    final int days =
        _isWeeklySubscriptionSelected()
            ? 7
            : _is15DaySubscriptionSelected()
            ? 15
            : 30;
    final end = start.add(Duration(days: days));
    return DateFormat("dd-MM-yyyy hh:mm a").format(end);
  }

  String? _instantCompactPricingText(String vehicleType) {
    String money(String? amt) {
      if (amt == null || amt.trim().isEmpty) return '0';
      return _cleanAmountForReceipt(amt);
    }

    final slabEntries = _getHourlySlabEntriesForVehicle(vehicleType);
    final additionalPerHour = _getAdditionalPerHourAmountForVehicle(
      vehicleType,
    );

    Map<String, dynamic>? chosenSlab;
    if (slabEntries.isNotEmpty) {
      // Prefer 0-2 if present, else first available.
      chosenSlab = slabEntries.firstWhere(
        (e) => (e['endHour'] as int?) == 2,
        orElse: () => slabEntries.first,
      );
    }

    final slabText =
        chosenSlab == null
            ? null
            : '0-${chosenSlab['endHour']} : ${money(chosenSlab['amount']?.toString())}';
    final addText =
        additionalPerHour == null ? null : '${money(additionalPerHour)}+';

    if (slabText != null && addText != null) return '$slabText  |  $addText';
    if (slabText != null) return slabText;
    if (addText != null) return addText;
    return null;
  }

  Widget _buildPricingSummaryPanel() {
    final vehicleType = _currentVehicleTypeForPricing();
    final weekly = _getChargeAmountByTypePattern(
      vehicleType,
      RegExp(r'weekly', caseSensitive: false),
    );
    final day15 = _getChargeAmountByTypePattern(
      vehicleType,
      RegExp(r'15.?days?', caseSensitive: false),
    );
    final monthly = _getChargeAmountByTypePattern(
      vehicleType,
      RegExp(r'^monthly$|monthly', caseSensitive: false),
    );
    final fullDay = _getFullDayAmountForVehicle(vehicleType);

    final bool showInstantDetails = _selectedOption == 'Instant';
    final slabEntries =
        showInstantDetails
            ? _getHourlySlabEntriesForVehicle(vehicleType)
            : const <Map<String, dynamic>>[];
    final additionalPerHour =
        showInstantDetails
            ? _getAdditionalPerHourAmountForVehicle(vehicleType)
            : null;
    final pass12 =
        showInstantDetails ? _getPassAmountForVehicle(vehicleType, 12) : null;
    final pass24 =
        showInstantDetails ? _getPassAmountForVehicle(vehicleType, 24) : null;
    final pass48 =
        showInstantDetails ? _getPassAmountForVehicle(vehicleType, 48) : null;
    final pass72 =
        showInstantDetails ? _getPassAmountForVehicle(vehicleType, 72) : null;

    final bool hasAnything =
        (showInstantDetails &&
            (slabEntries.isNotEmpty ||
                additionalPerHour != null ||
                pass12 != null ||
                pass24 != null ||
                pass48 != null ||
                pass72 != null)) ||
        ((_selectedOption == 'Subscription') &&
            (weekly != null || day15 != null || monthly != null)) ||
        weekly != null ||
        day15 != null ||
        monthly != null;
    if (!hasAnything) return const SizedBox.shrink();

    String money(String? amt) {
      if (amt == null || amt.trim().isEmpty) return '0';
      return _cleanAmountForReceipt(amt);
    }

    final baseStyle = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      height: 1.1,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    // Build one compact line like screenshot: "0-2 : 50 | 20+"
    String? compactText;
    if (showInstantDetails) {
      Map<String, dynamic>? chosenSlab;
      if (slabEntries.isNotEmpty) {
        // Prefer 0-2 if present (matches screenshot), else first available.
        chosenSlab = slabEntries.firstWhere(
          (e) => (e['endHour'] as int?) == 2,
          orElse: () => slabEntries.first,
        );
      }
      final slabText =
          chosenSlab == null
              ? null
              : '0-${chosenSlab['endHour']} : ${money(chosenSlab['amount']?.toString())}';
      final addText =
          additionalPerHour == null ? null : '${money(additionalPerHour)}+';

      if (slabText != null && addText != null) {
        compactText = '$slabText  |  $addText';
      } else if (slabText != null) {
        compactText = slabText;
      } else if (addText != null) {
        compactText = addText;
      }

      // Requirement: even in Instant, show Monthly amount in this same place.
      if (monthly != null) {
        compactText =
            (compactText == null || compactText.trim().isEmpty)
                ? 'Monthly : ${money(monthly)}'
                : '$compactText   Monthly : ${money(monthly)}';
      }
    } else if (_selectedOption == 'Subscription') {
      if (dropdownValue == "Weekly Subscription" && weekly != null) {
        compactText = 'Weekly : ${money(weekly)}';
      } else if (dropdownValue == "15 Days Subscription" && day15 != null) {
        compactText = '15 Days : ${money(day15)}';
      } else if (dropdownValue == "Monthly Subscription" && monthly != null) {
        compactText = 'Monthly : ${money(monthly)}';
      } else if (weekly != null || day15 != null || monthly != null) {
        compactText =
            'Weekly : ${money(weekly)}   15 Days : ${money(day15)}   Monthly : ${money(monthly)}';
      }
    }

    if (compactText == null || compactText.trim().isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(compactText, style: boldStyle),
      ),
    );
  }

  /// Builds receipt lines like:
  /// `0 to 4 hours : Rs. 80`
  /// `Additional per hour: Rs. 20`
  List<String> _getHourlyPricingSlabLinesForVehicle(String vehicleType) {
    if (!isHourly) return const [];
    final vt = vehicleType.trim();
    final vtNorm = vt.toLowerCase();

    bool categoryMatches(String chargeCategory) {
      final cc = chargeCategory.trim().toLowerCase();
      if (cc == vtNorm) return true;
      // Backend might use "Other" vs "Others".
      if (vtNorm == 'others' && cc == 'other') return true;
      if (vtNorm == 'other' && cc == 'others') return true;
      return false;
    }

    ParkingCharge? baseCharge;

    // Pick the "0 to X hours" slab with the largest hour window (the configured minimum period).
    {
      final slabRe = RegExp(
        r'^0\s*(?:to|-)\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
        caseSensitive: false,
      );
      int? bestHours;
      for (final c in charges) {
        if (!categoryMatches(c.category)) continue;
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

    ParkingCharge? additionalCharge;

    // Prefer explicit "Additional per hour" charge.
    try {
      additionalCharge = charges.firstWhere(
        (c) =>
            categoryMatches(c.category) &&
            c.type.toLowerCase().contains('additional') &&
            c.type.toLowerCase().contains('per hour'),
      );
    } catch (_) {}

    // Otherwise pick the largest "Additional X hour(s)" slab (matches the configured block).
    if (additionalCharge == null) {
      final candidates =
          charges.where((c) {
            return categoryMatches(c.category) &&
                RegExp(
                  r'additional\s*(\d+)\s*(?:hour|hours|hr|hrs)\b',
                  caseSensitive: false,
                ).hasMatch(c.type);
          }).toList();

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
          additionalCharge = c;
        }
      }

      if (additionalCharge == null) {
        try {
          additionalCharge = charges.firstWhere(
            (c) =>
                categoryMatches(c.category) &&
                c.type.toLowerCase().contains('additional'),
          );
        } catch (_) {}
      }
    }

    final lines = <String>[];
    if (baseCharge != null) {
      lines.add(
        '${baseCharge.type.trim()} : Rs. ${_cleanAmountForReceipt(baseCharge.amount)}',
      );
    }
    if (additionalCharge != null) {
      lines.add(
        '${additionalCharge.type.trim()} : Rs. ${_cleanAmountForReceipt(additionalCharge.amount)}',
      );
    }
    return lines;
  }

  Future<void> _doPrint({
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
    String? receiptSts,
    bool instantParkingReceipt = false,
    bool isPrintAndExit = false,
    double? valetChargeAmount,
    String? operationalTimings,
  }) async {
    final displayId = UniversalPrintHelper.formatReceiptBookingId(invoiceId);
    final vehicleLine =
        '${_vehicleTypeSymbol(vehicleType)} $vehicleType | $vehicleNumber';
    final hasName = personName.trim().isNotEmpty;
    final hasMobile = mobileNumber.trim().isNotEmpty;

    // Increased top spacing to prevent clipping first letter
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      '$vendorName',
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

    // Prefer `receiptSts` captured with the booking request so the slip matches what was
    // sent to the API (avoids hourly slabs if UI `_selectedPass` drifts after UPI, valet focus, etc.).
    final String snap = (receiptSts ?? '').trim().toLowerCase();
    final int? passHoursFromSnap =
        snap.isNotEmpty ? _passHoursFromSts(snap) : null;
    final bool isPass =
        passHoursFromSnap != null ||
        (receiptSts == null &&
            _selectedOption == 'Instant' &&
            _selectedPass != null);
    final int? passHoursForReceipt =
        passHoursFromSnap ??
        ((receiptSts == null && _selectedOption == 'Instant')
            ? _selectedPass
            : null);

    final bool isSubscription =
        (snap == 'weekly' || snap == '15day' || snap == 'monthly') ||
        (receiptSts == null && _selectedOption == 'Subscription');

    double finalAmt = double.tryParse(amount.toString().trim()) ?? 0.0;
    if (!isPrintAndExit && valetChargeAmount != null && valetChargeAmount > 0) {
      finalAmt += valetChargeAmount;
    }
    final cleanedAmt = _cleanAmountForReceipt(finalAmt.toString());

    if (isPass && passHoursForReceipt != null) {
      // Pass booking (12hr / 24hr / 48hr / 72hr)
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        final label =
            passHoursForReceipt == 24
                ? 'Full Day'
                : '$passHoursForReceipt Hour';
        await SunmiPrinter.printText('$label Pass');
        await SunmiPrinter.lineWrap(1);
        for (final line in UniversalPrintHelper.formatBoxedLines('Parking Amount : Rs. $cleanedAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(fontSize: 26, align: SunmiPrintAlign.CENTER, bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else if (isSubscription) {
      // Subscription: label from snapshot sts when available
      String label;
      if (snap == 'weekly' ||
          (receiptSts == null && _isWeeklySubscriptionSelected())) {
        label = 'Weekly';
      } else if (snap == '15day' ||
          (receiptSts == null && _is15DaySubscriptionSelected())) {
        label = '15 Days';
      } else {
        label = 'Monthly';
      }
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        for (final line in UniversalPrintHelper.formatBoxedLines('$label : Rs. $cleanedAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(fontSize: 26, align: SunmiPrintAlign.CENTER, bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else if (!isHourly) {
      // 24-hour (full day) mode
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        for (final line in UniversalPrintHelper.formatBoxedLines('Full Day : Rs. $cleanedAmt')) {
          await SunmiPrinter.printText(
            line,
            style: SunmiTextStyle(fontSize: 26, align: SunmiPrintAlign.CENTER, bold: true),
          );
          await SunmiPrinter.lineWrap(1);
        }
      }
    } else {
      // Hourly, no pass
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        if (!instantParkingReceipt || isPrintAndExit) {
          for (final line in UniversalPrintHelper.formatBoxedLines('Parking Amount : Rs. $cleanedAmt')) {
            await SunmiPrinter.printText(
              line,
              style: SunmiTextStyle(fontSize: 26, align: SunmiPrintAlign.CENTER, bold: true),
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

    if (!isPrintAndExit &&
        operationalTimings != null &&
        operationalTimings.isNotEmpty) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Timings : $operationalTimings');
    }

    if (!isPrintAndExit) {
      await SunmiPrinter.printText(
        'we are not responsible for any belongings inside and outside of the vehicle.',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);
    }
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

  double _getValetChargeAmount() {
    if (_valetChargeSetting > 0) {
      print('FOUND VALET CHARGE FROM SETTINGS: $_valetChargeSetting');
      return _valetChargeSetting;
    }

    try {
      print('--- ALL CONFIGURED CHARGES ---');
      for (var c in charges) {
        print('Category: ${c.category}, Type: ${c.type}, Amount: ${c.amount}');
      }
      final valetCharge = charges.firstWhere((c) {
        final cat = c.category.toLowerCase();
        final type = c.type.toLowerCase();
        return cat.contains('valet') ||
            type.contains('valet') ||
            cat.contains('valte') ||
            type.contains('valte') ||
            cat.contains('vale') ||
            type.contains('vale');
      });
      print('FOUND VALET CHARGE IN CHARGES LIST: ${valetCharge.amount}');
      return double.tryParse(valetCharge.amount.toString()) ?? 0.0;
    } catch (_) {
      print('NO VALET CHARGE FOUND');
      return 0.0;
    }
  }

  // Function to print ticket
  Future<void> _printTicket({
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
    bool includeDuration = true,
    String? receiptSts,
    bool instantParkingReceipt = false,
    bool isPrintAndExit = false,
    double? valetChargeAmount,
    String? operationalTimings,
  }) async {
    if (!Platform.isAndroid) {
      _showError(_printerTroubleshootMsg);
      return;
    }
    try {
      final String resolvedInvoiceId =
          await UniversalPrintHelper.resolveInvoiceIdForPrint(
            invoiceId: invoiceId,
            bookingId: bookingId,
          );
      final String? printInvoiceId =
          resolvedInvoiceId.isNotEmpty ? resolvedInvoiceId : null;

      String? printOperationalTimings =
          operationalTimings ?? _cachedOperationalTimings;
      if (printOperationalTimings == null) {
        try {
          final response = await http
              .get(
                Uri.parse(
                  '${ApiConfig.baseUrl}vendor/fetchbusinesshours/${widget.vendorid}',
                ),
              )
              .timeout(const Duration(seconds: 1));
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

                printOperationalTimings =
                    '${formatTime(todayTiming['openTime'])} to ${formatTime(todayTiming['closeTime'])}';
                _cachedOperationalTimings = printOperationalTimings;
              }
            }
          }
        } catch (_) {}
      }

      final String printerType = await UniversalPrintHelper.detectPrinterType(
        fast: true,
      );

      if (printerType == 'pinelabs_builtin') {
        await PineLabsPrintHelper.printTicket(
          vendorName: vendorName,
          bookingId: bookingId,
          invoiceId: printInvoiceId,
          vehicleType: vehicleType,
          vehicleNumber: vehicleNumber,
          parkingDate: parkingDate,
          parkingTime: parkingTime,
          amount: amount,
          personName: personName,
          mobileNumber: mobileNumber,
          duration: '',
          bookType: isHourly ? 'Hourly' : '24 Hours',
          isEntryReceipt: !isPrintAndExit,
        );
        return;
      }

      if (printerType == 'sunmi' || printerType == 'sumi') {
        await _doPrint(
          vendorName: vendorName,
          bookingId: bookingId,
          invoiceId: printInvoiceId,
          vehicleType: vehicleType,
          vehicleNumber: vehicleNumber,
          parkingDate: parkingDate,
          parkingTime: parkingTime,
          amount: amount,
          personName: personName,
          mobileNumber: mobileNumber,
          receiptSts: receiptSts,
          instantParkingReceipt: instantParkingReceipt,
          isPrintAndExit: isPrintAndExit,
          valetChargeAmount: isPrintAndExit ? null : valetChargeAmount,
          operationalTimings: printOperationalTimings,
        );
        return;
      }

      if (printerType == 'bluetooth') {
        final bool connected =
            await UniversalPrintHelper.connectBluetoothPrinter();
        if (!connected) {
          _showError(_printerTroubleshootMsg);
          return;
        }
        await UniversalPrintHelper.printWithESCPOS(
          vendorId: widget.vendorid,
          vendorName: vendorName,
          bookingId: bookingId,
          invoiceId: printInvoiceId,
          vehicleType: vehicleType,
          vehicleNumber: vehicleNumber,
          parkingDate: parkingDate,
          parkingTime: parkingTime,
          amount: amount,
          personName: personName,
          mobileNumber: mobileNumber,
          includeDuration: includeDuration,
          isEntryReceipt: !isPrintAndExit,
          sts: receiptSts ?? _stsForBookingRequest(),
          bookType: isHourly ? 'Hourly' : '24 Hours',
          skipChargeLookup: true,
          slabLinesOverride: _getHourlyPricingSlabLinesForVehicle(vehicleType),
          instantParkingReceipt: instantParkingReceipt,
          isPrintAndExit: isPrintAndExit,
          valetCharge: isPrintAndExit ? null : valetChargeAmount,
          operationalTimings: printOperationalTimings,
        );
        return;
      }

      _showError(_printerTroubleshootMsg);
    } catch (e) {
      print('Exception in print: $e');
      _showError(_printerTroubleshootMsg);
    }
  }

  Future<void> _payNowAndPrint() async {
    String vehicleType = cate[_selectedIndex];
    String amountStr = '';

    if (_selectedOption == 'Instant' || _selectedOption == 'Pass') {
      amountStr = _selectedAmountForBooking(vehicleType);
    } else {
      amountStr = _selectedAmountForBooking(vehicleType);
    }

    if (amountStr.isEmpty || amountStr == "Amount not found") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid amount. Cannot process payment.'),
        ),
      );
      return;
    }

    // Clean amount (remove anything that's not a digit or period)
    amountStr = amountStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final double baseAmt = double.tryParse(amountStr) ?? 0.0;
    double appliedValetAmount = 0.0;
    if (_valetEnabled && _isValetSelected && _isValetChargeApplicable()) {
      double valetAmount = _getValetChargeAmount();
      if (valetAmount > 0) {
        appliedValetAmount = valetAmount;
      }
    }
    final double totalCharge = baseAmt + appliedValetAmount;
    int amountInPaise = (totalCharge * 100).toInt();

    setState(() {
      _isLoading = true;
      _activeLoadingButton = 'payNow';
    });

    try {
      // Transaction JSON Payload required by PineLabs MasterApp
      Map<String, dynamic> payload = {
        "Detail": {
          "BillingRefNo": "PMW_${DateTime.now().millisecondsSinceEpoch}",
          "PaymentAmount":
              amountInPaise, // Amount in Paise as expected by configured terminal
          "TransactionType": _pinelabsPaymentMethod == 'UPI' ? 5120 : 4001,
        },
        "Header": {
          "ApplicationId": "94378c89faa6482eb98b4941ff5e6d2c",
          "MethodId": "1001",
          "UserId": "user1234",
          "VersionNo": "1.0",
        },
      };
      String transactionData = jsonEncode(payload);

      // Check PineLabs Device
      bool isPineLabs = await PlutusSmart.isPineLabsDevice();
      if (!isPineLabs) {
        _showError('PineLabs payment app not found');
        return;
      }

      // Trigger transaction
      String result = await PlutusSmart.startTransaction(transactionData);

      setState(() {
        _isLoading = false;
        _activeLoadingButton = '';
      });

      String responseCode = "";
      String responseMessage = result;

      try {
        Map<String, dynamic> responseData = jsonDecode(result);
        if (responseData.containsKey('Response')) {
          responseCode =
              responseData['Response']['ResponseCode']?.toString() ?? "";
          responseMessage =
              responseData['Response']['ResponseMsg']?.toString() ??
              responseData['Response']['ResponseMessage']?.toString() ??
              result;
        } else if (responseData.containsKey('Detail')) {
          responseCode =
              responseData['Detail']['ResponseCode']?.toString() ?? "";
          responseMessage =
              responseData['Detail']['ResponseMessage']?.toString() ?? result;
        }
      } catch (e) {
        // Not a JSON string
      }

      if (responseCode == "00") {
        // Indicates success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PineLabs Payment Successful!')),
        );
        // Automatically print and create booking on backend
        await _printAndExit();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Failed: $responseMessage')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _activeLoadingButton = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error initiating payment: $e')));
    }
  }

  // Function to print ticket and exit
  Future<void> _printAndExit() async {
    // Determine vehicle type
    String vehicleType;
    switch (_selectedIndex) {
      case 0:
        vehicleType = 'Car';
        break;
      case 1:
        vehicleType = 'Bike';
        break;
      case 2:
        vehicleType = 'Others';
        break;
      default:
        vehicleType = 'Unknown';
    }

    // Check available slots (skip when offline and slots not loaded)
    bool _isOnlineForSlots = _isDeviceOnline;
    if (_availableSlots != null) {
      int available = 0;
      if (vehicleType == 'Car') {
        available = _availableSlots!['Cars'] ?? 0;
      } else if (vehicleType == 'Bike') {
        available = _availableSlots!['Bikes'] ?? 0;
      } else {
        available = _availableSlots!['Others'] ?? 0;
      }

      if (available <= 0 && _isOnlineForSlots) {
        _showError(
          'No space available for $vehicleType. Please try another vehicle type or check back later.',
        );
        return;
      }
    } else if (_isOnlineForSlots) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

    // Validation for empty fields
    if (carController.text.isEmpty) {
      _showError('Please enter vehicle number');
      return;
    }

    if (_selectedOption == 'Subscription' &&
        subscriptionDateTimeController.text.isEmpty) {
      _showError('Please select a parking date and time for the subscription');
      return;
    }

    if (_selectedOption == 'Schedule' && dateeTimeController.text.isEmpty) {
      _showError(
        'Please select a parking date and time for the scheduled booking',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeLoadingButton = 'printAndExit';
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/vendorcreatebooking');
    String status =
        'COMPLETED'; // Always set status as COMPLETED for print and exit

    DateTime now = DateTime.now();
    // Get current date/time (device should be set to India timezone)
    String exitDate = DateFormat("dd-MM-yyyy").format(now);
    String exitTime = DateFormat("hh:mm a").format(now);

    String approvedDate = '';
    String approvedTime = '';
    String parkingDate = '';
    String parkingTime = '';
    String amount = '';
    String subscriptionEndDate = '';

    if (_selectedOption == 'Subscription') {
      amount = _selectedAmountForBooking(vehicleType);

      try {
        DateTime subscriptionDateTime = DateFormat(
          "dd-MM-yyyy hh:mm a",
        ).parse(subscriptionDateTimeController.text);
        approvedDate = DateFormat("dd-MM-yyyy").format(subscriptionDateTime);
        approvedTime = DateFormat("hh:mm a").format(subscriptionDateTime);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
        subscriptionEndDate = _computeSubscriptionEndDate(
          subscriptionDateTimeController.text,
        );
      } catch (e) {
        _showError('Invalid subscription date and time format');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else if (_selectedOption == 'Instant' || _selectedOption == 'Schedule') {
      amount = _selectedAmountForBooking(vehicleType);

      if (_selectedOption == 'Instant') {
        approvedDate = DateFormat("dd-MM-yyyy").format(now);
        approvedTime = DateFormat("hh:mm a").format(now);
        parkingDate = approvedDate;
        parkingTime = approvedTime;
      } else if (_selectedOption == 'Schedule') {
        try {
          DateTime scheduleDateTime = DateFormat(
            "dd-MM-yyyy hh:mm a",
          ).parse(dateeTimeController.text);
          parkingDate = DateFormat("dd-MM-yyyy").format(scheduleDateTime);
          parkingTime = DateFormat("hh:mm a").format(scheduleDateTime);
        } catch (e) {
          _showError('Invalid schedule date and time format');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    double appliedValetAmount = 0.0;
    if (_valetEnabled && _isValetSelected && _isValetChargeApplicable()) {
      double valetAmount = _getValetChargeAmount();
      if (valetAmount > 0) {
        appliedValetAmount = valetAmount;
      }
    }

    // In Print & Exit, the vehicle exits immediately upon registration.
    // The final exit total must include the base parking charge plus any valet charge.
    final double baseAmt =
        double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final double finalExitTotal = baseAmt + appliedValetAmount;
    final String finalExitTotalStr = finalExitTotal > 0
        ? (finalExitTotal == finalExitTotal.roundToDouble()
            ? finalExitTotal.round().toString()
            : finalExitTotal.toStringAsFixed(2))
        : amount;

    final String stsSnapshot = _stsForBookingRequest();
    final data = {
      'carType': CartypeController.text,
      'personName': nameController.text,
      'mobileNumber': mobileController.text,
      'vehicleNumber': _getCombinedVehicleNumber(),
      'vendorName': _vendor?.vendorName ?? '',
      'sts': stsSnapshot,
      'bookingDate': DateFormat("dd-MM-yyyy").format(now),
      'vendorId': widget.vendorid,
      'amount': finalExitTotalStr,
      'totalamout': finalExitTotalStr,
      'hour': "00:01:00",
      'status': status,
      'vehicleType': vehicleType,
      'parkingDate': parkingDate,
      'parkingTime': parkingTime,
      'bookingTime': DateFormat("hh:mm a").format(now),
      'cancelledStatus': "",
      'subsctiptiontype': _selectedSubscriptionType ?? '',
      'approvedDate': approvedDate,
      'approvedTime': approvedTime,
      'parkedDate': approvedDate,
      'subsctiptionenddate': subscriptionEndDate,
      'parkedTime': approvedTime,
      'bookType': isHourly ? 'Hourly' : '24 Hours',
      'exitvehicledate': exitDate,
      'exitvehicletime': exitTime,
      'paymentMode': _paymentMode,
      'paymentType': _paymentType,
      'valetToken': _valetTokenController.text,
      'valetLocation': _valetLocationController.text,
      'valetDriverId': _selectedValetDriverId ?? '',
      'isValet': _valetEnabled && _isValetSelected && _isValetUIApplicable(),
      'valetCharge':
          (_valetEnabled && _isValetSelected && _isValetChargeApplicable())
              ? _getValetChargeAmount().toString()
              : "0",
    };

    try {
      final response = await _sendBookingRequest(data);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          _showError('Invalid server response');
          return;
        }
        final Map<String, dynamic> responseBody = Map<String, dynamic>.from(
          decoded,
        );
        if (responseBody['message'] == 'Booking created successfully') {
          final String bookingId = responseBody['bookingId']?.toString() ?? '';
          final String invoiceId =
              UniversalPrintHelper.extractInvoiceIdFromJson(responseBody);
          final String vendorName = _vendor?.vendorName ?? '';
          final String receiptAmount = _amountFromResponse(
            responseBody,
            amount,
          );
          final bool instantReceipt =
              _selectedOption == 'Instant' &&
              (vehicleType == 'Car' ||
                  vehicleType == 'Bike' ||
                  vehicleType == 'Others' ||
                  vehicleType == 'other' ||
                  vehicleType == 'Other') &&
              _selectedPass == null &&
              isHourly;

          final String printVehicleNumber = _getCombinedVehicleNumber();
          final String printPersonName = nameController.text;
          final String printMobileNumber = mobileController.text;
          final List<String> capturedPhotoPaths =
              _vehicleImages.map((f) => f.path).toList();

          final String printTotalAmt = finalExitTotalStr;

          // Clear loading spinner
          setState(() {
            _isLoading = false;
            _activeLoadingButton = '';
          });

          // Non-blocking thermal print: hardware prints in background without stalling UI
          unawaited(_printTicket(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: printVehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: printTotalAmt,
            personName: printPersonName,
            mobileNumber: printMobileNumber,
            includeDuration: false,
            receiptSts: stsSnapshot,
            instantParkingReceipt: instantReceipt,
            isPrintAndExit: true,
            valetChargeAmount: null,
          ));

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentType != 'On Exit' &&
              _paymentMode == 'Online' &&
              upiUri is String &&
              upiUri.trim().isNotEmpty) {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => UpiPaymentQrPage(
                      title: 'UPI Payment',
                      upiUri: upiUri.trim(),
                      amount: upiAmount,
                      vendorName: vendorName,
                    ),
              ),
            );
          }

          if (!mounted) return;
          // Show pop-up on display with booking and exit details and total amount
          await _showTicketDialog(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: printVehicleNumber,
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: printTotalAmt,
            personName: printPersonName,
            mobileNumber: printMobileNumber,
            receiptSts: stsSnapshot,
            appliedValetAmount: 0.0,
            instantParkingReceipt: instantReceipt,
            vehicleImages: capturedPhotoPaths,
            isPrintAndExit: true,
            exitDate: exitDate,
            exitTime: exitTime,
          );

          if (!mounted) return;
          if (bookingId.isNotEmpty) {
            GlobalRecentExits.exitedBookingIds.add(bookingId);
            await LocalDbService.markBookingCompletedOffline(
              bookingId,
              amount: finalExitTotal,
              paymentMode: _paymentMode,
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Parking successfully registered, printed, and marked as completed!',
              ),
              duration: Duration(seconds: 2),
            ),
          );

          _resetFields();
          _preWarmHttpConnection();
        } else {
          _showError('${responseBody['message']}');
        }
      } else {
        String errMsg = 'Failed to register parking. Please try again.';
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errBody['error'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        if (response.statusCode == 413) {
          errMsg = 'Image too large. Please try with fewer or smaller images.';
        }
        _showError(errMsg);
      }
    } catch (e) {
      print('Exception occurred: $e');
      _showError('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _activeLoadingButton = '';
      });
    }
  }

  bool showSubscriptionOptions =
      false; // Track whether to show subscription options
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _httpClient.close();
    // Cancel the timer when the widget is disposed to avoid memory leaks
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ParkingCharge> carEntries =
        charges.where((charge) => charge.category == 'Car').toList();
    List<ParkingCharge> bikeentries =
        charges.where((charge) => charge.category == 'Bike').toList();
    List<ParkingCharge> others =
        charges.where((charge) => charge.category == 'Others').toList();

    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : WillPopScope(
          onWillPop: () async {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (context) => vendordashScreen(vendorid: widget.vendorid),
              ),
              (Route<dynamic> route) => false,
            );
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(60.0),
              child: Container(
                decoration: const BoxDecoration(),
                child: AppBar(
                  titleSpacing: 0,
                  backgroundColor: ColorUtils.secondarycolor(),
                  title: Text(
                    'New Booking',
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                  iconTheme: const IconThemeData(color: Colors.black),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  vendordashScreen(vendorid: widget.vendorid),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => qrcodeallowpark(
                                  vendorid: widget.vendorid,
                                  isFromNewBooking: true,
                                ),
                          ),
                        );
                      },
                      icon: Icon(Icons.qr_code_scanner, color: Colors.green),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    vSearchScreen(vendorid: widget.vendorid),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.search,
                        color: ColorUtils.primarycolor(),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Use the `infoRow` widget somewhere in your UI
                        showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  5.0,
                                ), // Circular border
                              ),
                              child: SingleChildScrollView(
                                // Make the dialog content scrollable
                                child: infoRow(
                                  context: context,
                                  carEntries: carEntries,
                                  bikeEntries: bikeentries,
                                  otherEntries: others,
                                  title: "Price Charts",
                                  value: "",
                                  icon: Icons.currency_rupee,
                                  iconCheck: true,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: Icon(
                        Icons.info_outline,
                        color: ColorUtils.primarycolor(),
                      ), // Set the icon here
                    ),
                    const SizedBox(width: 15),
                  ],
                ),
              ),
            ),
            body: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _carFocusNode.unfocus();
                  FocusScope.of(context).unfocus();
                  SystemChannels.textInput.invokeMethod('TextInput.hide');
                },
                child: SingleChildScrollView(
                  child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Vehicle Toggles and Valet Checkbox
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildVehicleToggleItem(
                                    0,
                                    Icons.directions_car,
                                    "Car",
                                    isDisabled:
                                        !(_enabledSettings['carEnabled'] ??
                                            true),
                                  ),
                                  _buildVehicleToggleItem(
                                    1,
                                    Icons.two_wheeler,
                                    "Bike",
                                    isDisabled:
                                        !(_enabledSettings['bikeEnabled'] ??
                                            true),
                                  ),
                                  _buildVehicleToggleItem(
                                    2,
                                    Icons.settings,
                                    "Others",
                                    isDisabled:
                                        !(_enabledSettings['othersEnabled'] ??
                                            true),
                                  ),
                                ],
                              ),
                              if (_isValetUIApplicable())
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _isValetSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          _isValetSelected = val ?? false;
                                          _valetEnabled = _isValetSelected;
                                        });
                                        _updateValetGlobalState(
                                          _isValetSelected,
                                        );
                                      },
                                      activeColor: ColorUtils.primarycolor(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text(
                                      "Valet",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          // Captured vehicle picture preview between Top Row and Input Row
                          if (_vehicleImages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 130,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _vehicleImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (_) => Dialog(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    insetPadding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: Stack(
                                                      alignment:
                                                          Alignment.topRight,
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          child: Image.file(
                                                            _vehicleImages[index],
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 8,
                                                          right: 8,
                                                          child: GestureDetector(
                                                            onTap:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    6,
                                                                  ),
                                                              decoration: const BoxDecoration(
                                                                color:
                                                                    Colors
                                                                        .black54,
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                              ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                            );
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    ColorUtils.primarycolor(),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              child: Image.file(
                                                _vehicleImages[index],
                                                width:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width -
                                                    30,
                                                height: 130,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap:
                                                () =>
                                                    _removeVehicleImage(index),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade600,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.35),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else
                            const SizedBox(height: 10),
                          // Input Fields Row
                          Row(
                            children: [
                              if (_isValetSelected && _isValetUIApplicable())
                                Expanded(
                                  flex: 2,
                                  child: _buildLabelAboveField(
                                    label: 'Valet Token',
                                    child: _buildSmallField(
                                      _valetTokenController,
                                      _valetTokenFocusNode,
                                      'Token',
                                      borderRadius: BorderRadius.circular(8),
                                      keyboardType: TextInputType.number,
                                      enabled: _isValetSelected,
                                    ),
                                  ),
                                ),
                              if (_isValetSelected && _isValetUIApplicable())
                                const SizedBox(width: 5),
                              Expanded(
                                flex: 3,
                                child: _buildLabelAboveField(
                                  label: 'Enter Vehicle No *',
                                  labelColor: Colors.grey,
                                  child: _buildSmallField(
                                    carController,
                                    _carFocusNode,
                                    'Vehicle No',
                                    isRequired: true,
                                    autofocus: false,
                                    borderRadius: BorderRadius.circular(8),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [UpperCaseTextFormatter()],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              _buildCameraIconButton(),
                              if (_isValetSelected && _isValetUIApplicable())
                                const SizedBox(width: 5),
                              if (_isValetSelected && _isValetUIApplicable())
                                Expanded(
                                  flex: 3,
                                  child: _buildLabelAboveField(
                                    label: 'Parking Location',
                                    child: _buildSmallField(
                                      _valetLocationController,
                                      _valetLocationFocusNode,
                                      'Location',
                                      borderRadius: BorderRadius.circular(8),
                                      enabled: _isValetSelected,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Builder(
                        builder: (context) {
                          final vehicleTypeForPricing =
                              _currentVehicleTypeForPricing();
                          final weeklyAmtStr = _cleanAmountForReceipt(
                            _getChargeAmountByTypePattern(
                                  vehicleTypeForPricing,
                                  RegExp(r"weekly", caseSensitive: false),
                                ) ??
                                "0",
                          );
                          final day15AmtStr = _cleanAmountForReceipt(
                            _getChargeAmountByTypePattern(
                                  vehicleTypeForPricing,
                                  RegExp(r"15.?days?", caseSensitive: false),
                                ) ??
                                "0",
                          );
                          final monthlyAmtStr = _cleanAmountForReceipt(
                            _getChargeAmountByTypePattern(
                                  vehicleTypeForPricing,
                                  RegExp(
                                    r"^monthly$|monthly",
                                    caseSensitive: false,
                                  ),
                                ) ??
                                "0",
                          );

                          final isInstantDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}Temporary'] ??
                                  true);
                          final isWeeklyDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}Weekly'] ??
                                  false);
                          final is15DayDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}15Day'] ??
                                  false);
                          final isMonthlyDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}Monthly'] ??
                                  false);

                          return Row(
                            children: [
                              _buildModeButton(
                                "Instant\nParking",
                                _selectedOption == 'Instant' &&
                                    _selectedPass == null,
                                () {
                                  setState(() {
                                    _selectedOption = 'Instant';
                                    isHourly = true;
                                    _selectedPass =
                                        null; // Always clear pass when standard Instant is chosen
                                    dateTimeController.text =
                                        _getFormattedCurrentDateTime();
                                  });
                                },
                                bottomText:
                                    _instantCompactPricingText(
                                      _currentVehicleTypeForPricing(),
                                    ) ??
                                    '',
                                isDisabled: isInstantDisabled,
                              ),
                              const SizedBox(width: 8),
                              _buildModeButton(
                                "Weekly\nPass",
                                _selectedOption == 'Subscription' &&
                                    dropdownValue == "Weekly Subscription",
                                () {
                                  setState(() {
                                    _selectedOption = 'Subscription';
                                    dropdownValue = "Weekly Subscription";
                                    _selectedPass = null;
                                    dateTimeController.clear();
                                    subscriptionDateTimeController.clear();
                                  });
                                },
                                bottomText: '₹$weeklyAmtStr',
                                isDisabled: isWeeklyDisabled,
                              ),
                              const SizedBox(width: 8),
                              _buildModeButton(
                                "15 Days\nPass",
                                _selectedOption == 'Subscription' &&
                                    dropdownValue == "15 Days Subscription",
                                () {
                                  setState(() {
                                    _selectedOption = 'Subscription';
                                    dropdownValue = "15 Days Subscription";
                                    _selectedPass = null;
                                    dateTimeController.clear();
                                    subscriptionDateTimeController.clear();
                                  });
                                },
                                bottomText: '₹$day15AmtStr',
                                isDisabled: is15DayDisabled,
                              ),
                              const SizedBox(width: 8),
                              _buildModeButton(
                                "Monthly\nSubscription",
                                _selectedOption == 'Subscription' &&
                                    dropdownValue == "Monthly Subscription",
                                () {
                                  setState(() {
                                    _selectedOption = 'Subscription';
                                    dropdownValue = "Monthly Subscription";
                                    _selectedPass = null;
                                    dateTimeController.clear();
                                    subscriptionDateTimeController.clear();
                                  });
                                },
                                bottomText: '₹$monthlyAmtStr',
                                isDisabled: isMonthlyDisabled,
                              ),
                            ],
                          );
                        },
                      ),
                      // Keep legacy panel available but hidden (amounts now live under each button).
                      Offstage(
                        offstage: true,
                        child: _buildPricingSummaryPanel(),
                      ),
                      const SizedBox(height: 15),
                      // Show amount on each pass button (12/24/48/72).
                      Builder(
                        builder: (context) {
                          final vehicleTypeForPricing =
                              _currentVehicleTypeForPricing();
                          final hr12AmtStr = _cleanAmountForReceipt(
                            _getPassAmountForVehicle(
                                  vehicleTypeForPricing,
                                  12,
                                ) ??
                                '0',
                          );
                          final hr24AmtStr = _cleanAmountForReceipt(
                            _getFullDayAmountForVehicle(
                                  vehicleTypeForPricing,
                                ) ??
                                '0',
                          );
                          final hr48AmtStr = _cleanAmountForReceipt(
                            _getPassAmountForVehicle(
                                  vehicleTypeForPricing,
                                  48,
                                ) ??
                                '0',
                          );
                          final hr72AmtStr = _cleanAmountForReceipt(
                            _getPassAmountForVehicle(
                                  vehicleTypeForPricing,
                                  72,
                                ) ??
                                '0',
                          );

                          final is12hDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}12h'] ??
                                  false);
                          final is24hDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}FullDay'] ??
                                  false);
                          final is48hDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}48h'] ??
                                  false);
                          final is72hDisabled =
                              !(_enabledSettings['${vehicleTypeForPricing.toLowerCase()}72h'] ??
                                  false);

                          return Row(
                            children: [
                              _buildPassButton(
                                12,
                                _selectedPass == 12,
                                () => _handlePassSelection(12),
                                bottomText: '₹$hr12AmtStr',
                                isDisabled: is12hDisabled,
                              ),
                              const SizedBox(width: 5),
                              _buildPassButton(
                                24,
                                _selectedPass == 24,
                                () => _handlePassSelection(24),
                                topText: "Full Day",
                                bottomText: '₹$hr24AmtStr',
                                isDisabled: is24hDisabled,
                              ),
                              const SizedBox(width: 5),
                              _buildPassButton(
                                48,
                                _selectedPass == 48,
                                () => _handlePassSelection(48),
                                bottomText: '₹$hr48AmtStr',
                                isDisabled: is48hDisabled,
                              ),
                              const SizedBox(width: 5),
                              _buildPassButton(
                                72,
                                _selectedPass == 72,
                                () => _handlePassSelection(72),
                                bottomText: '₹$hr72AmtStr',
                                isDisabled: is72hDisabled,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _buildActionButton(
                            "Book Now",
                            Icons.check_circle,
                            ColorUtils.primarycolor(),
                            _registerParking,
                            isDisabled: !_bookEnabled,
                            isLoading:
                                _isLoading && _activeLoadingButton == 'bookNow',
                          ),
                          if (_printEnabled) ...[
                            const SizedBox(width: 8),
                            _buildActionButton(
                              "Book and Print",
                              Icons.print,
                              ColorUtils.primarycolor(),
                              _bookAndPrint,
                              isDisabled: !_bookEnabled,
                              isLoading:
                                  _isLoading &&
                                  _activeLoadingButton == 'bookAndPrint',
                            ),
                          ],
                        ],
                      ),
                      if (_exitEnabled || _bookAndShowEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_exitEnabled)
                              _buildActionButton(
                                (_isPineLabsEnabled && _paymentMode == 'Online')
                                    ? "Pay Now"
                                    : "Print and Exit",
                                (_isPineLabsEnabled && _paymentMode == 'Online')
                                    ? Icons.payment
                                    : Icons.exit_to_app,
                                ColorUtils.primarycolor(),
                                (_isPineLabsEnabled && _paymentMode == 'Online')
                                    ? _payNowAndPrint
                                    : _printAndExit,
                                isDisabled: !_bookEnabled,
                                isLoading:
                                    _isLoading &&
                                    (_activeLoadingButton == 'printAndExit' ||
                                        _activeLoadingButton == 'payNow'),
                              ),
                            if (_exitEnabled && _bookAndShowEnabled)
                              const SizedBox(width: 8),
                            if (_bookAndShowEnabled)
                              _buildActionButton(
                                "Book and Show",
                                Icons.qr_code_2,
                                ColorUtils.primarycolor(),
                                _bookAndShow,
                                isDisabled: !_bookEnabled,
                                isLoading:
                                    _isLoading &&
                                    _activeLoadingButton == 'bookAndShow',
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 15),
                      // Compact Date/Time Picker with grey background for Instant, white for others
                      _selectedOption == 'Instant'
                          ? greyfield(
                            labelColor: customTeal,
                            selectedColor: customTeal,
                            controller: dateTimeController,
                            focusNode: _dateTimeFocusNode,
                            keyboard: TextInputType.text,
                            obscure: false,
                            textInputAction: TextInputAction.done,
                            inputFormatter: const [],
                            label: 'Select Parking Date & Time',
                            hint: 'Select Parking Date & Time',
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: customTeal,
                              size: 14,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: customTeal,
                                size: 20,
                              ),
                            ),
                            readOnly: true,
                            onTap: null, // Not editable for Instant
                          )
                          : CusTextField(
                            labelColor: customTeal,
                            selectedColor: customTeal,
                            controller: dateTimeController,
                            focusNode: _dateTimeFocusNode,
                            keyboard: TextInputType.text,
                            obscure: false,
                            textInputAction: TextInputAction.done,
                            inputFormatter: const [],
                            label: 'Select Parking Date & Time',
                            hint: 'Select Parking Date & Time',
                            prefixIcon: Icon(
                              Icons.calendar_today,
                              color: customTeal,
                              size: 14,
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: customTeal,
                                size: 20,
                              ),
                            ),
                            readOnly: true,
                            onTap: () async {
                              _showDateTimePicker();
                            },
                          ),

                      // const SizedBox(height: 20),
                      // _buildSectionHeader("Payment Selection"),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Payment Type",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _buildRadioOption(
                                      "On Entry",
                                      _paymentType == "On Entry",
                                      (v) => setState(() => _paymentType = v!),
                                      fontSize: 9,
                                    ),
                                    _buildRadioOption(
                                      "On Exit",
                                      _paymentType == "On Exit",
                                      (v) => setState(() => _paymentType = v!),
                                      fontSize: 9,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_paymentType != "On Exit")
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Payment Mode",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      _buildRadioOption(
                                        "Online",
                                        _paymentMode == "Online",
                                        (v) => setState(() => _paymentMode = v!),
                                      ),
                                      _buildRadioOption(
                                        "Cash",
                                        _paymentMode == "Cash",
                                        (v) => setState(() => _paymentMode = v!),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (_paymentType != "On Exit") ...[
                        const SizedBox(height: 15),

                        if (_isPineLabsEnabled && _paymentMode == 'Online') ...[
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "PineLabs Payment Method",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        _buildRadioOption(
                                          "Card",
                                          _pinelabsPaymentMethod == "Card",
                                          (v) => setState(
                                            () => _pinelabsPaymentMethod = v!,
                                          ),
                                        ),
                                        _buildRadioOption(
                                          "UPI",
                                          _pinelabsPaymentMethod == "UPI",
                                          (v) => setState(
                                            () => _pinelabsPaymentMethod = v!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                        ],

                        if (_paymentMode == 'Online') _buildInlineUpiQr(),
                      ],
                      const SizedBox(height: 10),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _showOptionalInfo,
                              activeColor: ColorUtils.primarycolor(),
                              onChanged:
                                  (val) =>
                                      setState(() => _showOptionalInfo = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap:
                                () => setState(
                                  () => _showOptionalInfo = !_showOptionalInfo,
                                ),
                            child: Text(
                              "Optional Information",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      if (_showOptionalInfo) ...[
                        const SizedBox(height: 15),
                        CusTextField(
                          labelColor: customTeal,
                          selectedColor: customTeal,
                          controller: checkout,
                          focusNode: _checkout,
                          keyboard: TextInputType.text,
                          obscure: false,
                          textInputAction: TextInputAction.next,
                          inputFormatter: const [],
                          label: 'Tentative checkout date & time',
                          hint: 'Tentative checkout date & time',
                          prefixIcon: Icon(
                            Icons.timer,
                            color: customTeal,
                            size: 14,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: customTeal,
                              size: 20,
                            ),
                          ),
                          readOnly: true,
                          onTap: _tenditivecheckout,
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildLabelAboveField(
                                label: 'Car Type',
                                child: _buildSmallField(
                                  CartypeController,
                                  _CartypeFocusNode,
                                  'Model',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildLabelAboveField(
                                label: 'Person name',
                                child: _buildSmallField(
                                  nameController,
                                  _nameFocusNode,
                                  'Name',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildLabelAboveField(
                                label: 'Mobile number',
                                child: _buildSmallField(
                                  mobileController,
                                  _mobileFocusNode,
                                  'Mobile',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (_valetEnabled)
                          _buildLabelAboveField(
                            label: 'Select Valet Driver',
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return DropdownMenu<String>(
                                  key: ValueKey(_valetDropdownKey),
                                  initialSelection: _selectedValetDriverId,
                                  width: constraints.maxWidth,
                                  menuHeight: 250,
                                  hintText: 'Select Driver',
                                  textStyle: GoogleFonts.poppins(fontSize: 12),
                                  inputDecorationTheme: InputDecorationTheme(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: ColorUtils.primarycolor(),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  dropdownMenuEntries:
                                      _valetDrivers.map((driver) {
                                        final firstName =
                                            driver['firstName']?.toString() ??
                                            '';
                                        final lastName =
                                            driver['lastName']?.toString() ??
                                            '';
                                        final fullName =
                                            '$firstName $lastName'.trim();

                                        return DropdownMenuEntry<String>(
                                          value:
                                              driver['_id']?.toString() ??
                                              driver['id']?.toString() ??
                                              '',
                                          label:
                                              fullName.isNotEmpty
                                                  ? fullName
                                                  : 'Unknown Driver',
                                          style: MenuItemButton.styleFrom(
                                            textStyle: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                  onSelected: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedValetDriverId = value;
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 15),
                        // Vehicle images - capture from camera (only for Instant parking, when Vehicle Upload is ON)
                        if (_selectedOption == 'Instant' &&
                            _vehicleUploadEnabled) ...[
                          Container(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Add Vehicle Image",
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _captureVehicleImage,
                            child: CustomPaint(
                              painter: DashedBorderPainter(
                                color: Colors.grey.shade400,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                width: double.infinity,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/svg/upload.svg',
                                      height: 60,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Tap to capture",
                                          style: GoogleFonts.poppins(
                                            color: ColorUtils.primarycolor(),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "JPG, PNG up to 5MB",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],

                        if (_vehicleImages.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _vehicleImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _vehicleImages[index],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap:
                                              () => _removeVehicleImage(index),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade600,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget infoRow({
    required BuildContext context,
    required List<ParkingCharge> carEntries,
    required List<ParkingCharge> bikeEntries,
    required List<ParkingCharge> otherEntries,
    required String title,
    required String value,
    required IconData icon,
    bool iconCheck = false,
  }) {
    // Combine the lists into a single list for grid display
    List<ParkingCharge> allEntries = [
      ...carEntries,
      ...bikeEntries,
      ...otherEntries,
    ];

    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: ColorUtils.secondarycolor(),
        borderRadius: BorderRadius.circular(
          5.0,
        ), // Full border radius applied here
        border: Border.all(
          color: ColorUtils.primarycolor(), // Border color
          width: 1, // Border thickness
        ),
      ),
      // color: ColorUtils.secondarycolor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          // Title and Icon Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ColorUtils.primarycolor()),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 0),

          // GridView to display the charges in a grid format
          Container(
            child: GridView.builder(
              shrinkWrap:
                  true, // Make the GridView take up only the necessary space
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Number of columns in the grid
                childAspectRatio: 1.3, // Aspect ratio of each card
              ),
              itemCount: allEntries.length,
              itemBuilder: (context, index) {
                final entry = allEntries[index];
                return Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      5.0,
                    ), // Optional: rounded corners
                    side: BorderSide(
                      color: ColorUtils.primarycolor(), // Color of the outline
                      width: 0.5, // Thickness of the outline
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.0), // Reduced padding
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.category,
                          style: GoogleFonts.poppins(
                            fontSize: 12, // Font size for category
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // SizedBox(height: 3),
                        Text(
                          entry.type,
                          style: GoogleFonts.poppins(
                            fontSize: 7, // Font size for type
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // SizedBox(height: 3), // Space between type and amount
                        Text(
                          '₹${entry.amount}',
                          style: GoogleFonts.poppins(
                            fontSize: 10, // Font size for amount
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---

  String _getCombinedVehicleNumber() {
    String vehicleNo = carController.text.trim();
    if (_valetEnabled) {
      String token = _valetTokenController.text.trim();
      String location = _valetLocationController.text.trim();
      final parts = <String>[];
      if (token.isNotEmpty) parts.add(token);
      if (vehicleNo.isNotEmpty) parts.add(vehicleNo);
      if (location.isNotEmpty) parts.add(location);
      return parts.join('-');
    }
    return vehicleNo;
  }

  void _handlePassSelection(int hours) {
    setState(() {
      _selectedOption = 'Instant'; // Switch to Instant mode
      isHourly = true;
      _selectedPass = hours;
      // Pre-fill checkout time based on current time + hours
      DateTime checkoutTime = DateTime.now().add(Duration(hours: hours));
      checkout.text = _formatDateTime(checkoutTime);
      dateTimeController.text = _getFormattedCurrentDateTime();
    });
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildRadioOption(
    String label,
    bool isSelected,
    Function(String?) onChanged, {
    double fontSize = 10,
  }) {
    return GestureDetector(
      onTap: () => onChanged(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ColorUtils.primarycolor() : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? ColorUtils.primarycolor() : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleToggleItem(
    int index,
    IconData icon,
    String label, {
    bool isDisabled = false,
  }) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: isDisabled ? null : () => setState(() => _selectedIndex = index),
      child: Container(
        width: 70,
        height: 35,
        decoration: BoxDecoration(
          color:
              isDisabled
                  ? Colors.grey.shade100
                  : (isSelected
                      ? ColorUtils.primarycolor().withOpacity(0.1)
                      : Colors.white),
          border: Border.all(
            color:
                isDisabled
                    ? Colors.grey.shade200
                    : (isSelected
                        ? ColorUtils.primarycolor()
                        : Colors.grey.shade300),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(index == 0 ? 8 : 0),
            bottomLeft: Radius.circular(index == 0 ? 8 : 0),
            topRight: Radius.circular(index == 2 ? 8 : 0),
            bottomRight: Radius.circular(index == 2 ? 8 : 0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  isDisabled
                      ? Colors.grey.shade300
                      : (isSelected ? ColorUtils.primarycolor() : Colors.grey),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isDisabled
                        ? Colors.grey.shade400
                        : (isSelected
                            ? ColorUtils.primarycolor()
                            : Colors.grey),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelAboveField({
    required String label,
    required Widget child,
    Color labelColor = Colors.grey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildSmallField(
    TextEditingController controller,
    FocusNode focusNode,
    String hint, {
    bool isRequired = false,
    BorderRadius? borderRadius,
    TextInputType? keyboardType,
    bool autofocus = false,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.characters,
    Widget? suffixIcon,
    VoidCallback? onTap,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (enabled) {
              if (!focusNode.hasFocus) {
                focusNode.requestFocus();
              }
              SystemChannels.textInput.invokeMethod('TextInput.show');
              onTap?.call();
            }
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade200,
              borderRadius: borderRadius ?? BorderRadius.circular(8),
              border: Border.all(
                color: focusNode.hasFocus ? Colors.red : Colors.grey.shade300,
                width: focusNode.hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: child,
          ),
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13),
        onTap: () {
          SystemChannels.textInput.invokeMethod('TextInput.show');
          onTap?.call();
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: InputBorder.none,
          isDense: true,
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraIconButton() {
    final bool hasImages = _vehicleImages.isNotEmpty;
    return _buildLabelAboveField(
      label: 'Camera',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _captureVehicleImage,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            width: 42,
            decoration: BoxDecoration(
              color:
                  hasImages
                      ? ColorUtils.primarycolor().withOpacity(0.08)
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    hasImages
                        ? ColorUtils.primarycolor()
                        : Colors.grey.shade300,
                width: hasImages ? 1.5 : 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.camera_alt,
                  color: hasImages ? ColorUtils.primarycolor() : Colors.black87,
                  size: 20,
                ),
                if (hasImages)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: ColorUtils.primarycolor(),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '${_vehicleImages.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String title,
    bool isSelected,
    VoidCallback onTap, {
    String? bottomText,
    bool isDisabled = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isDisabled
                    ? Colors.grey.shade200
                    : (isSelected ? ColorUtils.primarycolor() : Colors.white),
            border: Border.all(
              color:
                  isDisabled
                      ? Colors.grey.shade300
                      : (isSelected
                          ? ColorUtils.primarycolor()
                          : Colors.grey.shade300),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color:
                      isDisabled
                          ? Colors.grey.shade400
                          : (isSelected ? Colors.white : Colors.black),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
              if (bottomText != null && bottomText.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    bottomText,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color:
                          isDisabled
                              ? Colors.grey.shade400
                              : (isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700),
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                      height: 1.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassButton(
    int hours,
    bool isSelected,
    VoidCallback onTap, {
    String? topText,
    String? bottomText,
    bool isDisabled = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          height: 45,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isDisabled
                    ? Colors.grey.shade200
                    : (isSelected ? ColorUtils.primarycolor() : Colors.white),
            border: Border.all(
              color:
                  isDisabled
                      ? Colors.grey.shade300
                      : (isSelected
                          ? ColorUtils.primarycolor()
                          : Colors.grey.shade300),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                topText ?? "$hours",
                style: GoogleFonts.poppins(
                  color:
                      isDisabled
                          ? Colors.grey.shade400
                          : (isSelected
                              ? Colors.white
                              : ColorUtils.primarycolor()),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.0,
                ),
              ),
              Text(
                bottomText ?? "Hours Pass",
                style: GoogleFonts.poppins(
                  color:
                      isDisabled
                          ? Colors.grey.shade400
                          : (isSelected ? Colors.white : Colors.grey.shade600),
                  fontWeight: FontWeight.w500,
                  fontSize: 8,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: (isDisabled || isLoading) ? null : onTap,
        icon:
            isLoading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              (isDisabled || isLoading) ? Colors.grey.shade300 : color,
          foregroundColor:
              (isDisabled || isLoading) ? Colors.grey.shade500 : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: (isDisabled || isLoading) ? 0 : 2,
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    var path = Path();
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ),
    );

    Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) => false;
}

class CategoryItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color customTeal;
  final bool isFirst;
  final bool isLast;

  const CategoryItem({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.customTeal,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 47,
        width: 106, // Set the width to a larger value (e.g., 150 or 120)
        // padding: EdgeInsets.symmetric(horizontal: 12.0), // Adjust padding if needed
        decoration: BoxDecoration(
          color: isSelected ? customTeal : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 5.0 : 0.0),
            bottomLeft: Radius.circular(isFirst ? 5.0 : 0.0),
            topRight: Radius.circular(isLast ? 5.0 : 0.0),
            bottomRight: Radius.circular(isLast ? 5.0 : 0.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(width: 9.0), // Adjust space between icon and title
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CusTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Widget prefixIcon;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final Function()? onTap;
  final Widget? suffixIcon;
  final Color selectedColor;
  final Color labelColor;

  const CusTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    required this.selectedColor,
    required this.labelColor,
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8.0), // Add space before icon
            child: prefixIcon,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          labelStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 12.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.5),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 20,
          ), // Adjusted to remove extra space
          suffixIconConstraints: const BoxConstraints(
            minWidth: 10,
            minHeight: 20,
          ),
        ),
        readOnly: readOnly,
        onTap: onTap,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class CuTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Widget prefixIcon;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final Function()? onTap;
  final Widget? suffixIcon;
  final Color selectedColor; // For focused border color
  final Color labelColor; // For label text color
  final bool isSelected;
  const CuTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    required this.selectedColor, // Initialize selectedColor
    required this.labelColor,
    this.isSelected = false, // Initialize labelColor
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      obscureText: obscure,
      textInputAction: textInputAction,
      inputFormatters: inputFormatter,

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8.0), // Add space before icon
          child: prefixIcon,
        ),
        suffixIcon: suffixIcon,
        filled: true, // Fill the background
        fillColor: Colors.white, // Keep background white
        labelStyle: GoogleFonts.poppins(color: Colors.red),

        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 12.0,
        ), // Set label text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(
            color: Colors.red,
          ), // Default border color
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 0.5,
          ), // Use primary color when focused
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 0.5,
          ), // Use grey for enabled state
        ),
      ),
      readOnly: readOnly,
      onTap: onTap,
      onSubmitted: onSubmitted,
    );
  }
}

class greyfield extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final bool obscure;
  final TextInputAction textInputAction;
  final List<TextInputFormatter> inputFormatter;
  final String label;
  final String hint;
  final Widget prefixIcon;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final Function()? onTap;
  final Widget? suffixIcon;
  final Color selectedColor; // For focused border color
  final Color labelColor; // For label text color

  const greyfield({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    required this.obscure,
    required this.textInputAction,
    required this.inputFormatter,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.onSubmitted,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    required this.selectedColor, // Initialize selectedColor
    required this.labelColor, // Initialize labelColor
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8.0), // Add space before icon
            child: prefixIcon,
          ),
          suffixIcon: suffixIcon,
          filled: true, // Fill the background
          fillColor:
              Colors.grey[200], // Change this to grey color for background
          labelStyle: GoogleFonts.poppins(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 12.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 20,
          ), // Adjusted to remove extra space
          suffixIconConstraints: const BoxConstraints(
            minWidth: 10,
            minHeight: 20,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.5),
          ),
        ),

        readOnly: readOnly,
        onTap: onTap,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
