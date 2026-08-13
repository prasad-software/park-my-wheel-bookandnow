import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/vendor/vendorbottomnav/thirdpage.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import '../../../config/colorcode.dart';

class Editslotss extends StatefulWidget {
  final String vendorid;
  const Editslotss({super.key, required this.vendorid});

  @override
  _EditslotssState createState() => _EditslotssState();
}

class _EditslotssState extends State<Editslotss> {
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Third(vendorid: widget.vendorid,),
          ),
        );
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
    return  _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Custom back icon
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Third(vendorid: widget.vendorid)),
            ); // Navigate back
          },
        ),
        title:  Text(
          'Edit Slots',
          style:   GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
          child: Image.asset('assets/gifload.gif',),
        ),
      ) // Show loading indicator
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
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
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
                        const SizedBox(width: 5),
                        Container(
                          height: 50,
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
                  const SizedBox(width: 5),
                  Expanded(
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
                  const SizedBox(width: 5),
                  Container(
                    height: 50,
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
              const SizedBox(height: 10),
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
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                    ),
                    child: const Text('Update slots'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),   );
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