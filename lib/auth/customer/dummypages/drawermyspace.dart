import 'dart:convert';
import 'dart:io';


import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';


import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mywheels/auth/customer/addspace.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tab_container/tab_container.dart';
import '../../vendor/editamenities.dart';
import '../../vendor/editpage/editparkingpage.dart';

import '../../vendor/editpage/editvendorprofile.dart';
import '../../vendor/menus/addamenties.dart';

import '../../vendor/menus/parkingchart.dart';

import 'myspaceeditslotchargesamenties.dart';

class myownspaces extends StatefulWidget {
  final String vendorId;

  const myownspaces({super.key, required this.vendorId});

  @override
  _MyOwnSpacesState createState() => _MyOwnSpacesState();
}

class _MyOwnSpacesState extends State<myownspaces> {
  Vendor? _vendor;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _fetchVendorData();
  }

  List<Vendor> _vendors = []; // ✅ Store all vendors instead of one

  Future<void> _fetchVendorData() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final String url =
          '${ApiConfig.baseUrl}vendor/fetchspace/${widget.vendorId}';
      print('Fetching vendor data from URL: $url');

      final response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Response data: $data');

        if (data['data'] == null || (data['data'] as List).isEmpty) {
          throw Exception('No vendor data found');
        }

        setState(() {
          _vendors =
              (data['data'] as List) // ✅ Convert List<dynamic> to List<Vendor>
                  .map((vendor) => Vendor.fromJson(vendor))
                  .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load vendor data');
      }
    } catch (error) {
      print('Error fetching vendor data: $error');

      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        title: Text(
          'My Space',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => addmyspace(vendorid: widget.vendorId),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingGif() // Show loading GIF before the Scaffold
          : _vendors.isEmpty
              ? const Center(
                  child: Text(
                    "No space details found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _vendors.length, // ✅ Loop through all vendors
                  itemBuilder: (context, index) {
                    final vendor = _vendors[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VendorDetailsPage(

                                vendorId: widget.vendorId,
                                id: vendor.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: ColorUtils.primarycolor(), width: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: vendor.image.isNotEmpty
                                      ? NetworkImage(vendor.image)
                                      : null,
                                  child: vendor.image.isEmpty
                                      ? const Icon(Icons.store,
                                          size: 30, color: Colors.black54)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vendor.vendorName,
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Address:',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[800]),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        vendor.address,
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[800]),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class VendorDetailsPage extends StatefulWidget {

  final String vendorId;
  final String id;

  const VendorDetailsPage(
      {super.key,

      required this.id,
      required this.vendorId});

  @override
  _VendorDetailsPageState createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage>
    with TickerProviderStateMixin {
  File? _selectedImage;
  TabController? _chargesController;
  bool _isLoading = false;
  Vendor? _vendor;
  bool value = false;
  final int _selecteddIndex = 2; //botom nav
  int selectedTabIndex = 0;
  int selecedIndex = 0;
  bool carTemporary = false;
  bool carFullDay = false;
  bool carMonthly = false;

  // Bike parking options
  bool bikeTemporary = false;
  bool bikeFullDay = false;
  bool bikeMonthly = false;

  // Others parking options
  bool othersTemporary = false;
  bool othersFullDay = false;
  bool othersMonthly = false;
  late List<Widget> _pagess;

  late TextEditingController _nameController;

  late TextEditingController _addresscontroller;
  late TextEditingController _landmarkcontroller;
  late TextEditingController _latitudecontroller;
  late TextEditingController _longtitudecontroller;


  late final TabController _controller;
  Future<void> _fetchVendorData() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetchspacedata?vendorId=${widget.id}')
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _nameController.text = _vendor?.vendorName ?? ''; // Set controller text
            _addresscontroller.text = _vendor?.address ?? '';
            _landmarkcontroller.text = _vendor?.landMark ?? '';
            _latitudecontroller.text = _vendor?.latitude ?? '';
            _longtitudecontroller.text = _vendor?.longitude??'';
            _isLoading = false; // Hide loading indicator after data is fetched
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      // );
      setState(() {
        _isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }
  Future<void> fetchEnabledVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchenable/${widget.id}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          carEnabled = data['carEnabled'] ?? false;
          bikeEnabled = data['bikeEnabled'] ?? false;
          othersEnabled = data['othersEnabled'] ?? false;

          carTemporary = data['carTemporary'] ?? false;
          bikeTemporary = data['bikeTemporary'] ?? false;
          othersTemporary = data['othersTemporary'] ?? false;

          carFullDay = data['carFullDay'] ?? false;
          bikeFullDay = data['bikeFullDay'] ?? false;
          othersFullDay = data['othersFullDay'] ?? false;

          carMonthly = data['carMonthly'] ?? false;
          bikeMonthly = data['bikeMonthly'] ?? false;
          othersMonthly = data['othersMonthly'] ?? false;
        });

        // Reinitialize the TabController after updating enabled vehicles
        _initializeTabController();
      } else {
        throw Exception('Failed to fetch enabled vehicles');
      }
    } catch (e) {
      print('Error fetching enabled vehicles: $e');
    }
  }
  List<ParkingCharge> charges = [];
  List<ParkingCharge> amenities = [];
  Future<List<ParkingCharge>> fetchamenities(String vendorId) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId'); // Replace with your actual API URL

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
            data['vendor']['charges']
                .map((item) => ParkingCharge.fromJson(item)),
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

  late final TabController _contoller;
  List<Map<String, dynamic>> businessHours = List.generate(7, (index) {
    return {
      'day': getDayOfWeek(index),
      'openTime': '09:00',
      'closeTime': '21:00',
      'is24Hours': false,
      'isClosed': false,
    };
  });

  List<String> hours = List.generate(24, (index) {
    return index < 10 ? '0$index:00' : '$index:00';
  });


  Future<void> fetchFullDayMode(String vehicleType) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}vendor/getfullday/${widget.id}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      setState(() {
        if (vehicleType == 'car') {
          selectcar = data['fulldaycar'] ?? 'Full Day';
        } else if (vehicleType == 'bike') {
          selectbike = data['fulldaybike'] ?? 'Full Day';
        } else if (vehicleType == 'others') {
          selectothers = data['fulldayothers'] ?? 'Full Day';
        }
      });
    } else {
      print("Failed to fetch full day mode: ${response.body}");
    }
  }
  Future<Map<String, dynamic>> fetchVendor(String vendorId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fetchbusinesshours/$vendorId'),
      );

      if (response.statusCode == 200) {
        isLoading = false;
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch vendor');
      }
    } catch (e) {
      print('Error: $e');
      isLoading = false;
      return {};
    }
  }
  late Future<Map<String, dynamic>> vendorData;
  @override
  void initState() {
    super.initState();
    if (_vendor != null) {
      value = _vendor!.visibility;
    }
    vendorData = fetchVendor(widget.vendorId); // Initialize vendorData here
    fetchFullDayMode('car');    // for car switch
    fetchFullDayMode('bike'); // for bike switch
    fetchFullDayMode('others'); // for others switch
    selectedTabIndex = 0; // Initialize to the first tab
    selecedIndex = 0; // Initialize to the first sub-tab
    vendorData.then((data) {
      setState(() {
        if (data['businessHours'] != null) {
          businessHours = List<Map<String, dynamic>>.from(data['businessHours']);
        }
        isLoading = false;
      });
    });
    _controller = TabController(vsync: this, length: 3);
    _chargesController = TabController(vsync: this, length: 3);

    _fetchVendorData();
    _controller.addListener(() {
      setState(() {
        selectedTabIndex = _controller.index;
        // Update the selected tab index
      });
      fetchChargesData();
    });

    selecedIndex = 0;
    _initializeTabController();
    fetchChargesData(); // Fetch data
    fetchInitialData();
    fetchEnabledVehicles().then((_) {
      _initializeTabController();
      fetchChargesData();
    });// Call this for initial data fetch
    fetchChargesData();
    // Fetch data
    fetchInitialData();
  }
  void _initializeTabController() {
    final enabledTypes = getEnabledVehicleTypes();

    // Dispose of the old controller if it exists
    _chargesController?.dispose();

    if (enabledTypes.isEmpty) {
      _chargesController = null;
      selecedIndex = 0; // Reset index when no tabs
      return;
    }

    // Ensure selecedIndex is within bounds
    selecedIndex = selecedIndex.clamp(0, enabledTypes.length - 1);

    _chargesController = TabController(
      length: enabledTypes.length,
      vsync: this,
      initialIndex: selecedIndex,
    );

    _chargesController!.addListener(() {
      if (!_chargesController!.indexIsChanging) {
        setState(() {
          selecedIndex = _chargesController!.index;
        });
        fetchChargesData();
      }
    });
  }
  Future<void> fetchChargesData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final enabledTypes = getEnabledVehicleTypes();
      if (enabledTypes.isEmpty || selecedIndex >= enabledTypes.length) {
        return; // Skip if no enabled types or invalid index
      }
      final currentType = enabledTypes[selecedIndex];

      switch (currentType) {
        case 'Car':
          await fetchMinimumCharge(widget.id);
          await fetchAdditionalCharge(widget.id);
          await fetchfulldaycar(widget.id);
          await fetchfulldaymonthly(widget.id);
          break;
        case 'Bike':
          await fetchbikeMinimumCharge(widget.id);
          await fetchbikeAdditionalCharge(widget.id);
          await fetchbikefulldaycar(widget.id);
          await fetchbikefulldaymonthly(widget.id);
          break;
        case 'Others':
          await fetchotherMinimumCharge(widget.id);
          await fetchotherAdditionalCharge(widget.id);
          await fetchotherfulldaycar(widget.id);
          await fetchotherfulldaymonthly(widget.id);
          break;
      }
    } catch (e) {
      showSnackBar("Error fetching charges: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  List<String> getEnabledVehicleTypes() {
    List<String> enabledTypes = [];
    if (carEnabled) enabledTypes.add('Car');
    if (bikeEnabled) enabledTypes.add('Bike');
    if (othersEnabled) enabledTypes.add('Others');
    return enabledTypes;
  }

  void fetchInitialData() {
    fetchChargesData(); // Fetch charges data
    fetchAmenitiesAndCharges(widget.id); // Fetch amenities data
  }

  @override
  void dispose() {
    _controller.dispose();
    _chargesController?.dispose(); // No need for null check since it's not nullable
    super.dispose();
  }

  void _refreshData() {
    // Call the methods to fetch the updated data
    fetchChargesData(); // This will refresh the charges data
    fetchAmenitiesAndCharges(widget.id); // Refresh amenities if needed
  }

  Future<void> _updateVendorVisibility(bool newValue) async {
    print("🔄 Updating vendor visibility for Vendor ID: ${widget.id}");
    print("➡️ New visibility value: $newValue");

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/visibility/${widget.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'visibility': newValue}),
      );

      print("📡 API Response Status Code: ${response.statusCode}");
      print("📡 API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Decoded response: $data");

        if (data.containsKey('vendor')) {
          print("📦 Vendor data found. Updating state...");
          setState(() {
            _vendor = Vendor.fromJson(data['vendor']);
          });
          // print("✅ Vendor updated: ${_vendor.toJson()}");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newValue
                    ? 'Visibility on successfully'
                    : 'Visibility off successfully',
              ),
            ),
          );
        } else {
          print("⚠️ Vendor key not found in response.");
          throw Exception('Invalid response: Missing vendor data');
        }
      } else {
        print("❌ Failed response: ${response.body}");
        throw Exception('At least one slot (Car, Bike, or Others) must be available and enabled to set visibility');
      }
    } catch (e) {
      print('🔥 Exception caught: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('At least one slot (Car, Bike, or Others) must be available and enabled to set visibility')),
      );
    }
  }

  Future<Map<String, dynamic>> fetchAmenitiesAndCharges(String vendorId) async {
    final amenitiesUrl =
        Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final responses = await Future.wait([
        http.get(amenitiesUrl),
        // Add the charges URL here if you are fetching charges as well
        // http.get(chargesUrl), // Uncomment and define chargesUrl if needed
      ]);

      // Print the status codes of the responses
      for (var response in responses) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      // Check if the first response (amenities) is successful
      if (responses[0].statusCode == 200) {
        final amenitiesData = json.decode(responses[0].body);
        print('Amenities Data: $amenitiesData'); // Log the amenities data

        // Parse amenities
        final amenitiesList =
            List<String>.from(amenitiesData['AmenitiesData']['amenities']);
        print('Parsed Amenities: $amenitiesList'); // Log parsed amenities

        // If you are fetching charges, ensure you have the second response
        // Uncomment the following lines if you are fetching charges
        // if (responses[1].statusCode == 200) {
        //   final chargesData = json.decode(responses[1].body);
        //   print('Charges Data: $chargesData'); // Log the charges data

        //   final charges = List<Services>.from(
        //     chargesData['vendor']['charges'].map((item) => Services.fromJson(item)),
        //   );

        //   return {
        //     'amenities': amenitiesList,
        //     'parkingCharges': charges,
        //   };
        // } else {
        //   throw Exception('Failed to fetch charges data');
        // }

        return {
          'amenities': amenitiesList,
          // 'parkingCharges': charges, // Uncomment if you are fetching charges
        };
      } else {
        throw Exception('Failed to fetch amenities data');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    }
  }
  String selectcar = 'Full Day'; // Initial mode
  String selectbike = 'Full Day'; // Initial mode
  String selectothers = 'Full Day'; // Initial mode

  bool carEnabled = false;
  bool bikeEnabled = false;
  bool othersEnabled = false;


  bool isLoading = true;
  List<ParkingCharge> minimumCharges = [];
  List<ParkingbikeCharge> minimumbikeCharges = [];
  List<ParkingotherCharge> minimumotherCharges = [];
  List<ParkingCharge> additionalCharges = [];
  List<ParkingbikeCharge> additionalbikeCharges = [];
  List<ParkingotherCharge> additionalotherCharges = [];
  List<ParkingCharge> fulldaycharge = [];
  List<ParkingbikeCharge> fulldaybikecharge = [];
  List<ParkingotherCharge> fulldayothercharge = [];
  List<ParkingbikeCharge> monthlybikecharge = [];
  List<ParkingotherCharge> monthlyothercharge = [];
  List<ParkingCharge> monthlycharge = [];
  List<Map<String, dynamic>> parkingEntries = [];
  final List<String> parkingTypes = [
    '0 to 1 hour',
    '0 to 2 hours',
    '0 to 3 hours',
    '0 to 4 hours',
  ];
  final List<String> addcharge = [
    'Additional 1 hour',
    'Additional 2 hours',
    'Additional 3 hours',
    'Additional 4 hours',
  ];
  final List<String> fullday = ['Full day'];
  final List<String> monthly = ['Monthly'];
  Future<void> fetchMinimumCharge(String vendorId) async {
    setState(() {
      isLoading = true; // Start loading
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            minimumCharges = charges
                .where((charge) =>
                    charge.category == 'Car' &&
                    parkingTypes.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No minimum charges found");
        }
      } else {
        showSnackBar("Failed to load minimum charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }

  Future<void> fetchbikeMinimumCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching data from: $url'); // Print the URL
      final response = await http.get(url);
      print(
          'Response status: ${response.statusCode}'); // Print response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print raw data

        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found'); // Confirm vendor charges are found
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingbikeCharge.fromJson(item)),
          );

          print(
              'Total charges fetched: ${chargess.length}'); // Print total charges count

          setState(() {
            minimumbikeCharges = chargess
                .where((charges) =>
                    charges.category == 'Bike' &&
                    parkingTypes.contains(charges.type))
                .toList();
            print(
                'Filtered charges: $minimumbikeCharges'); // Print filtered charges
          });
        } else {
          print('No charges found in vendor data'); // Log if no charges exist
          showSnackBar("No minimum charges found");
        }
      } else {
        print(
            'Failed to load charges. Status code: ${response.statusCode}'); // Log failure
        // showSnackBar("Failed to load minimum charges");
      }
    } catch (e) {
      print('Error occurred: $e'); // Print error message
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
      print('Loading completed'); // Indicate loading is complete
    }
  }

  Future<void> fetchotherMinimumCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching data from: $url'); // Print the URL
      final response = await http.get(url);
      print(
          'Response status: ${response.statusCode}'); // Print response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print raw data

        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found'); // Confirm vendor charges are found
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingotherCharge.fromJson(item)),
          );

          print(
              'Total charges fetched: ${chargesss.length}'); // Print total charges count

          setState(() {
            minimumotherCharges = chargesss
                .where((charges) =>
                    charges.category == 'Others' &&
                    parkingTypes.contains(charges.type))
                .toList();
            print(
                'Filtered charges: $minimumbikeCharges'); // Print filtered charges
          });
        } else {
          print('No charges found in vendor data'); // Log if no charges exist
          showSnackBar("No minimum charges found");
        }
      } else {
        print(
            'Failed to load charges. Status code: ${response.statusCode}'); // Log failure
        // showSnackBar("Failed to load minimum charges");
      }
    } catch (e) {
      print('Error occurred: $e'); // Print error message
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
      print('Loading completed'); // Indicate loading is complete
    }
  }
  Future<void> fetchAdditionalCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            additionalCharges = charges
                .where((charge) =>
                    charge.category == 'Car' && addcharge.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchbikeAdditionalCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching bike additional charges from: $url');
      final response = await http.get(url);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found: ${data['vendor']['charges']}');
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges'].map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            additionalbikeCharges = chargess
                .where((charge) => charge.category == 'Bike' && addcharge.contains(charge.type))
                .toList();
            print('Filtered additional bike charges: $additionalbikeCharges');
          });
        } else {
          print('No charges found in vendor data');
          showSnackBar("No additional charges found");
        }
      } else {
        print('Failed to load charges. Status code: ${response.statusCode}');
        showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      print('Error fetching bike additional charges: $e');
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  Future<void> fetchotherAdditionalCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            additionalotherCharges = chargesss
                .where((charge) =>
                    charge.category == 'Others' &&
                    addcharge.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchfulldaycar(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            fulldaycharge = charges
                .where((charge) =>
                    charge.category == 'Car' && fullday.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchbikefulldaycar(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            fulldaybikecharge = chargess
                .where((charge) =>
                    charge.category == 'Bike' && fullday.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchotherfulldaycar(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            fulldayothercharge = chargesss
                .where((charge) =>
                    charge.category == 'Others' &&
                    fullday.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchfulldaymonthly(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            monthlycharge = charges
                .where((charge) =>
                    charge.category == 'Car' && monthly.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchbikefulldaymonthly(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            monthlybikecharge = chargess
                .where((charge) =>
                    charge.category == 'Bike' && monthly.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchotherfulldaymonthly(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges']
                .map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            monthlyothercharge = chargesss
                .where((charge) =>
                    charge.category == 'Others' &&
                    monthly.contains(charge.type))
                .toList();
          });
        } else {
          showSnackBar("No additional charges found");
        }
      } else {
        // showSnackBar("Failed to load additional charges");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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
  void toggleParking(String vehicle, String type) {
    setState(() {
      if (vehicle == "Car") {
        if (type == "Temporary") {
          carTemporary = !carTemporary;
        } else if (type == "FullDay") {
          carFullDay = !carFullDay;
        } else if (type == "Monthly") {
          carMonthly = !carMonthly;
        }
      } else if (vehicle == "Bike") {
        if (type == "Temporary") {
          bikeTemporary = !bikeTemporary;
        } else if (type == "FullDay") {
          bikeFullDay = !bikeFullDay;
        } else if (type == "Monthly") {
          bikeMonthly = !bikeMonthly;
        }
      } else if (vehicle == "Others") {
        if (type == "Temporary") {
          othersTemporary = !othersTemporary;
        } else if (type == "FullDay") {
          othersFullDay = !othersFullDay;
        } else if (type == "Monthly") {
          othersMonthly = !othersMonthly;
        }
      }
    });

    // Call the update function to save the changes
    updateEnabledVehicles();
  }
  void toggleVehicle(String type) {
    setState(() {
      if (type == "Car") {
        carEnabled = !carEnabled;
        if (!carEnabled) {
          carTemporary = false;
          carFullDay = false;
          carMonthly = false;
        }
      } else if (type == "Bike") {
        bikeEnabled = !bikeEnabled;
        if (!bikeEnabled) {
          bikeTemporary = false;
          bikeFullDay = false;
          bikeMonthly = false;
        }
      } else if (type == "Others") {
        othersEnabled = !othersEnabled;
        if (!othersEnabled) {
          othersTemporary = false;
          othersFullDay = false;
          othersMonthly = false;
        }
      }

      // Reset selecedIndex when changing vehicle types
      selecedIndex = 0;
      _initializeTabController();
    });

    updateEnabledVehicles().then((_) {
      fetchEnabledVehicles();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // backgroundColor: ColorUtils.secondarycolor(),
          title: Text( _vendor?.vendorName ?? '',)
      ),
      body:
      SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            :SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        
                // _buildMySpaceDetails(MediaQuery.of(context).size.width),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomSlidingSegmentedControl<int>(
                      initialValue: selectedTabIndex,
                      isStretch: true,
                      children: {
                        0: Text(
                          'Profile',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        1: Text(
                          'Charges',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        2: Text(
                          'Amenities',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      },
                      onValueChanged: (value) {
                        setState(() {
                          selectedTabIndex = value;
                        });
                      },
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      thumbDecoration: BoxDecoration(
                        color: ColorUtils.secondarycolor(),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInToLinear,
                    ),
                  ),
                ),
                IndexedStack(
                  index: selectedTabIndex,
                  children: [
                    buildFirstTabContent(),
                    buildSecondTabContent(),
                    buildThirdTabContent(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
  Widget _statusLabel(String label, Color color, {bool isSmallScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 4, horizontal: isSmallScreen ? 4 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  Widget _styledBox(String value) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(":");
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = "${hour12.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")} $period";
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }
  static String getDayOfWeek(int index) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[index];
  }
  void _onVisibilityTurnedOn() {
    // Add your ON logic here
    debugPrint("Vendor is now VISIBLE");
    // Example: Show success Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor is now visible on platform')),
    );
  }

  void _onVisibilityTurnedOff() {
    // Add your OFF logic here
    debugPrint("Vendor is now HIDDEN");
    // Example: Remove vendor from live map or list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor is now hidden from users')),
    );
  }
  Widget _buildVisibilityConfirmSheet(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Turn On Your Visibility',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SvgPicture.asset('assets/svg/visible.svg', height: 150),
          const SizedBox(height: 10),
          Text(
            'Visibility is set to true and a platform fee will be deducted automatically.',
            style: GoogleFonts.poppins(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildModalButton(context, 'Cancel', Colors.grey, false),
              const SizedBox(width: 10),
              _buildModalButton(context, 'Confirm', ColorUtils.primarycolor(), true),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _buildModalButton(BuildContext context, String text, Color color, bool result) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context, result),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }
  Widget buildFirstTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  Align(
                    alignment: Alignment.bottomRight,
                    child: AnimatedToggleSwitch<bool>.dual(
                      current: _vendor?.visibility ?? false, // Use vendor's visibility directly
                      first: false,
                      second: true,
                      borderWidth: 1.0,
                      height: 24.0,
                      spacing: 15.0,
                      styleBuilder: (val) => ToggleStyle(
                        backgroundColor: Colors.black,
                        borderColor: Colors.grey.shade400,
                        indicatorColor: val ? ColorUtils.primarycolor() : Colors.red,
                      ),
                      onChanged: (val) async {
                        // Show loading indicator
                        bool? confirmed = val; // Default to immediate action for turning OFF

                        // Only show confirmation for turning ON
                        if (val == true) {
                          confirmed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: _buildVisibilityConfirmSheet(context),
                            ),
                          );
                        }

                        if (confirmed != null && confirmed == val) {
                          try {
                            // Show processing state
                            setState(() {
                              value = val; // Immediate UI feedback
                            });

                            await _updateVendorVisibility(val);

                            // Final state update
                            setState(() {
                              _vendor = _vendor?.copyWith(visibility: val);
                              value = val;
                            });

                            // Call appropriate handlers
                            if (val) {
                              _onVisibilityTurnedOn();
                            } else {
                              _onVisibilityTurnedOff();
                            }
                          } catch (e) {
                            // Revert on error
                            setState(() {
                              value = !val;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update visibility: ${e.toString()}')),
                            );
                          }
                        } else {
                          // Revert if user cancelled
                          setState(() {
                            value = !val;
                          });
                        }
                      },
                      iconBuilder: (val) => Icon(
                        val ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      textBuilder: (val) => Text(
                        val ? "VISIBLE" : "HIDDEN", // More descriptive text
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10, // Slightly smaller for longer text
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10,),


                ],
              ),
              _buildVendorHeader(),
              const SizedBox(height: 10),
              Text(
                "Location Details",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildMap(),
              const SizedBox(height: 15),
              Text(
                "Operational Timings",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessHours(vendorid: widget.id),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Shrink to fit content
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(Icons.edit, color: Colors.black, size: 12),
                        ),
                        const SizedBox(width: 5.0),
                        Text(
                          'Edit Hours',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                child: Column(
                  children: [

                    Divider(
                      thickness: 0.5, // Set the thickness of the divider
                      color: ColorUtils.primarycolor(), // Set the color of the divider
                    ),
                    const SizedBox(height: 5),
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Expanded(flex: 3, child: Text('Open at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Expanded(flex: 3, child: Text('Close at', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: businessHours.length,
                            itemBuilder: (context, index) {
                              final dayData = businessHours[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(dayData['day'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black87)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: dayData['isClosed']
                                          ? _statusLabel('Closed', Colors.red)
                                          : dayData['is24Hours']
                                          ? _statusLabel('24 Hours', Colors.green)
                                          : _styledBox(dayData['openTime']),

                                    ),
                                    if (!dayData['isClosed'] && !dayData['is24Hours'])
                                      const SizedBox(width: 8.0),
                                    if (!dayData['isClosed'] && !dayData['is24Hours'])
                                      Expanded(
                                        flex: 3,
                                        child: _styledBox(dayData['closeTime']),
                                      ),

                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Text("Contact details", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                  ],
                ),
              ),


              const SizedBox(height: 15),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => editslotuserspace(vendorid: widget.id),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // Shrink to fit content
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(Icons.edit, color: Colors.black, size: 12),
                        ),
                        const SizedBox(width: 5.0),
                        Text(
                          'Edit Slots',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildInfoCard(),
                        buildbookedslot(),
                        buildavailableslot(),
                      ],
                    ),
      ],
    );
  }
  Future<void> updateEnabledVehicles() async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/updateenable/${widget.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "carEnabled": carEnabled,
          "bikeEnabled": bikeEnabled,
          "othersEnabled": othersEnabled,
          "carTemporary": carTemporary,
          "bikeTemporary": bikeTemporary,
          "othersTemporary": othersTemporary,
          "carFullDay": carFullDay,
          "bikeFullDay": bikeFullDay,
          "othersFullDay": othersFullDay,
          "carMonthly": carMonthly,
          "bikeMonthly": bikeMonthly,
          "othersMonthly": othersMonthly,
        }),
      );

      if (response.statusCode == 200) {
        print('Update successful');
      } else {
        print('Failed to update: ${response.body}');
      }
    } catch (e) {
      print('Error updating enabled vehicles: $e');
    }
  }
  Widget _buildVehicleSwitch(String label, bool value, String vehicleType) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 0),
        AnimatedToggleSwitch<bool>.dual(
          current: value,
          first: false,
          second: true,
          borderWidth: 1.0,
          height: 24.0,
          spacing: 15.0,
          styleBuilder: (val) => ToggleStyle(
            backgroundColor: val ? Colors.black : Colors.black,
            borderColor: Colors.grey.shade400,
            indicatorColor: val ?  ColorUtils.primarycolor() : Colors.red,
          ),
          onChanged: (val) {
            toggleVehicle(vehicleType);
            updateEnabledVehicles();
          },
          iconBuilder: (val) => Icon(
            val ? Icons.power : Icons.power_settings_new_outlined,
            color: Colors.white,
            size: 16,
          ),
          textBuilder: (val) => Text(
            val ? "ON" : 'OFF',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParkingOptions(String vehicleType, bool temp, bool full, bool monthly) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildParkingSwitch(vehicleType, "Temporary", temp),
        _buildParkingSwitch(vehicleType, "FullDay", full),
        _buildParkingSwitch(vehicleType, "Monthly", monthly),
      ],
    );
  }


  Widget _buildParkingSwitch(String vehicle, String type, bool value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 5,),
        Text(
          type, // heading text
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 0),
        AnimatedToggleSwitch<bool>.dual(
          current: value,
          first: false,
          second: true,
          borderWidth: 1.0,
          height: 24.0,
          spacing: 14.0,
          styleBuilder: (val) => ToggleStyle(
            backgroundColor: val ? Colors.black : Colors.black,
            borderColor: Colors.grey.shade400,
            indicatorColor: val ?  ColorUtils.primarycolor() : Colors.red,
          ),
          onChanged: (val) {
            if (val != value) {
              toggleParking(vehicle, type);
            }
          },
          iconBuilder: (val) => Icon(
            val ? Icons.power : Icons.power_settings_new_outlined,
            color: Colors.white,
            size: 16,
          ),
          textBuilder: (val) => Text(
            val ? "ON" : 'OFF',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }


  Widget buildThirdTabContent() {
    // Build your third tab content here
    return FutureBuilder<AmenitiesAndParking>(
      future: fetchAmenitiesAndParking(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0), // Adjust padding as needed
              child: Image.asset('assets/gifload.gif'),
            ),
          );
        } else if (snapshot.hasError) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Text(
                      "Amenities:",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8), // Adds some space between text and icon
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Addamenties(
                              vendorid: widget.id,
                              onEditSuccess: () {
                                setState(() {
                                  selectedTabIndex =
                                      2; // Change to the third tab
                                });
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        // Set the background color
                        decoration: BoxDecoration(
                          color: Colors.white, // Background color

                          borderRadius: BorderRadius.circular(
                              30), // Circular border radius
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.black, // Icon color
                          size: 20,
                        ),
                      ),
                    ), // Pencil icon
                  ],
                ),
              ),
              const SizedBox(
                height: 100,
              ),
              const Center(child: Text("No Amenties Data Found")),

            ],
          );
        } else if (snapshot.hasData) {
          final amenities = snapshot.data!.amenities; // List<String>
          final services = snapshot.data!.services; // List<Services>

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Text(
                        "Amenities:",
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                          width: 8), // Adds some space between text and icon
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Editamenities(
                                vendorid: widget.id,
                                onEditSuccess: () {
                                  setState(() {
                                    selectedTabIndex =
                                        2; // Change to the third tab
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          // Set the background color
                          decoration: BoxDecoration(
                            color: Colors.white, // Background color

                            borderRadius: BorderRadius.circular(
                                30), // Circular border radius
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.black, // Icon color
                            size: 20,
                          ),
                        ),
                      ), // Pencil icon
                    ],
                  ),

                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6.0,
                                offset: Offset(0, 2),
                              ),
                            ]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getAmenityIcon(amenity),
                              color: ColorUtils.primarycolor(),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              amenity,
                              style: GoogleFonts.poppins(
                                color: ColorUtils.primarycolor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),


                  Row(
                    children: [
                      Text(
                        "Additional Services:",
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                          width: 8), // Adds some space between text and icon
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => editParkingPage(
                                onEditSuccess: () {
                                  setState(() {
                                    selectedTabIndex =
                                        2; // Change to the third tab
                                  });
                                },
                                vendorId: widget.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          // Set the background color
                          decoration: BoxDecoration(
                            color: Colors.white, // Background color

                            borderRadius: BorderRadius.circular(
                                30), // Circular border radius
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.black, // Icon color
                            size: 20,
                          ),
                        ),
                      ), // Pencil icon
                    ],
                  ),

                  // Align(
                  //   alignment: Alignment.centerLeft, // Aligns content to the left
                  //   child: Text(
                  //     "Additional Services:",
                  //     style:  GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.bold),
                  //   ),
                  // ),
                  const SizedBox(height: 10),
                  // Heading Card
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      children: [
                        // Bold Heading Card
                        SizedBox(
                          width:
                              double.infinity, // or a specific width, e.g., 300
                          height:
                              40, // set a specific height for the heading card
                          child: Card(
                            color:
                                Colors.white, // Set the Card color explicitly
                            child: Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: Row(
                                children: [
                                  // Heading for Serial Number
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "S.No", // Heading text
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: ColorUtils.primarycolor(),
                                        fontWeight:
                                            FontWeight.bold, // Make it bold
                                      ),
                                      textAlign: TextAlign
                                          .center, // Center the heading
                                    ),
                                  ),
                                  // Heading for Service Type
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "Services", // Heading text
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: ColorUtils.primarycolor(),
                                        fontWeight:
                                            FontWeight.bold, // Make it bold
                                      ),
                                      textAlign: TextAlign
                                          .center, // Center the heading
                                    ),
                                  ),
                                  // Heading for Amount
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Amount", // Heading text
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: ColorUtils.primarycolor(),
                                        fontWeight:
                                            FontWeight.bold, // Make it bold
                                      ),
                                      textAlign: TextAlign
                                          .center, // Center the heading
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loop through the services list
                  ...services
                      .asMap()
                      .map(
                        (index, s) => MapEntry(
                          index,
                          Column(
                            children: [
                              // Content Card
                              SizedBox(
                                width: double
                                    .infinity, // or a specific width, e.g., 300
                                height:
                                    40, // set a specific height for the card
                                child: Card(
                                  color: Colors
                                      .white, // Set the Card color explicitly
                                  child: Row(
                                    children: [
                                      // Serial Number (index + 1)
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          "${index + 1}.", // Serial number starts from 1
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.bold, // Make it bold
                                          ),
                                          textAlign: TextAlign
                                              .center, // Align to center
                                        ),
                                      ),
                                      // Service Type
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          s.type,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign
                                              .center, // Align to center
                                        ),
                                      ),
                                      // Amount
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "₹${s.amount}",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign
                                              .center, // Align to center
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .values,
                ],
              ),
            ),
          );
        } else {
          return const Text("No data found.");
        }
      },
    );
  }

  Widget buildSecondTabContent() {
    final enabledTypes = getEnabledVehicleTypes();



    // Build your second tab content here
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVehicleSwitch("Car", carEnabled, "Car"),
            const SizedBox(width: 6,),
            _buildVehicleSwitch("Bike", bikeEnabled, "Bike"),
            const SizedBox(width: 6,),
            _buildVehicleSwitch("Others", othersEnabled, "Others"),

          ],
        ),
        const SizedBox(height: 10,),
        if (enabledTypes.isNotEmpty && _chargesController != null) // Only show TabContainer if at least one vehicle is enabled
          Container(
            decoration: BoxDecoration(
              color: ColorUtils.primarycolor(),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white,
                width: 2.0,
              ),
            ),
            child: TabContainer(
              controller: _chargesController,
              borderRadius: BorderRadius.circular(20),
              tabEdge: TabEdge.top,
              curve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                animation = CurvedAnimation(curve: Curves.easeIn, parent: animation);
                return SlideTransition(
                  position: Tween(
                    begin: const Offset(0.2, 0.0),
                    end: const Offset(0.0, 0.0),
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              colors: List.filled(enabledTypes.length, Colors.white),
              selectedTextStyle: GoogleFonts.poppins(
                fontSize: 15.0,
                color: ColorUtils.primarycolor(),
              ),
              unselectedTextStyle: GoogleFonts.poppins(
                fontSize: 13.0,
                color: Colors.black,
              ),
              tabs: _geTabs(),
              children: enabledTypes.map((type) {
                switch (type) {
                  case 'Car':
                    return _buildCarTabContent();
                  case 'Bike':
                    return _buildBikeTabContent();
                  case 'Others':
                    return _buildOthersTabContent();
                  default:
                    return Container(); // Fallback
                }
              }).toList(),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Please enable at least one vehicle type"),
          ),
      ],
    );
  }



  List<Widget> _geTabs() {
    final enabledTypes = getEnabledVehicleTypes();
    if (enabledTypes.isEmpty) return [];
    return enabledTypes.asMap().entries.map((entry) {
      final index = entry.key;
      final type = entry.value;

      IconData icon;
      String label;

      switch (type) {
        case 'Car':
          icon = Icons.drive_eta;
          label = 'Cars';
          break;
        case 'Bike':
          icon = Icons.pedal_bike;
          label = 'Bikes';
          break;
        case 'Others':
          icon = Icons.miscellaneous_services;
          label = 'Others';
          break;
        default:
          icon = Icons.help_outline;
          label = 'Unknown';
      }

      final isSelecte = selecedIndex == index;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelecte ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelecte ? Colors.black : Colors.white,
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget buildInfoCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchCategories(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['categories'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['totalCount'];
        List<Category> categories = snapshot.data!['categories'];

        return _buildContent("Total", totalCount, categories);
      },
    );
  }

  Widget _buildCarTabContent() {
    return        SingleChildScrollView(
      child: Padding(

        padding: const EdgeInsets.all(5.0),
        child:  isLoading // Check if loading
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Image.asset('assets/gifload.gif',),
          ),
        )
            :Column(
          children: [


// Text(widget.id),
            if (carEnabled) _buildParkingOptions("Car", carTemporary, carFullDay, carMonthly),
            if (carEnabled &  carTemporary) ...[
              // Text(widget.id),
              Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: Row(

                  children: [
                    // First Container wrapped with Expanded to fit the screen width
                    Expanded(
                      child: GestureDetector(
                        // When navigating to addMinimumCharge
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => addcarspaceminimumcharge(
                              onEditSuccess: () {
                                selecedIndex = 0;
                              },
                              vendorid: widget.id,
                            )),
                          );
                          // After returning, refresh the data
                          _refreshData();
                        },
                        child: Container(
                          height: 120, // Increased for the toggle switch
                          // width: 160,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Minimum Charges",
                                style:  GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    minimumCharges.isNotEmpty ? minimumCharges[0].type : '',
                                    style:  GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: minimumCharges.isNotEmpty
                                        ? Text(
                                      minimumCharges[0].amount,
                                      style:  GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : GestureDetector(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => addcarspaceminimumcharge(
                                            onEditSuccess: () {
                                              selecedIndex = 0;
                                            },
                                            vendorid: widget.id,
                                          )),
                                        );
                                        // After returning, refresh the data
                                        _refreshData();
                                      },
                                          child: const IconButton(
                                                                              icon: Icon(
                                          Icons.add_circle,
                                          color: Colors.black,
                                                                              ),
                                                                              onPressed: null,
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

                    // const Spacer(),
                    const SizedBox(width: 2),
                    // Second Container wrapped with Expanded to fit the screen width
                    Expanded(
                      child: GestureDetector(
                        // When navigating to addMinimumCharge
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => addcarspaceadditionalcharge(
                              onEditSuccess: () {
                                selecedIndex = 0; // This callback can be used if you want to perform actions on success
                              },
                              vendorid: widget.id,
                            )),
                          );
                          // After returning, refresh the data
                          _refreshData();
                        },

                        child: Container(
                          height: 120, // Increased for the toggle switch
                          // width: 160,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(), // Change color if selected
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Additional Charges", // You can change the title dynamically
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              // Display the type of charge at the top
                              Text(
                                " ${additionalCharges.isNotEmpty ? additionalCharges[0].type : ''}", // Display type or ' if no data
                                style:  GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),

                              // Display the amount below the type
                              // CircleAvatar with action button
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: additionalCharges.isNotEmpty
                                    ? Text(
                                  additionalCharges[0].amount, // Display the amount as text
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 16, // Adjust font size as needed
                                  ),
                                )
                                    : GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => addcarspaceadditionalcharge(
                                        onEditSuccess: () {
                                          selecedIndex = 0; // This callback can be used if you want to perform actions on success
                                        },
                                        vendorid: widget.id,
                                      )),
                                    );
                                    // After returning, refresh the data
                                    _refreshData();
                                  },
                                      child: const IconButton(
                                                                        icon: Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                                                        ),
                                                                        onPressed: null,
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
              ),
            ],
            const SizedBox(height: 2,),
            Row(
              children: [
                if (carEnabled && carFullDay && !carMonthly) ...[
                  // Full-Day Charges Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => addcarspacefullday(
                                onEditSuccess: () {
                                  selecedIndex = 0; // Fixed typo
                                },
                                vendorid: widget.id,
                              ),
                            ),
                          );
                          _refreshData();
                        },
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Full-Day Charges",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: fulldaycharge.isNotEmpty
                                    ? Text(
                                  fulldaycharge[0].amount,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                )
                                    : const Icon(Icons.add_circle, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              AnimatedToggleSwitch<String>.dual(
                                current: selectcar,
                                first: 'Full Day',
                                second: '24 Hours',
                                spacing: 25.0,
                                borderWidth: 1.0,
                                height: 20,
                                styleBuilder: (val) => ToggleStyle(
                                  backgroundColor: Colors.white,
                                  borderColor: Colors.grey.shade400,
                                  indicatorColor: Colors.red,
                                ),
                                textBuilder: (val) => Text(
                                  val,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                                iconBuilder: (val) => val == 'Full Day'
                                    ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                    : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                onChanged: (val) async {
                                  setState(() {
                                    selectcar = val;
                                  });
                                  final response = await http.put(
                                    Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldaycar/${widget.id}'),
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'fulldaycar': val}),
                                  );
                                  if (response.statusCode == 200) {
                                    print("Full day car mode updated successfully");
                                  } else {
                                    print("Failed to update full day car mode: ${response.body}");
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // White Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Add content here if needed (e.g., additional charges)
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (carEnabled && !carFullDay && carMonthly) ...[
                  // Monthly Charges Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => addMonthlyspacesubscription(
                                onEditSuccess: () {
                                  selecedIndex = 0; // Fixed typo
                                },
                                vendorid: widget.id,
                              ),
                            ),
                          );
                          _refreshData();
                        },
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Monthly Charges",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: monthlycharge.isNotEmpty
                                    ? Text(
                                  monthlycharge[0].amount,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                )
                                    : const Icon(Icons.add_circle, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // White Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Add content here if needed (e.g., additional charges)
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (carEnabled && carFullDay && carMonthly) ...[
                  // Full-Day Charges Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => addcarspacefullday(
                                onEditSuccess: () {
                                  selecedIndex = 0; // Fixed typo
                                },
                                vendorid: widget.id,
                              ),
                            ),
                          );
                          _refreshData();
                        },
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Full-Day Charges",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: fulldaycharge.isNotEmpty
                                    ? Text(
                                  fulldaycharge[0].amount,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                )
                                    : const Icon(Icons.add_circle, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              AnimatedToggleSwitch<String>.dual(
                                current: selectcar,
                                first: 'Full Day',
                                second: '24 Hours',
                                spacing: 25.0,
                                borderWidth: 1.0,
                                height: 20,
                                styleBuilder: (val) => ToggleStyle(
                                  backgroundColor: Colors.white,
                                  borderColor: Colors.grey.shade400,
                                  indicatorColor: Colors.red,
                                ),
                                textBuilder: (val) => Text(
                                  val,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                                iconBuilder: (val) => val == 'Full Day'
                                    ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                    : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                onChanged: (val) async {
                                  setState(() {
                                    selectcar = val;
                                  });
                                  final response = await http.put(
                                    Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldaycar/${widget.id}'),
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'fulldaycar': val}),
                                  );
                                  if (response.statusCode == 200) {
                                    print("Full day car mode updated successfully");
                                  } else {
                                    print("Failed to update full day car mode: ${response.body}");
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Monthly Charges Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => addMonthlyspacesubscription(
                                onEditSuccess: () {
                                  selecedIndex = 0; // Fixed typo
                                },
                                vendorid: widget.id,
                              ),
                            ),
                          );
                          _refreshData();
                        },
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor(),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Monthly Charges",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: monthlycharge.isNotEmpty
                                    ? Text(
                                  monthlycharge[0].amount,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                )
                                    : const Icon(Icons.add_circle, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),


          ],
        ),
      ),
    );


  }
  Widget _buildBikeTabContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(5.0),
            child:  isLoading // Check if loading
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Image.asset('assets/gifload.gif',),
              ),
            )
                :Column(
              children: [

                // _buildVehicleSwitch("Bike", bikeEnabled, "Bike"),
                if (bikeEnabled) _buildParkingOptions("Bike", bikeTemporary, bikeFullDay, bikeMonthly),
                if (bikeEnabled &&bikeTemporary) ...[
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addbikespaceminimumcharge(
                                onEditSuccess: () {

                                  selecedIndex = 1; // This callback can be used if you want to perform actions on success
                                },
                                vendorid: widget.id,
                              )),
                            );
                            // After returning, refresh the data
                            _refreshData();
                          },
                          child: Container(
                            height: 120, // Increased for the toggle switch
                            // width: 160,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Minimum Charges",
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  minimumbikeCharges.isNotEmpty ? minimumbikeCharges[0].type : '',
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: minimumbikeCharges.isNotEmpty
                                      ? Text(
                                    minimumbikeCharges[0].amount,
                                    style:  GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addbikespaceminimumcharge(
                                          onEditSuccess: () {

                                            selecedIndex = 1; // This callback can be used if you want to perform actions on success
                                          },
                                          vendorid: widget.id,
                                        )),
                                      );
                                      // After returning, refresh the data
                                      _refreshData();
                                    },
                                        child: const IconButton(
                                                                          icon: Icon(
                                        Icons.add_circle,
                                        color: Colors.black,
                                                                          ),
                                                                          onPressed: null,
                                                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2,),

                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addbikespaceadditionalcharge(
                                onEditSuccess: () {
                                  selecedIndex = 1; // This callback can be used if you want to perform actions on success
                                },
                                vendorid: widget.id,
                              )),
                            );
                            // After returning, refresh the data
                            _refreshData();
                          },
                          child: Container(
                            height: 120, // Increased for the toggle switch
                            // width: 160,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(), // Change color if selected
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Additional Charges", // You can change the title dynamically
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                // Display the type of charge at the top
                                Text(
                                  " ${additionalbikeCharges.isNotEmpty ? additionalbikeCharges[0].type : ''}", // Display type or ' if no data
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                // Display the amount below the type
                                // CircleAvatar with action button
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: additionalbikeCharges.isNotEmpty
                                      ? Text(
                                    additionalbikeCharges[0].amount, // Display the amount as text
                                    style:  GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16, // Adjust font size as needed
                                    ),
                                  )
                                      : GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addbikespaceadditionalcharge(
                                          onEditSuccess: () {
                                            selecedIndex = 1; // This callback can be used if you want to perform actions on success
                                          },
                                          vendorid: widget.id,
                                        )),
                                      );
                                      // After returning, refresh the data
                                      _refreshData();
                                    },
                                        child: const IconButton(
                                                                          icon: Icon(
                                        Icons.add_circle,
                                        color: Colors.black,
                                                                          ),
                                                                          onPressed: null,
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
                ],
                const SizedBox(height: 2,),
                Row(
                  children: [
                    if (bikeEnabled && bikeFullDay && !bikeMonthly) ...[
                      // Full-Day Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addbikespacefullday(
                                    onEditSuccess: () {
                                      selecedIndex = 1; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Full-Day Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: fulldaybikecharge.isNotEmpty
                                        ? Text(
                                      fulldaybikecharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedToggleSwitch<String>.dual(
                                    current: selectbike,
                                    first: 'Full Day',
                                    second: '24 Hours',
                                    spacing: 25.0,
                                    borderWidth: 1.0,
                                    height: 20,
                                    styleBuilder: (val) => ToggleStyle(
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.grey.shade400,
                                      indicatorColor: Colors.red,
                                    ),
                                    textBuilder: (val) => Text(
                                      val,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                    iconBuilder: (val) => val == 'Full Day'
                                        ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                        : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                    onChanged: (val) async {
                                      setState(() {
                                        selectbike = val;
                                      });
                                      final response = await http.put(
                                        Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldaybike/${widget.id}'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({'fulldaybike': val}),
                                      );
                                      if (response.statusCode == 200) {
                                        print("Full day bike mode updated successfully");
                                      } else {
                                        print("Failed to update full day bike mode: ${response.body}");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // White Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Add content here if needed (e.g., additional charges)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (bikeEnabled && !bikeFullDay && bikeMonthly) ...[
                      // Monthly Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addbikespaceMonthlysubscription(
                                    onEditSuccess: () {
                                      selecedIndex = 1; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Monthly Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: monthlybikecharge.isNotEmpty
                                        ? Text(
                                      monthlybikecharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // White Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Add content here if needed (e.g., additional charges)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (bikeEnabled && bikeFullDay && bikeMonthly) ...[
                      // Full-Day Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addbikespacefullday(
                                    onEditSuccess: () {
                                      selecedIndex = 1; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Full-Day Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: fulldaybikecharge.isNotEmpty
                                        ? Text(
                                      fulldaybikecharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedToggleSwitch<String>.dual(
                                    current: selectbike,
                                    first: 'Full Day',
                                    second: '24 Hours',
                                    spacing: 25.0,
                                    borderWidth: 1.0,
                                    height: 20,
                                    styleBuilder: (val) => ToggleStyle(
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.grey.shade400,
                                      indicatorColor: Colors.red,
                                    ),
                                    textBuilder: (val) => Text(
                                      val,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                    iconBuilder: (val) => val == 'Full Day'
                                        ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                        : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                    onChanged: (val) async {
                                      setState(() {
                                        selectbike = val;
                                      });
                                      final response = await http.put(
                                        Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldaybike/${widget.id}'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({'fulldaybike': val}),
                                      );
                                      if (response.statusCode == 200) {
                                        print("Full day bike mode updated successfully");
                                      } else {
                                        print("Failed to update full day bike mode: ${response.body}");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Monthly Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addbikespaceMonthlysubscription(
                                    onEditSuccess: () {
                                      selecedIndex = 1; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Monthly Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: monthlybikecharge.isNotEmpty
                                        ? Text(
                                      monthlybikecharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Add more bike-specific widgets here
        ],
      ),
    );
  }

  Widget _buildOthersTabContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(5.0),
            child:  isLoading // Check if loading
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Image.asset('assets/gifload.gif',),
              ),
            )
                :Column(
              children: [

                // _buildVehicleSwitch("Others", othersEnabled, "Others"),
                if (othersEnabled) _buildParkingOptions("Others", othersTemporary, othersFullDay, othersMonthly),
                if (othersEnabled && othersTemporary)
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersspaceminimumcharge(
                                onEditSuccess: () {
                                  selecedIndex = 2; // This callback can be used if you want to perform actions on success
                                },
                                vendorid: widget.id,
                              )),
                            );
                            // After returning, refresh the data
                            _refreshData();
                          },
                          child: Container(
                            height: 120, // Increased for the toggle switch
                            // width: 160,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Minimum Charges",
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  minimumotherCharges.isNotEmpty ? minimumotherCharges[0].type : '',
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: minimumotherCharges.isNotEmpty
                                      ? Text(
                                    minimumotherCharges[0].amount,
                                    style:  GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersspaceminimumcharge(
                                          onEditSuccess: () {
                                            selecedIndex = 2; // This callback can be used if you want to perform actions on success
                                          },
                                          vendorid: widget.id,
                                        )),
                                      );
                                      // After returning, refresh the data
                                      _refreshData();
                                    },
                                        child: const IconButton(
                                                                          icon: Icon(
                                        Icons.add_circle,
                                        color: Colors.black,
                                                                          ),
                                                                          onPressed:null,
                                                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2,),

                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersspaceadditionalcharge(
                                onEditSuccess: () {
                                  selecedIndex = 2; // This callback can be used if you want to perform actions on success
                                },
                                vendorid: widget.id,
                              )),
                            );
                            // After returning, refresh the data
                            _refreshData();
                          },
                          child: Container(
                            height: 120, // Increased for the toggle switch
                            // width: 160,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(), // Change color if selected
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Additional Charges", // You can change the title dynamically
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                // Display the type of charge at the top
                                Text(
                                  " ${additionalotherCharges.isNotEmpty ? additionalotherCharges[0].type : ''}", // Display type or '' if no data
                                  style:  GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                // Display the amount below the type
                                // CircleAvatar with action button
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: additionalotherCharges.isNotEmpty
                                      ? Text(
                                    additionalotherCharges[0].amount, // Display the amount as text
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16, // Adjust font size as needed
                                    ),
                                  )
                                      : GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersspaceadditionalcharge(
                                          onEditSuccess: () {
                                            selecedIndex = 2; // This callback can be used if you want to perform actions on success
                                          },
                                          vendorid: widget.id,
                                        )),
                                      );
                                      // After returning, refresh the data
                                      _refreshData();
                                    },
                                        child: const IconButton(
                                                                          icon: Icon(
                                        Icons.add_circle,
                                        color: Colors.black,
                                                                          ),
                                                                          onPressed: null,
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
                const SizedBox(height: 2,),

                Row(
                  children: [
                    if (othersEnabled && othersFullDay && !othersMonthly) ...[
                      // Full-Day Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addothersspacefullday(
                                    onEditSuccess: () {
                                      selecedIndex = 2; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Full-Day Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: fulldayothercharge.isNotEmpty
                                        ? Text(
                                      fulldayothercharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16, // Fixed to match bike/car
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedToggleSwitch<String>.dual(
                                    current: selectothers,
                                    first: 'Full Day',
                                    second: '24 Hours',
                                    spacing: 25.0,
                                    borderWidth: 1.0,
                                    height: 20,
                                    styleBuilder: (val) => ToggleStyle(
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.grey.shade400,
                                      indicatorColor: Colors.red,
                                    ),
                                    textBuilder: (val) => Text(
                                      val,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                    iconBuilder: (val) => val == 'Full Day'
                                        ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                        : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                    onChanged: (val) async {
                                      setState(() {
                                        selectothers = val;
                                      });
                                      final response = await http.put(
                                        Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldayothers/${widget.id}'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({'fulldayothers': val}),
                                      );
                                      if (response.statusCode == 200) {
                                        print("Full day others mode updated successfully");
                                      } else {
                                        print("Failed to update full day others mode: ${response.body}");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // White Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Add content here if needed (e.g., additional charges)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (othersEnabled && !othersFullDay && othersMonthly) ...[
                      // Monthly Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addothersspaceMonthlysubscription(
                                    onEditSuccess: () {
                                      selecedIndex = 2; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Monthly Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: monthlyothercharge.isNotEmpty
                                        ? Text(
                                      monthlyothercharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // White Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Add content here if needed (e.g., additional charges)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (othersEnabled && othersFullDay && othersMonthly) ...[
                      // Full-Day Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addothersspacefullday(
                                    onEditSuccess: () {
                                      selecedIndex = 2; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Full-Day Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: fulldayothercharge.isNotEmpty
                                        ? Text(
                                      fulldayothercharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16, // Fixed to match bike/car
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedToggleSwitch<String>.dual(
                                    current: selectothers,
                                    first: 'Full Day',
                                    second: '24 Hours',
                                    spacing: 25.0,
                                    borderWidth: 1.0,
                                    height: 20,
                                    styleBuilder: (val) => ToggleStyle(
                                      backgroundColor: Colors.white,
                                      borderColor: Colors.grey.shade400,
                                      indicatorColor: Colors.red,
                                    ),
                                    textBuilder: (val) => Text(
                                      val,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                    iconBuilder: (val) => val == 'Full Day'
                                        ? const Icon(Icons.access_time, size: 16, color: Colors.black)
                                        : const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                                    onChanged: (val) async {
                                      setState(() {
                                        selectothers = val;
                                      });
                                      final response = await http.put(
                                        Uri.parse('${ApiConfig.baseUrl}vendor/upadatefulldayothers/${widget.id}'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({'fulldayothers': val}),
                                      );
                                      if (response.statusCode == 200) {
                                        print("Full day others mode updated successfully");
                                      } else {
                                        print("Failed to update full day others mode: ${response.body}");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Monthly Charges Container
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => addothersspaceMonthlysubscription(
                                    onEditSuccess: () {
                                      selecedIndex = 2; // Fixed typo
                                    },
                                    vendorid: widget.id,
                                  ),
                                ),
                              );
                              _refreshData();
                            },
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ColorUtils.primarycolor(),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Monthly Charges",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: monthlyothercharge.isNotEmpty
                                        ? Text(
                                      monthlyothercharge[0].amount,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    )
                                        : const Icon(Icons.add_circle, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 2,),
                // Second Container wrapped with Expanded to fit the screen width

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorHeader() {
    if (_vendor == null) {
      return _buildShimmerVendorHeader();
    }

    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.grey[300],
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (_vendor?.image != null && _vendor!.image.isNotEmpty)
                  ? NetworkImage(_vendor!.image)
                  : null,
              child: (_selectedImage == null &&
                  (_vendor == null || _vendor!.image.isEmpty))
                  ? const Icon(Icons.person, size: 30, color: Colors.black54)
                  : null,
            ),
            CircleAvatar(
              radius: 15,
              backgroundColor: ColorUtils.primarycolor(),
              child: IconButton(
                icon: const Icon(Icons.edit, size: 12, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => editspace(
                        id: widget.id,
                        vendorid: widget.vendorId,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vendor?.vendorName ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 5,
              ),
              const SizedBox(height: 3),
              Text("Address:",
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey[800])),
              const SizedBox(height: 2),
              Text(
                _vendor?.address ?? '',
                style:
                GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
                maxLines: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerVendorHeader() {
    return Row(
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Colors.grey[300],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 15,
                  width: 100,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 5),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 10,
                  width: 200,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 5),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  height: 10,
                  width: 150,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    if (_vendor == null || _vendor!.latitude.isEmpty || _vendor!.longitude.isEmpty) {
      return _buildShimmerMap();
    }

    double latitude = double.tryParse(_vendor!.latitude) ?? 0.0;
    double longitude = double.tryParse(_vendor!.longitude) ?? 0.0;

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: ColorUtils.primarycolor()),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(latitude, longitude),
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('vendor_location'),
              position: LatLng(latitude, longitude),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildShimmerMap() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(5.0),
        ),
      ),
    );
  }


  Widget _buildContent(
      String title, String totalCount, List<Category> categories) {
    return Container(
      height: 110,
      width: 110,
      decoration: BoxDecoration(
        color: ColorUtils.primarycolor(),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text(
              totalCount,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: categories
                .map((category) =>
                    buildCategoryColumn(category.name, category.count))
                .toList(),
          ),
        ],
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
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
            ),
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

  Widget buildbookedslot() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchbookedslot(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['categories'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['totalCount'];
        List<Category> categories = snapshot.data!['categories'];

        return Container(
          height: 110, // Adjust height as needed
          width: 110,
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display total count at the top
              Text(
                "Parked",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  totalCount,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(
                  height:
                      5), // Add some space between total count and categories
              // Display categories below the total count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: categories
                    .map((category) =>
                        buildCategoryColumn(category.name, category.count))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildavailableslot() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchavailableslote(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildkeletonLoader(); // Show skeleton loader
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!['categories'].isEmpty) {
          return const Text('No data available');
        }

        String totalCount = snapshot.data!['totalCount'];
        List<Category> categories = snapshot.data!['categories'];

        return Container(
          height: 110, // Adjust height as needed
          width: 110,
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display total count at the top
              Text(
                "Available ",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  totalCount,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(
                  height:
                      5), // Add some space between total count and categories
              // Display categories below the total count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: categories
                    .map((category) =>
                        buildCategoryColumn(category.name, category.count))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }


}

Widget buildCategoryColumn(String category, String count) {
  return Column(
    children: [
      Text(
        category,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    ],
  );
}

class Category {
  final String name;
  final String count;

  Category({required this.name, required this.count});

  factory Category.fromJson(String name, dynamic count) {
    return Category(
      name: name,
      count: count.toString(), // Convert count to a string
    );
  }
}

Future<Map<String, dynamic>> fetchCategories(String vendorId) async {
  try {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}vendor/fetch-slot-vendor-data/$vendorId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final List<Category> categories = [];
        data.forEach((key, value) {
          if (key != 'totalCount') {
            categories.add(Category.fromJson(key, value));
          }
        });
        return {
          'totalCount': data['totalCount'].toString(),
          'categories': categories,
        };
      } else {
        throw Exception('No categories found');
      }
    } else {
      throw Exception(
          'Failed to load categories, status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('An error occurred while fetching categories: $e');
  }
}

Future<Map<String, dynamic>> fetchbookedslot(String vendorId) async {
  try {
    final uri = Uri.parse('${ApiConfig.baseUrl}vendor/bookedslots/$vendorId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final List<Category> categories = [];
        data.forEach((key, value) {
          if (key != 'totalCount') {
            categories.add(Category.fromJson(key, value));
          }
        });
        return {
          'totalCount': data['totalCount'].toString(),
          'categories': categories,
        };
      } else {
        throw Exception('No categories found');
      }
    } else {
      throw Exception(
          'Failed to load categories, status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('An error occurred while fetching categories: $e');
  }
}

Future<Map<String, dynamic>> fetchavailableslote(String vendorId) async {
  try {
    final uri =
        Uri.parse('${ApiConfig.baseUrl}vendor/availableslots/$vendorId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final List<Category> categories = [];
        data.forEach((key, value) {
          if (key != 'totalCount') {
            categories.add(Category.fromJson(key, value));
          }
        });
        return {
          'totalCount': data['totalCount'].toString(),
          'categories': categories,
        };
      } else {
        throw Exception('No categories found');
      }
    } else {
      throw Exception(
          'Failed to load categories, status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('An error occurred while fetching categories: $e');
  }
}

class ParkingCharge {
  final String amount;
  final String type;
  final String category;

  ParkingCharge({
    required this.amount,
    required this.type,
    required this.category,
  });

  factory ParkingCharge.fromJson(Map<String, dynamic> json) {
    return ParkingCharge(
      amount: json['amount'],
      type: json['type'],
      category: json['category'],
    );
  }
}

// Model for Services
class Services {
  final String type;
  final String amount;

  Services({required this.type, required this.amount});

  factory Services.fromJson(Map<String, dynamic> json) {
    return Services(
      type: json['text'], // Assuming 'text' is the type you want
      amount: json['amount'].toString(), // Ensure amount is a string
    );
  }
}

// Model for Amenity
class Amenity {
  final String name;
  final String description;

  Amenity({required this.name, required this.description});

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      name: json['name'],
      description: json['description'] ??
          '', // Provide a default value if description is null
    );
  }
}

// Function to fetch amenities and parking services
Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
  final url =
      Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AmenitiesAndParking.fromJson(data);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    throw Exception('Error fetching data: $e');
  }
}

// Model for combined amenities and parking services
class AmenitiesAndParking {
  final List<String> amenities; // Change to List<String>
  final List<Services> services;

  AmenitiesAndParking({required this.amenities, required this.services});

  factory AmenitiesAndParking.fromJson(Map<String, dynamic> json) {
    return AmenitiesAndParking(
      amenities: List<String>.from(
        json['AmenitiesData']['amenities']
            .map((item) => item.toString()), // Convert to List<String>
      ),
      services: List<Services>.from(
        json['AmenitiesData']['parkingEntries']
            .map((item) => Services.fromJson(item)),
      ),
    );
  }
}

class Vendor {
  final String id;
  final String vendorName;
  final String vendorid;
  final String latitude;
  final String longitude;
  final String address;
  final String landMark;
  final String image;
  final String spaceid;
  final bool visibility;
  double? distance;
  final List<ParkingEntry> parkingEntries;

  Vendor({
    required this.id,
    required this.vendorName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.landMark,
    required this.image,
    required this.spaceid,
    required this.vendorid,
    required this.parkingEntries,
    required this.visibility,
    this.distance,
  });
  Vendor copyWith({
    String? id,
    String? spaceid,
    String? vendorName,
    String? address,
    String? landMark,
    String? image,
    String? vendorid,
    String? latitude,
    String? longitude,
    bool? visibility,
    List<ParkingEntry>? parkingEntries,
  }) {
    return Vendor(
      spaceid: spaceid ?? this.spaceid,
      id: id ?? this.id,
      vendorid: vendorid ?? this.vendorid,
      vendorName: vendorName ?? this.vendorName,
      address: address ?? this.address,
      landMark: landMark ?? this.landMark,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      parkingEntries: parkingEntries ?? this.parkingEntries,
      visibility: visibility ?? this.visibility,
    );
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      vendorid: json['vendorId'],
      spaceid: json['spaceid'],
      id: json['_id'],
      vendorName: json['vendorName'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      landMark: json['landMark'],
      image: json['image'],
      visibility: json['visibility'] ?? false,
      parkingEntries: (json['parkingEntries'] as List)
          .map((parkingEntryJson) => ParkingEntry.fromJson(parkingEntryJson))
          .toList(),
    );
  }
}

class ParkingEntry {
  final String type;
  int count; // Removed 'final' to make it mutable
  final String id;

  ParkingEntry({
    required this.type,
    required this.count,
    required this.id,
  });

  factory ParkingEntry.fromJson(Map<String, dynamic> json) {
    return ParkingEntry(
      type: json['type'],
      count: int.parse(json['count'].toString()), // Handle both String/int
      id: json['_id'],
    );
  }
}

class editspace extends StatefulWidget {
  final String vendorid;
  final String id;
  const editspace({
    super.key,
    required this.vendorid,
    required this.id,
    // required this.userName
  });

  @override
  _editvendorprofileState createState() => _editvendorprofileState();
}

class _editvendorprofileState extends State<editspace> {
  Vendor? _vendor;
  final bool _isEditing = false;
  bool _isLoading = false;
  List<Map<String, String>> vendor = [];
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;
  late TextEditingController _addresscontroller;
  late TextEditingController _landmarkcontroller;
  final TextEditingController noofparking = TextEditingController();
  late FocusNode _landmarkFocusNode;
  late FocusNode _addressFocusNode;

  File? _selectedImage;
  String? selectedParkingType;
  final List<String> parkingTypes = ['Bikes', 'Cars', 'Others'];
  List<Map<String, String>> parkingEntries = [];

  late List<Widget> _pagess;
  @override
  void initState() {
    super.initState();
    _isLoading = true; // Show loading indicator initially
    _fetchVendorData();
    _nameController = TextEditingController(); // Initialize controller
    _nameFocusNode = FocusNode(); // Initialize focus node
    _addresscontroller = TextEditingController();
    _addressFocusNode = FocusNode();
    _landmarkcontroller = TextEditingController();
    _landmarkFocusNode = FocusNode();
  }



  Future<void> _fetchVendorData() async {
    try {
      // Construct the full URL
      final String apiUrl = '${ApiConfig.baseUrl}vendor/fetchspacedata?vendorId=${widget.id}';

      // Print the full API URL
      print('Fetching vendor data from URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      print('Response status code: ${response.statusCode}'); // Print response status

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('Response data: $data'); // Print the response data

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _nameController.text = _vendor?.vendorName ?? ''; // Set controller text
            _addresscontroller.text = _vendor?.address ?? '';
            _landmarkcontroller.text = _vendor?.landMark ?? '';
            _isLoading = false; // Hide loading indicator after data is fetched
          });
          print('Vendor data fetched successfully: ${_vendor?.vendorName}');
        } else {
          print('No vendor data found in response.');
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        print('Failed to load vendor data, status code: ${response.statusCode}');
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching vendor data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVendorProfile() async {
    if (_nameController.text.isEmpty || _addresscontroller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/updatespace/${widget.id}');
      var request = http.MultipartRequest('PUT', url); // Change to POST for file upload

      // Add text fields
      request.fields['vendorName'] = _nameController.text;
      request.fields['address'] = _addresscontroller.text;
      request.fields['landmark'] = _landmarkcontroller.text;
      request.fields['latitude'] = _vendor?.latitude ?? '';
      request.fields['longitude'] = _vendor?.longitude ?? '';

      // Add image if selected
      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image', // The field name expected by the API
          _selectedImage!.path,
          contentType: MediaType('image', 'jpeg'), // Ensure proper MIME type
        ));
      }

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vendor profile updated successfully")),
        );
        print("Vendor profile updated successfully");
      } else {
        print("Failed to update vendor profile, status: ${response.statusCode}");
        final responseBody = await response.stream.bytesToString();
        print("Error response: $responseBody");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $responseBody')),
        );
      }
    } catch (error) {
      print("Error occurred: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  List<String> getAvailableParkingTypes() {
    // Create a set of already added parking types
    final addedParkingTypes =
        _vendor?.parkingEntries.map((entry) => entry.type).toSet() ?? {};

    // Filter the parkingTypes list to exclude already added types
    return parkingTypes
        .where((type) => !addedParkingTypes.contains(type))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Edit Space details',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator()) // Show loading indicator
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle Avatar with Person Icon
                    Align(
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (_vendor?.image.isNotEmpty ?? false
                                    ? NetworkImage(_vendor!.image)
                                    : null),
                            child: _selectedImage == null &&
                                    (_vendor?.image.isEmpty ?? true)
                                ? const Icon(Icons.person,
                                    size: 34, color: Colors.black54)
                                : null,
                          ),
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: ColorUtils.primarycolor(),
                            child: IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 12, color: Colors.white),

                              onPressed:
                                  _selectImage, // Select image from gallery
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
// Text(widget.vendorid),
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          profileCustomTextField(
                            inputFormatter: const [],
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            keyboard: TextInputType.text,
                            obscure: false,
                            textInputAction: TextInputAction.next,
                            label: 'Name',
                            hint: 'Please enter your Name',
                          ),
                          // SizedBox(height: 15),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () async {
                              final selectedData = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditMapScreen(
                                    initialPosition: LatLng(
                                      double.tryParse(
                                              _vendor?.latitude ?? '0') ??
                                          0.0,
                                      double.tryParse(
                                              _vendor?.longitude ?? '0') ??
                                          0.0,
                                    ),
                                  ),
                                ),
                              );

                              if (selectedData != null) {
                                setState(() {
                                  _vendor = _vendor?.copyWith(
                                    latitude: selectedData['latitude'],
                                    longitude: selectedData['longitude'],
                                    address: selectedData['address'],
                                    landMark: selectedData['landmark'],
                                  );

                                  _addresscontroller.text =
                                      selectedData['address'];
                                  _landmarkcontroller.text =
                                      selectedData['landmark'];
                                });
                              }
                            },
                            child: Row(
                              children: [
                                Container(
                                  child: Text(
                                    "Location details",
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  width: 18, // Reduced width
                                  height: 18, // Reduced height
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.black,
                                    size: 16, // Reduced icon size
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Container(
                              width: double.infinity, // Use full width
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: ColorUtils.primarycolor(),
                                ),
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      double.tryParse(
                                              _vendor?.latitude ?? '0') ??
                                          0.0, // Convert latitude to double
                                      double.tryParse(
                                              _vendor?.longitude ?? '0') ??
                                          0.0,
                                    ),
                                    zoom: 15,
                                  ),
                                  onMapCreated:
                                      (GoogleMapController controller) {
                                    // Additional setup can be done here if needed
                                  },
                                  markers: {
                                    Marker(
                                      markerId:
                                          const MarkerId('vendor_location'),
                                      position: LatLng(
                                        double.tryParse(
                                                _vendor?.latitude ?? '0') ??
                                            0.0, // Convert latitude to double
                                        double.tryParse(
                                                _vendor?.longitude ?? '0') ??
                                            0.0,
                                      ),
                                    ),
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          profileCustomTextField(
                            inputFormatter: const [],
                            controller: _addresscontroller,
                            focusNode: _addressFocusNode,
                            keyboard: TextInputType.text,
                            obscure: false,
                            textInputAction: TextInputAction.next,
                            label: 'Address',
                            hint: 'Please enter your Address',
                          ),
                          const SizedBox(height: 15),
                          profileCustomTextField(
                            inputFormatter: const [],
                            controller: _landmarkcontroller,
                            focusNode: _landmarkFocusNode,
                            keyboard: TextInputType.text,
                            obscure: false,
                            textInputAction: TextInputAction.next,
                            label: 'Landmark',
                            hint: 'Please enter your Landmark',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    const SizedBox(height: 10),


                    Row(
                      mainAxisAlignment: MainAxisAlignment
                          .end, // Aligns the button to the right
                      children: [
                        ElevatedButton(
                          onPressed: _updateVendorProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primarycolor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 15.0),
                          ),
                          child: const Text('Update Profile'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

}
