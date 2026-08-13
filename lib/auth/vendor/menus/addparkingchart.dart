import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';


import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class addcarminimumcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcarminimumcharge({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcarminimumchargeState createState() => _addcarminimumchargeState();
}
class _addcarminimumchargeState extends State<addcarminimumcharge> {
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
    return  _isLoading
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ), );
  }
}
class addbikeminimumcharge extends StatefulWidget {
  final String vendorid;
  // Add this line
  final Function onEditSuccess;
  const addbikeminimumcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addbikeminimumchargeState createState() => _addbikeminimumchargeState();
}
class _addbikeminimumchargeState extends State<addbikeminimumcharge>with SingleTickerProviderStateMixin  {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}

class addothersminimumcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersminimumcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addothersminimumchargeState createState() => _addothersminimumchargeState();
}
class _addothersminimumchargeState extends State<addothersminimumcharge> {
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
    return Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(crossAxisAlignment: CrossAxisAlignment.start,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}


class addcaradditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcaradditionalcharge({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcaradditionalchargeState createState() => _addcaradditionalchargeState();
}
class _addcaradditionalchargeState extends State<addcaradditionalcharge> {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addbikeadditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikeadditionalcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,

  });

  @override
  _addbikeadditionalchargeState createState() => _addbikeadditionalchargeState();
}
class _addbikeadditionalchargeState extends State<addbikeadditionalcharge> {
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
    return Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Column(crossAxisAlignment: CrossAxisAlignment.start,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ), );
  }
}
class addothersadditionalcharge extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersadditionalcharge({super.key,
    required this.vendorid,
    required this.onEditSuccess,
  });

  @override
  _addothersadditionalchargeState createState() => _addothersadditionalchargeState();
}
class _addothersadditionalchargeState extends State<addothersadditionalcharge> {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}




class addcarfullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addcarfullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addcarfulldayState createState() => _addcarfulldayState();
}
class _addcarfulldayState extends State<addcarfullday> {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addbikefullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikefullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addbikefulldayState createState() => _addbikefulldayState();
}
class _addbikefulldayState extends State<addbikefullday> {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addothersfullday extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersfullday({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addothersfulldayState createState() => _addothersfulldayState();
}
class _addothersfulldayState extends State<addothersfullday> {
  bool _isLoading = false;


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
    // print("Available parking types: $uniqueParkingTypes");

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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addMonthlysubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addMonthlysubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addMonthlysubscriptionState createState() => _addMonthlysubscriptionState();
}
class _addMonthlysubscriptionState extends State<addMonthlysubscription> {
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addbikeMonthlysubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addbikeMonthlysubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addbikeMonthlysubscriptionState createState() => _addbikeMonthlysubscriptionState();
}
class _addbikeMonthlysubscriptionState extends State<addbikeMonthlysubscription> {
  bool _isLoading = false;

  // final String _selectedOption = 'Bike';
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class addothersMonthlysubscription extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const addothersMonthlysubscription({super.key,
    required this.vendorid, required this.onEditSuccess,

  });

  @override
  _addothersMonthlysubscriptionState createState() => _addothersMonthlysubscriptionState();
}
class _addothersMonthlysubscriptionState extends State<addothersMonthlysubscription> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("FPlease check your slot availability")),
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
    return Scaffold(backgroundColor: Colors.white,
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

      body: SafeArea(
        child: SingleChildScrollView(
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





      ),);
  }
}
class AddDurationChargePage extends StatefulWidget {
  final String vendorid;
  final String category;
  final String durationLabel;
  final String chargeId;
  final Function onEditSuccess;

  const AddDurationChargePage({
    super.key,
    required this.vendorid,
    required this.category,
    required this.durationLabel,
    required this.chargeId,
    required this.onEditSuccess,
  });

  @override
  _AddDurationChargePageState createState() => _AddDurationChargePageState();
}

class _AddDurationChargePageState extends State<AddDurationChargePage> {
  bool _isLoading = false;
  final TextEditingController amount = TextEditingController();
  List<Map<String, dynamic>> charges = [];

  @override
  void initState() {
    super.initState();
    fetchDurationCharge();
  }

  Future<void> fetchDurationCharge() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/getchargesbycategoryandtype/${widget.vendorid}/${widget.category}/${widget.chargeId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          charges = List<Map<String, dynamic>>.from(data['charges'] ?? []);
          if (charges.isNotEmpty) {
            amount.text = charges[0]['amount']?.toString() ?? '';
          }
        });
      }
    } catch (e) {
      print("Error fetching duration charge: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCharges() async {
    if (_isLoading) return;

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
      final body = {
        'vendorid': widget.vendorid,
        'charges': [
          {
            'type': widget.durationLabel,
            'amount': amount.text,
            'category': widget.category,
            'chargeid': widget.chargeId,
          }
        ],
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/addparkingcharges'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Charges updated successfully")),
        );
        widget.onEditSuccess();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update charges")),
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

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingGif()
        : Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              titleSpacing: 0,
              backgroundColor: ColorUtils.secondarycolor(),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add ${widget.durationLabel} Charge',
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                  Text(
                    'Kindly add amount exclusive of GST*',
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                  ),
                ],
              ),
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: 'Enter amount for ${widget.durationLabel}',
                          labelStyle: GoogleFonts.poppins(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton.icon(
                          onPressed: _submitCharges,
                          icon: const Icon(Icons.update, color: Colors.white),
                          label: const Text("Update Charges"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: ColorUtils.primarycolor(),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}
