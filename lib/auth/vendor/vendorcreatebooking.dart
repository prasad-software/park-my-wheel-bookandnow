import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
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
import '../customer/parking/bookparking.dart';
import 'menus/parkingchart.dart';
import 'upi_payment_qr.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'vendorsearch.dart';

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
  bool _bookEnabled = false;
  bool _printEnabled = false;
  bool _exitEnabled = false;
  bool _vehicleUploadEnabled = false;
  bool _slotViewEnabled = false;
  bool _valetEnabled = false;
  double _valetChargeSetting = 0.0;
  bool _showOptionalInfo = false;
  bool _isValetSelected = true;
  int? _selectedPass;
  String _paymentType = 'On Entry';
  String _paymentMode = 'Online';
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
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/valet-drivers/${widget.vendorid}',
        ),
      );
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
  final ImagePicker _imagePicker = ImagePicker();
  Future<void> _fetchVendorData() async {
    try {
      print('Fetching data for vendor ID: ${widget.vendorid}');

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}',
        ),
      );

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
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/availableslots/${widget.vendorid}',
        ),
      );

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

  // Fetch toggle states from backend
  Future<void> _fetchToggleStates() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}vendor/get-toggle-states/${widget.vendorid}',
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _bookEnabled =
              true; // Force enabled to recover from accidental overwrite
          _printEnabled = true; // Force enabled
          _exitEnabled = true; // Force enabled
          _vehicleUploadEnabled = true; // Force enabled
          _slotViewEnabled = true; // Force enabled
          _valetEnabled = data['valetEnabled'] ?? false;
          _valetChargeSetting =
              double.tryParse(data['valetCharge']?.toString() ?? '0') ?? 0.0;
        });

        setState(() {
          _isValetSelected = _valetEnabled;
        });

        final prefs = await SharedPreferences.getInstance();
        final savedValetCharge = prefs.getString(
          'valetCharge_${widget.vendorid}',
        );
        if (savedValetCharge != null) {
          setState(() {
            _valetChargeSetting =
                double.tryParse(savedValetCharge) ?? _valetChargeSetting;
          });
        }

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
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchenable/${widget.vendorid}'),
      );

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
      final response = await http.get(url);

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
  String _activeLoadingButton = '';
  String? _selectedSubscription;
  String? dropdownValue;
  final List<String> subscriptionOptions = [
    "Weekly Subscription",
    "15 Days Subscription",
    "Monthly Subscription",
  ];

  @override
  void initState() {
    super.initState();
    _fetchVendorData();
    _fetchAvailableSlots();
    _fetchToggleStates();
    _fetchEnabledSettings();
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
    _futureCars = ApiService().fetchCars(widget.vendorid);
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

  /// Compresses vehicle image to avoid 413 Request Entity Too Large and timeouts.
  Future<File> _compressVehicleImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.absolute.path}_compressed.jpg',
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
    );
    if (result != null) {
      final compressedFile = File(result.path);
      final length = await compressedFile.length();
      if (length > 2000000) {
        return await _compressVehicleImage(compressedFile);
      }
      return compressedFile;
    } else {
      throw Exception('Image compression failed');
    }
  }

  Future<void> _captureVehicleImage() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        try {
          final compressedFile = await _compressVehicleImage(File(photo.path));
          setState(() {
            _vehicleImages.add(compressedFile);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vehicle image added')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to process image: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
      }
    }
  }

  void _removeVehicleImage(int index) {
    setState(() {
      _vehicleImages.removeAt(index);
    });
  }

  // Helper function to format date (day, month, year) and time (hour, minute, AM/PM)
  String _formatDateTime(DateTime dateTime) {
    return DateFormat(
      "dd-MM-yyyy hh:mm a",
    ).format(dateTime); // Full date + time with AM/PM
  }

  Future<List<Car>> fetchCars(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId'),
    );

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
      final response = await http.get(Uri.parse(apiUrl));
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
      _selectedOption = 'Instant';
      _selectedPass = null;
      _selectedIndex = _defaultVehicleIndex(_defaultVehicleType);
      selectedDateTime = DateTime.now();
      _selectedValetDriverId = null;
      _valetDropdownKey++;
    });
  }

  void _registerParking() async {
    // First check if we have slot data
    if (_availableSlots == null) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

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

    // Check available slots
    int available = 0;
    if (vehicleType == 'Car') {
      available = _availableSlots!['Cars'] ?? 0;
    } else if (vehicleType == 'Bike') {
      available = _availableSlots!['Bikes'] ?? 0;
    } else {
      available = _availableSlots!['Others'] ?? 0;
    }

    if (available <= 0) {
      _showError(
        'No space available for $vehicleType. Please try another vehicle type or check back later.',
      );
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
          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentMode == 'Online' &&
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parking successfully registered!')),
          );
          _resetFields();
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
      });
    }
  }

  /// Sends booking request - uses JSON when no images, multipart when vehicle images are present.
  /// Uses machinecreatebooking for all booking flows. Vehicle images are compressed before add.
  Future<http.Response> _sendBookingRequest(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/machinecreatebooking');
    if (_vehicleImages.isEmpty) {
      return await http.post(
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
      request.files.add(
        await http.MultipartFile.fromPath(
          'vehicleImages',
          _vehicleImages[i].path,
          filename: 'vehicle_$i.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }
    var streamedResponse = await request.send();
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
    // First check if we have slot data
    if (_availableSlots == null) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

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

    // Check available slots
    int available = 0;
    if (vehicleType == 'Car') {
      available = _availableSlots!['Cars'] ?? 0;
    } else if (vehicleType == 'Bike') {
      available = _availableSlots!['Bikes'] ?? 0;
    } else {
      available = _availableSlots!['Others'] ?? 0;
    }

    if (available <= 0) {
      _showError(
        'No space available for $vehicleType. Please try another vehicle type or check back later.',
      );
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
              (vehicleType == 'Car' || vehicleType == 'Bike' || vehicleType == 'Others' || vehicleType == 'other' || vehicleType == 'Other') &&
              _selectedPass == null &&
              isHourly;

          await _printTicket(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: _getCombinedVehicleNumber(),
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: receiptAmount,
            personName: nameController.text,
            mobileNumber: mobileController.text,
            includeDuration: false,
            receiptSts: stsSnapshot,
            instantParkingReceipt: instantReceipt,
            valetChargeAmount:
                appliedValetAmount > 0 ? appliedValetAmount : null,
          );

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentMode == 'Online' &&
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking successfully registered and printed!'),
            ),
          );

          _resetFields();
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
      });
    }
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
    return _isValetUIApplicable() && _selectedPass == null;
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
    if (isPrintAndExit && valetChargeAmount != null && valetChargeAmount > 0) {
      finalAmt += valetChargeAmount;
    }
    final cleanedAmt = _cleanAmountForReceipt(finalAmt.toString());

    if (isPass && passHoursForReceipt != null) {
      // Pass booking (12hr / 24hr / 48hr / 72hr)
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        final label = passHoursForReceipt == 24 ? 'Full Day' : '$passHoursForReceipt Hour';
        await SunmiPrinter.printText('$label Pass');
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Parking Amount : Rs. $cleanedAmt');
        await SunmiPrinter.lineWrap(1);
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
        await SunmiPrinter.printText('$label : Rs. $cleanedAmt');
        await SunmiPrinter.lineWrap(1);
      }
    } else if (!isHourly) {
      // 24-hour (full day) mode
      if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        await SunmiPrinter.printText('Full Day : Rs. $cleanedAmt');
        await SunmiPrinter.lineWrap(1);
      }
    } else {
      // Hourly, no pass
      final slabLines = _getHourlyPricingSlabLinesForVehicle(vehicleType);
      if (slabLines.isNotEmpty) {
        if (instantParkingReceipt) {
          if (isPrintAndExit) {
            if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
              await SunmiPrinter.printText('Parking Amount : Rs. $cleanedAmt');
              await SunmiPrinter.lineWrap(1);
            }
          }
        } else {
          // await SunmiPrinter.printText(slabLines[0]);
          // if (slabLines.length > 1) {
          //   await SunmiPrinter.printText(slabLines[1]);
          // }
        }
      } else if (cleanedAmt.isNotEmpty && cleanedAmt != '0') {
        // Commenting out Amount as well for instant receipts if no slab lines
        if (!instantParkingReceipt || isPrintAndExit) {
          await SunmiPrinter.printText('Parking Amount : Rs. $cleanedAmt');
          await SunmiPrinter.lineWrap(1);
        }
      }
    }

    if (bookingId.isNotEmpty) {
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

    await SunmiPrinter.printText(
      'we are not responsible for any belongings inside and outside of the vehicle.',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
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

      String? operationalTimings;
      try {
        print(
          'DEBUG PRINT: Starting fetchbusinesshours for vendorid = ${widget.vendorid}',
        );
        final response = await http
            .get(
              Uri.parse(
                '${ApiConfig.baseUrl}vendor/fetchbusinesshours/${widget.vendorid}',
              ),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('DEBUG PRINT: BUSINESS HOURS DATA = $data');
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
        } else {
          print('DEBUG PRINT: API returned status code ${response.statusCode}');
        }
      } catch (e) {
        print('DEBUG PRINT: Error fetching operational timings for print: $e');
      }
      print('DEBUG PRINT: Final operationalTimings = $operationalTimings');

      final String printerType = await UniversalPrintHelper.detectPrinterType(
        fast: true,
      );

      if (printerType == 'sunmi' ||
          printerType == 'sumi' ||
          printerType == 'pinelabs_builtin') {
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
          valetChargeAmount: valetChargeAmount,
          operationalTimings: operationalTimings,
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
          isEntryReceipt: !includeDuration,
          sts: receiptSts ?? _stsForBookingRequest(),
          bookType: isHourly ? 'Hourly' : '24 Hours',
          skipChargeLookup: true,
          slabLinesOverride: _getHourlyPricingSlabLinesForVehicle(vehicleType),
          instantParkingReceipt: instantParkingReceipt,
          isPrintAndExit: isPrintAndExit,
          valetCharge: valetChargeAmount,
          operationalTimings: operationalTimings,
        );
        return;
      }

      _showError(_printerTroubleshootMsg);
    } catch (e) {
      print('Exception in print: $e');
      _showError(_printerTroubleshootMsg);
    }
  }

  // Function to print ticket and exit
  Future<void> _printAndExit() async {
    // First check if we have slot data
    if (_availableSlots == null) {
      _showError('Unable to check parking availability. Please try again.');
      return;
    }

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

    // Check available slots
    int available = 0;
    if (vehicleType == 'Car') {
      available = _availableSlots!['Cars'] ?? 0;
    } else if (vehicleType == 'Bike') {
      available = _availableSlots!['Bikes'] ?? 0;
    } else {
      available = _availableSlots!['Others'] ?? 0;
    }

    if (available <= 0) {
      _showError(
        'No space available for $vehicleType. Please try another vehicle type or check back later.',
      );
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
              (vehicleType == 'Car' || vehicleType == 'Bike' || vehicleType == 'Others' || vehicleType == 'other' || vehicleType == 'Other') &&
              _selectedPass == null &&
              isHourly;

          await _printTicket(
            vendorName: vendorName,
            bookingId: bookingId,
            invoiceId: invoiceId.isNotEmpty ? invoiceId : null,
            vehicleType: vehicleType,
            vehicleNumber: _getCombinedVehicleNumber(),
            parkingDate: parkingDate,
            parkingTime: parkingTime,
            amount: receiptAmount,
            personName: nameController.text,
            mobileNumber: mobileController.text,
            includeDuration: false,
            receiptSts: stsSnapshot,
            instantParkingReceipt: instantReceipt,
            isPrintAndExit: true,
            valetChargeAmount:
                appliedValetAmount > 0 ? appliedValetAmount : null,
          );

          final upiUri = responseBody['upi']?['uri'];
          final upiAmount = responseBody['upi']?['am']?.toString();
          if (_paymentMode == 'Online' &&
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Parking successfully registered, printed, and marked as completed!',
              ),
            ),
          );

          _resetFields();
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
      });
    }
  }

  bool showSubscriptionOptions =
      false; // Track whether to show subscription options
  @override
  void dispose() {
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
            Navigator.pop(context, _selectedIndex);
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
                      Navigator.pop(context, _selectedIndex);
                    },
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    qrcodeallowpark(vendorid: widget.vendorid),
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
                                    autofocus:
                                        true, // Enable autofocus for new booking page
                                    borderRadius: BorderRadius.circular(8),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ),
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
                            // isLoading: _isLoading && _activeLoadingButton == 'bookNow',
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            "Book and Print",
                            Icons.print,
                            ColorUtils.primarycolor(),
                            _bookAndPrint,
                            isDisabled: !(_bookEnabled && _printEnabled),
                            // isLoading: _isLoading && _activeLoadingButton == 'bookAndPrint',
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            "Print and Exit",
                            Icons.exit_to_app,
                            ColorUtils.primarycolor(),
                            _printAndExit,
                            isDisabled: !(_printEnabled && _exitEnabled),
                            // isLoading: _isLoading && _activeLoadingButton == 'printAndExit',
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 15),


                      if (_paymentMode == 'Online') _buildInlineUpiQr(),
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
                                        top: -4,
                                        right: -4,
                                        child: GestureDetector(
                                          onTap:
                                              () => _removeVehicleImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
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
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        return Container(
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
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        keyboardType: keyboardType,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: InputBorder.none,
          isDense: true,
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
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: (isDisabled || isLoading) ? Colors.grey.shade300 : color,
          foregroundColor: (isDisabled || isLoading) ? Colors.grey.shade500 : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
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
