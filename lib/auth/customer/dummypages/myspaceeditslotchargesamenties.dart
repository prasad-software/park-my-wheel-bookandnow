import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mywheels/config/authconfig.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import '../../../config/colorcode.dart';

class editslotuserspace extends StatefulWidget {
  final String vendorid;
  const editslotuserspace({super.key, required this.vendorid});

  @override
  _EditslotssState createState() => _EditslotssState();
}

class _EditslotssState extends State<editslotuserspace> {
  Vendor? _vendor;
  bool _isLoading = false;
  List<Map<String, String>> vendor = [];
  late TextEditingController _nameController;
  final TextEditingController noofparking = TextEditingController();
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
  }

  void _addParkingEntry() {
    if (selectedParkingType == null || noofparking.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select parking type and enter number of parking spots")),
      );
      return;
    }

    bool isTypeAlreadyAdded = parkingEntries.any((entry) => entry['type'] == selectedParkingType);

    if (isTypeAlreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This parking type has already been added")),
      );
      return;
    }

    setState(() {
      // Add new parking entry to the list
      parkingEntries.add({
        'type': selectedParkingType!,
        'count': noofparking.text,
      });


      // Also add the entry to _vendor's parkingEntries
      _vendor?.parkingEntries.add(ParkingEntry(type: selectedParkingType!, count: noofparking.text));

      // Clear input fields
      noofparking.clear();
      selectedParkingType = null;
    });

    // Call _updateVendorProfile to send the new data to the API
    _updateVendorProfile();
  }
  Future<void> _fetchVendorData() async {
    try {
      final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}vendor/fetch-vendor-data?id=${widget.vendorid}')
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['data'] != null) {
          setState(() {
            _vendor = Vendor.fromJson(data['data']);
            _nameController.text = _vendor?.vendorName ?? ''; // Set controller text

            _isLoading = false; // Hide loading indicator after data is fetched
          });
        } else {
          throw Exception(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        throw Exception('Failed to load vendor data, status code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load vendor data. Please try again later.')),
      );
      setState(() {
        _isLoading = false; // Hide loading indicator if there's an error
      });
    }
  }

  Future<void> _updateVendorProfile() async {
    // Add the unadded parking entry directly from the input fields
    if (selectedParkingType != null && noofparking.text.isNotEmpty) {
      parkingEntries.add({
        'type': selectedParkingType!,
        'count': noofparking.text,
      });

      _vendor?.parkingEntries.add(ParkingEntry(type: selectedParkingType!, count: noofparking.text));
    }

    // Merge parking entries
    final List<Map<String, String>> mergedParkingEntries = [
      ..._vendor?.parkingEntries.map((entry) => {
        'type': entry.type,
        'count': entry.count,
      }).toList() ?? [],
      ...parkingEntries.map((entry) => {
        'type': entry['type']!,
        'count': entry['count']!,
      }),
    ];

    // Ensure unique entries by type
    final Map<String, String> uniqueParkingEntries = {};
    for (var entry in mergedParkingEntries) {
      final type = entry['type'] ?? 'Unknown Type';
      final count = entry['count'] ?? '0';
      uniqueParkingEntries[type] = count;
    }

    final Map<String, dynamic> vendorData = {
      'parkingEntries': uniqueParkingEntries.entries.map((e) => {
        'type': e.key,
        'count': e.value,
      }).toList(),
    };

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/updatevendor/${widget.vendorid}');
      print("Request URL: $url");
      print("Request Body: $vendorData"); // Print the request body to verify data

      final headers = {'Content-Type': 'application/json'};
      final body = json.encode(vendorData);

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        print("Vendor profile updated successfully");
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Slot data updated successfully")),
        );
        _fetchVendorData(); // Refresh vendor data after update
      } else {
        final responseBody = json.decode(response.body);
        print("Error response: $responseBody");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update vendor profile: ${responseBody['message']}')),
        );
      }
    } catch (error) {
      print("Error occurred: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  List<String> getAvailableParkingTypes() {
    // Create a set of already added parking types
    final addedParkingTypes = _vendor?.parkingEntries.map((entry) => entry.type).toSet() ?? {};

    // Filter the parkingTypes list to exclude already added types
    final uniqueParkingTypes = parkingTypes.toSet(); // Using a set to ensure uniqueness

    // Ensure the result doesn't contain any duplicates and exclude types that are already added
    return uniqueParkingTypes
        .where((type) => !addedParkingTypes.contains(type))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.black), // Custom back icon
        //   onPressed: () {
        //     Navigator.pushReplacement(
        //       context,
        //       MaterialPageRoute(builder: (context) => Third(vendorid: widget.vendorid)),
        //     ); // Navigate back
        //   },
        // ),
        title:  Text(
          'Edit Slots',
          style:   GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _vendor?.parkingEntries.length ?? 0,
                itemBuilder: (context, index) {
                  final parkingEntry = _vendor!.parkingEntries[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              initialValue: parkingEntry.type,
                              readOnly: true,
                              style:   GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Parking Type',
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                                labelStyle:   GoogleFonts.poppins(color: Colors.black),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                // Limit the length to 10 digits
                                LengthLimitingTextInputFormatter(10),
                              ],
                              initialValue: parkingEntry.count,
                              style:   GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'No of Parking',
                                labelStyle:   GoogleFonts.poppins(color: Colors.black),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  parkingEntry.count = value; // Update value when changed
                                  // Update the corresponding entry in the _vendor object
                                  _vendor?.parkingEntries[index].count = value;
                                });
                                _updateVendorProfile(); // Update vendor profile automatically
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          height: 40,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(5),
                              bottomRight: Radius.circular(5),
                            ),
                            color: Colors.redAccent,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                if (_vendor?.parkingEntries.isNotEmpty ?? false && index < _vendor!.parkingEntries.length) {
                                  // Remove the item from the vendor's parkingEntries
                                  _vendor?.parkingEntries.removeAt(index);

                                  // Remove it from the local parkingEntries list
                                  if (index < parkingEntries.length) {
                                    parkingEntries.removeAt(index);
                                  }
                                }
                              });

                              // Optionally, update the vendor profile to reflect the changes
                              _updateVendorProfile();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Parking Type',
                          labelStyle:   GoogleFonts.poppins(
                            color: ColorUtils.primarycolor(),
                            fontSize: 12,
                          ),
                          hintText: 'parkingtype',
                          hintStyle:  GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                          ),
                        ),
                        value: selectedParkingType,  // This must be a single valid value
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedParkingType = newValue;
                          });
                        },
                        items: getAvailableParkingTypes().map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: noofparking,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'No of Parking',
                          hintText: 'Enter number of parking',
                          labelStyle:   GoogleFonts.poppins(color: Colors.black),
                          hintStyle:   GoogleFonts.poppins(color: Colors.black),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5,),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(), width: 0.5,),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color:ColorUtils.primarycolor(), width: 0.5,),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                      ),
                      color: ColorUtils.primarycolor(), // Set the container's background color to primary color
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      color: Colors.white,
                      onPressed: _addParkingEntry,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end, // Aligns the button to the right
                children: [
                  ElevatedButton(
                    onPressed: _updateVendorProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor(),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.zero, // Remove extra padding
                      minimumSize: const Size(90, 25), // Set custom width and height
                    ),
                    child: const Text('Update slots', style: TextStyle(fontSize: 14)), // Adjust text size if needed
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

class Vendor {
  String vendorName;
  List<ParkingEntry> parkingEntries;

  Vendor({required this.vendorName, required this.parkingEntries});

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      vendorName: json['vendorName'],
      parkingEntries: (json['parkingEntries'] as List)
          .map((entry) => ParkingEntry.fromJson(entry))
          .toList(),
    );
  }
}

class ParkingEntry {
  String type;
  String count;

  ParkingEntry({required this.type, required this.count});

  factory ParkingEntry.fromJson(Map<String, dynamic> json) {
    return ParkingEntry(
      type: json['type'],
      count: json['count'],
    );
  }
}

class addcarspaceminimumcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcarspaceminimumcharge({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcarminimumchargeState createState() => _addcarminimumchargeState();
}
class _addcarminimumchargeState extends State<addcarspaceminimumcharge> {
  bool _isLoading = false;

  final String _selectedOption = 'Car';
  List<Map<String, String>> parkingEntries = [];
  List<Map<String, dynamic>> charges = [];
  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    '0 to 1 hour',
    '0 to 2 hours',
    '0 to 3 hours',
    '0 to 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;

    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      parkingEntries.add({
        'type': selectedParkingType!,
        'amount': amount.text,
        'category': "Car",
        'chargeid': "A",
      });
      amount.clear();
      selectedParkingType = null;

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess();
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    return [
      '0 to 1 hour',
      '0 to 2 hours',
      '0 to 3 hours',
      '0 to 4 hours',
    ];
  }
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Car/A');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Minimum Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [

// Text(widget.vendorid),
              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 2.0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: const BoxDecoration(
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                      //     offset: const Offset(0, 4), // Offset in x and y direction
                      //     blurRadius: 6, // Blur radius for the shadow
                      //   ),
                      // ],
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                        : ElevatedButton.icon(
                      onPressed: _submitCharges, // Disable button if loading
                      icon: const Icon(Icons.read_more,color: Colors.white,),
                      label: const Text("Add Charges"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, // Text color
                        backgroundColor: ColorUtils.primarycolor(), // Button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5), // Circular border radius
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}


class addbikespaceminimumcharge extends StatefulWidget {
  final String vendorid;
  // Add this line
  final Function onEditSuccess;
  const addbikespaceminimumcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addbikeminimumchargeState createState() => _addbikeminimumchargeState();
}
class _addbikeminimumchargeState extends State<addbikespaceminimumcharge>with SingleTickerProviderStateMixin  {
  bool _isLoading = false;

  final String _selectedOption = 'Bike';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    '0 to 1 hour',
    '0 to 2 hours',
    '0 to 3 hours',
    '0 to 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Bike",
          'chargeid': "E",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );

        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);


        // Switch to the second tab

        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);

  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Bike/E');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Minimum Charge',
                  style:  GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:  GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}

class addothersspaceminimumcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersspaceminimumcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addothersminimumchargeState createState() => _addothersminimumchargeState();
}
class _addothersminimumchargeState extends State<addothersspaceminimumcharge> {
  bool _isLoading = false;

  final String _selectedOption = 'Others';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    '0 to 1 hour',
    '0 to 2 hours',
    '0 to 3 hours',
    '0 to 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Others",
          'chargeid': "I",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Others/I');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Minimum Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:  GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:  GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:  GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}


class addcarspaceadditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcarspaceadditionalcharge({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcaradditionalchargeState createState() => _addcaradditionalchargeState();
}
class _addcaradditionalchargeState extends State<addcarspaceadditionalcharge> {
  bool _isLoading = false;

  final String _selectedOption = 'Car';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes =[
    'Additional 1 hour',
    'Additional 2 hours',
    'Additional 3 hours',
    'Additional 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Car",
          'chargeid': "B",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        // This will trigger the parent to navigate to the third tab
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);


        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Car/B');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Additional Charge',
                  style:  GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:  GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addbikespaceadditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikespaceadditionalcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addbikeadditionalchargeState createState() => _addbikeadditionalchargeState();
}
class _addbikeadditionalchargeState extends State<addbikespaceadditionalcharge> {
  bool _isLoading = false;

  final String _selectedOption = 'Bike';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Additional 1 hour',
    'Additional 2 hours',
    'Additional 3 hours',
    'Additional 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Bike",
          'chargeid': "F",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }

  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Bike/F');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Additional Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addothersspaceadditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersspaceadditionalcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,
  });

  @override
  _addothersadditionalchargeState createState() => _addothersadditionalchargeState();
}
class _addothersadditionalchargeState extends State<addothersspaceadditionalcharge> {
  bool _isLoading = false;

  final String _selectedOption = 'Others';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Additional 1 hour',
    'Additional 2 hours',
    'Additional 3 hours',
    'Additional 4 hours',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Others",
          'chargeid': "J",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }

  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Others/J');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Additional Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:  GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addcarspacefullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcarspacefullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcarfulldayState createState() => _addcarfulldayState();
}
class _addcarfulldayState extends State<addcarspacefullday> {
  bool _isLoading = false;

  final String _selectedOption = 'Car';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Full day',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Car",
          'chargeid': "C",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    selectedParkingType = 'Full day';
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Car/C');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Full day Charge',
                  style:  GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addbikespacefullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikespacefullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addbikefulldayState createState() => _addbikefulldayState();
}
class _addbikefulldayState extends State<addbikespacefullday> {
  bool _isLoading = false;

  final String _selectedOption = 'Bike';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Full day',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Bike",
          'chargeid': "G",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }

  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    selectedParkingType = 'Full day';
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Bike/G');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Full day Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addothersspacefullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersspacefullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addothersfulldayState createState() => _addothersfulldayState();
}
class _addothersfulldayState extends State<addothersspacefullday> {
  bool _isLoading = false;

  final String _selectedOption = 'Others';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Full day',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Others",
          'chargeid': "K",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }

  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    selectedParkingType = 'Full day';
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Others/K');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Full day Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addMonthlyspacesubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addMonthlyspacesubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addMonthlysubscriptionState createState() => _addMonthlysubscriptionState();
}
class _addMonthlysubscriptionState extends State<addMonthlyspacesubscription> {
  bool _isLoading = false;

  final String _selectedOption = 'Car';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Monthly',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Car",
          'chargeid': "D",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please check your slot availability")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    selectedParkingType = 'Monthly';
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Car/D');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Monthly Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addbikespaceMonthlysubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikespaceMonthlysubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addbikeMonthlysubscriptionState createState() => _addbikeMonthlysubscriptionState();
}
class _addbikeMonthlysubscriptionState extends State<addbikespaceMonthlysubscription> {
  bool _isLoading = false;

  final String _selectedOption = 'Bike';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Monthly',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Bike",
          'chargeid': "H",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Please check your slot availability")),
        // );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }

  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    // Call fetchParkingCharges on init
    fetchParkingCharges(widget.vendorid);
    selectedParkingType = 'Monthly';
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Bike/H');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :  Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Monthly Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:  GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}
class addothersspaceMonthlysubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersspaceMonthlysubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addothersMonthlysubscriptionState createState() => _addothersMonthlysubscriptionState();
}
class _addothersMonthlysubscriptionState extends State<addothersspaceMonthlysubscription> {
  bool _isLoading = false;

  final String _selectedOption = 'Others';
  List<Map<String, String>> parkingEntries = [];

  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;
  final List<String> parkingTypes = [
    'Monthly',
  ];

  Future<void> _submitCharges() async {
    if (_isLoading) return;
    if (selectedParkingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a parking type")),
      );
      return;
    }

    if (amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedParkingType != null && amount.text.isNotEmpty) {
        parkingEntries.add({
          'type': selectedParkingType!,
          'amount': amount.text,
          'category': "Others",
          'chargeid': "L",
        });
        amount.clear();
        selectedParkingType = null;
      }

      final body = {
        'vendorid': widget.vendorid,
        'charges': parkingEntries,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges added successfully")),
        );
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        setState(() {
          parkingEntries.clear();
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Please check your slot availability")),
        // );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableParkingTypes() {
    // Ensure uniqueness of parking types by converting to a Set first
    List<String> uniqueParkingTypes = parkingTypes.toSet().toList();

    // Filter out types that have already been used in parkingEntries
    uniqueParkingTypes = uniqueParkingTypes.where((type) {
      return !parkingEntries.any((entry) => entry['type'] == type);
    }).toList();

    // Print the available parking types for debugging
    print("Available parking types: $uniqueParkingTypes");

    return uniqueParkingTypes;
  }
  List<Map<String, dynamic>> charges = [];
  @override
  void initState() {
    super.initState();
    selectedParkingType = 'Monthly';
    fetchParkingCharges(widget.vendorid);
  }


  Future<void> fetchParkingCharges(String vendorId) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/$vendorId/Others/L');

    print("Fetching parking charges from: $url");

    try {
      final response = await http.get(url);

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Parsed data: $data");

        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges']);
          print("Charges list: $charges");

          if (charges.isNotEmpty) {
            final parkingTypes = _getAvailableParkingTypes();
            print("Available parking types: $parkingTypes");

            selectedParkingType = parkingTypes.contains(charges[0]['type']) ? charges[0]['type'] : null;
            print("Selected parking type: $selectedParkingType");

            amount.text = charges[0]['amount']?.toString() ?? '';
            print("Amount text: ${amount.text}");
          } else {
            print("No charges found.");
          }
        });
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Failed to fetch charges: ${response.body}")),
        // );
      }
    } catch (e) {
      print("Error during fetch: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Error fetching charges: $e")),
      // );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        : Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Monthly Charge',
                  style:   GoogleFonts.poppins(color: Colors.black),
                ),
                Text(
                  'Kindly add the amount exclusive of GST*',
                  style:   GoogleFonts.poppins(color:Colors.red,
                      fontSize: 14),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [


              // Subscription Radio Button

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle:   GoogleFonts.poppins(
                          color: ColorUtils.primarycolor(),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        hintStyle:   GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        hintText: 'Select type',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                      value: selectedParkingType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedParkingType = newValue;
                        });
                      },
                      items: _getAvailableParkingTypes().map((String parkingType) {
                        return DropdownMenuItem<String>(
                          value: parkingType,
                          child: Text(
                            parkingType,
                            style:   GoogleFonts.poppins(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 2),

                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Amount',
                        labelStyle:   GoogleFonts.poppins(color: Colors.black),
                        hintStyle:   GoogleFonts.poppins(color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ColorUtils.primarycolor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),


                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                        offset: const Offset(0, 4), // Offset in x and y direction
                        blurRadius: 6, // Blur radius for the shadow
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                      : ElevatedButton.icon(
                    onPressed: _submitCharges, // Disable button if loading
                    icon: const Icon(Icons.read_more,color: Colors.white,),
                    label: const Text("Add Charges"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Text color
                      backgroundColor: ColorUtils.primarycolor(), // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // Circular border radius
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),





    );
  }
}