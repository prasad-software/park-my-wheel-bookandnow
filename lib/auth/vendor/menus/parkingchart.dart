import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';
import 'package:tab_container/tab_container.dart';
import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';


import 'package:http/http.dart' as http;

import 'addparkingchart.dart';

class listmParkingLotScreen extends StatefulWidget {
  final String vendorid;
  final Function? onSuccess; // Add this line
  final TabController? tabController; // Add this line

  const listmParkingLotScreen({super.key,
    required this.vendorid,  this.onSuccess,
    this.tabController,
  });
  @override
  _listParkingLotScreenState createState() => _listParkingLotScreenState();
}
class _listParkingLotScreenState extends State<listmParkingLotScreen>with SingleTickerProviderStateMixin {
  List<ParkingCharge> charges = [];
  List<ParkingbikeCharge> chargess = [];
  List<ParkingotherCharge> chargesss = [];
  bool isLoading = true;
  int selectedIndex = 0;
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

  final List<String> fullday = [

    'Full day'];
  final List<String> monthly = [

    'Monthly'];
  Future<void> fetchMinimumCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching data from: $url'); // Print the URL
      final response = await http.get(url);
      print('Response status: ${response.statusCode}'); // Print response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print raw data

        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found'); // Confirm vendor charges are found
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges'].map((item) => ParkingCharge.fromJson(item)),
          );

          print('Total charges fetched: ${charges.length}'); // Print total charges count

          setState(() {
            minimumCharges = charges
                .where((charge) => charge.category == 'Car' && parkingTypes.contains(charge.type))
                .toList();
            print('Filtered charges: $minimumCharges'); // Print filtered charges
          });
        } else {
          print('No charges found in vendor data'); // Log if no charges exist
          showSnackBar("No minimum charges found");
        }
      } else {
        print('Failed to load charges. Status code: ${response.statusCode}'); // Log failure
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
  Future<void> fetchbikeMinimumCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching data from: $url'); // Print the URL
      final response = await http.get(url);
      print('Response status: ${response.statusCode}'); // Print response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print raw data

        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found'); // Confirm vendor charges are found
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges'].map((item) => ParkingbikeCharge.fromJson(item)),
          );

          print('Total charges fetched: ${chargess.length}'); // Print total charges count

          setState(() {
            minimumbikeCharges = chargess
                .where((charges) => charges.category == 'Bike' && parkingTypes.contains(charges.type))
                .toList();
            print('Filtered charges: $minimumbikeCharges'); // Print filtered charges
          });
        } else {
          print('No charges found in vendor data'); // Log if no charges exist
          showSnackBar("No minimum charges found");
        }
      } else {
        print('Failed to load charges. Status code: ${response.statusCode}'); // Log failure
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      print('Fetching data from: $url'); // Print the URL
      final response = await http.get(url);
      print('Response status: ${response.statusCode}'); // Print response status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Response data: $data'); // Print raw data

        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          print('Vendor charges found'); // Confirm vendor charges are found
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges'].map((item) => ParkingotherCharge.fromJson(item)),
          );

          print('Total charges fetched: ${chargesss.length}'); // Print total charges count

          setState(() {
            minimumotherCharges = chargesss
                .where((charges) => charges.category == 'Others' && parkingTypes.contains(charges.type))
                .toList();
            print('Filtered charges: $minimumbikeCharges'); // Print filtered charges
          });
        } else {
          print('No charges found in vendor data'); // Log if no charges exist
          showSnackBar("No minimum charges found");
        }
      } else {
        print('Failed to load charges. Status code: ${response.statusCode}'); // Log failure
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges'].map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            additionalCharges = charges
                .where((charge) => charge.category == 'Car' && addcharge.contains(charge.type))
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
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges'].map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            additionalbikeCharges = chargess
                .where((charge) => charge.category == 'Bike' && addcharge.contains(charge.type))
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
  Future<void> fetchotherAdditionalCharge(String vendorId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges'].map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            additionalotherCharges = chargesss
                .where((charge) => charge.category == 'Others' && addcharge.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges'].map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            fulldaycharge = charges
                .where((charge) => charge.category == 'Car' && fullday.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges'].map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            fulldaybikecharge = chargess
                .where((charge) => charge.category == 'Bike' && fullday.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges'].map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            fulldayothercharge = chargesss
                .where((charge) => charge.category == 'Others' && fullday.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingCharge> charges = List<ParkingCharge>.from(
            data['vendor']['charges'].map((item) => ParkingCharge.fromJson(item)),
          );

          setState(() {
            monthlycharge = charges
                .where((charge) => charge.category == 'Car' && monthly.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingbikeCharge> chargess = List<ParkingbikeCharge>.from(
            data['vendor']['charges'].map((item) => ParkingbikeCharge.fromJson(item)),
          );

          setState(() {
            monthlybikecharge = chargess
                .where((charge) => charge.category == 'Bike' && monthly.contains(charge.type))
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
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['vendor'] != null && data['vendor']['charges'] != null) {
          List<ParkingotherCharge> chargesss = List<ParkingotherCharge>.from(
            data['vendor']['charges'].map((item) => ParkingotherCharge.fromJson(item)),
          );

          setState(() {
            monthlyothercharge = chargesss
                .where((charge) => charge.category == 'Others' && monthly.contains(charge.type))
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<List<ParkingCharge>> fetchParkingCharges(String vendorId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getchargesdata/$vendorId'); // Replace with your actual API URL

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
            data['vendor']['charges'].map((item) => ParkingCharge.fromJson(item)),
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

  late  TabController _controller;
  int selectedTabIndex = 0;
  @override
  void initState() {
    super.initState();

    _controller = TabController(vsync: this, length: 3);
    _controller.addListener(() {
      setState(() {
        refreshData();
        selectedTabIndex = _controller.index;
      });
    });
    fetchMinimumCharge(widget.vendorid);
    fetchAdditionalCharge(widget.vendorid);
    fetchfulldaycar(widget.vendorid);
    fetchfulldaymonthly(widget.vendorid);
    fetchbikeMinimumCharge(widget.vendorid);
    fetchbikeAdditionalCharge(widget.vendorid);
    fetchbikefulldaycar(widget.vendorid);
    fetchbikefulldaymonthly(widget.vendorid);
    fetchotherMinimumCharge(widget.vendorid);
    fetchotherAdditionalCharge(widget.vendorid);
    fetchotherfulldaycar(widget.vendorid);
    fetchotherfulldaymonthly(widget.vendorid);
    // Call the fetch function here to load data when the screen is initialized.
    fetchParkingCharges(widget.vendorid).then((fetchedCharges) {
      setState(() {
        charges = fetchedCharges;
        isLoading = false; // Update to stop loading spinner
      });
    }).catchError((e) {
      print('Error fetching charges: $e');
      setState(() {
        isLoading = false; // Stop loading spinner even on error
      });
    });
  }
  void refreshData() {
    switch (selectedTabIndex) {
      case 0:
        fetchMinimumCharge(widget.vendorid);
        fetchAdditionalCharge(widget.vendorid);
        fetchfulldaycar(widget.vendorid);
        fetchfulldaymonthly(widget.vendorid);
        fetchbikeMinimumCharge(widget.vendorid);
        fetchbikeAdditionalCharge(widget.vendorid);
        fetchbikefulldaycar(widget.vendorid);
        fetchbikefulldaymonthly(widget.vendorid);
        fetchotherMinimumCharge(widget.vendorid);
        fetchotherAdditionalCharge(widget.vendorid);
        fetchotherfulldaycar(widget.vendorid);
        fetchotherfulldaymonthly(widget.vendorid);
        break;
      case 1:
        fetchbikeMinimumCharge(widget.vendorid);
        fetchbikeAdditionalCharge(widget.vendorid);
        fetchbikefulldaycar(widget.vendorid);
        fetchbikefulldaymonthly(widget.vendorid);
        break;
      case 2:
        fetchotherMinimumCharge(widget.vendorid);
        fetchotherAdditionalCharge(widget.vendorid);
        fetchotherfulldaycar(widget.vendorid);
        fetchotherfulldaymonthly(widget.vendorid);
        break;
    }
  }
  @override
  Widget build(BuildContext context) {


    return  isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(backgroundColor: Colors.white,

      appBar: AppBar(titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(
          'Charge Sheet',
          style:   GoogleFonts.poppins(color: Colors.black),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
        // actions: [
        //   Container(
        //     decoration: BoxDecoration(
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.2),
        //           offset: Offset(0, 4),
        //           blurRadius: 6,
        //         ),
        //       ],
        //     ),
        //     child: ElevatedButton.icon(
        //       onPressed: () {
        //         Navigator.push(
        //           context,
        //           MaterialPageRoute(
        //             builder: (context) =>
        //                 ParkingLotScreen(vendorid: widget.vendorid),

      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(),
          borderRadius: BorderRadius.circular(20),  // Circular border
          border: Border.all(
            color: Colors.white,  // Border color, change as needed
            width: 2.0,           // Border width, adjust as needed
          ),
        ),
        child: TabContainer(
          controller: _controller,  // Ensure the controller is passed here
          borderRadius: BorderRadius.circular(20),  // Ensure this is passed as well
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
          colors: const <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF),],
          selectedTextStyle:  GoogleFonts.poppins(
            fontSize: 15.0,
            color: ColorUtils.primarycolor(),
          ),
          unselectedTextStyle:   GoogleFonts.poppins(
            fontSize: 13.0,
            color: Colors.black, // Set default unselected color
          ),
          tabs: _getTabs(),
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
              Row(
              children: [
              // First Container wrapped with Expanded to fit the screen width
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => addcarminimumcharge( onEditSuccess: () {

                          setState(() {
                            selectedIndex = 0; // Change to the third tab
                          });
                        },vendorid: widget.vendorid,)),
                      );
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: ColorUtils.primarycolor(),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(
                            "Minimum Charge",
                            style:   GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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
                              style:   GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            )
                                : IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => addcarminimumcharge(onEditSuccess: () {

                          setState(() {
                            selectedIndex = 0; // Change to the third tab
                          });
                        },vendorid: widget.vendorid,)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                    const SizedBox(width: 5,),

                // Second Container wrapped with Expanded to fit the screen width
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => addcaradditionalcharge(onEditSuccess: () {

                          setState(() {
                            selectedIndex = 0; // Change to the third tab
                          });
                        },vendorid: widget.vendorid,)),
                      );
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: ColorUtils.primarycolor(), // Change color if selected
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(
                            "Additional Hours", // You can change the title dynamically
                            style:   GoogleFonts.poppins(
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
                              style:  GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 16, // Adjust font size as needed
                              ),
                            )
                                : IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => addcaradditionalcharge(onEditSuccess: () {

                                    setState(() {
                                      selectedIndex = 0; // Change to the third tab
                                    });
                                  },vendorid: widget.vendorid,)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                    ],
                  ),
              const SizedBox(height: 5,),
              Row(
                children: [
                  // First Container wrapped with Expanded to fit the screen width
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => addcarfullday(onEditSuccess: () {

                          setState(() {
                            selectedIndex = 0; // Change to the third tab
                          });
                        },vendorid: widget.vendorid,)),
                        );
                      },
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: ColorUtils.primarycolor(),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Text(
                              "Full Day",
                              style:  GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // Text(
                            //   fulldaycharge.isNotEmpty ? fulldaycharge[0].type : '',
                            //   style: TextStyle(
                            //     fontSize: 14,
                            //     fontWeight: FontWeight.bold,
                            //     color: Colors.white,
                            //   ),
                            // ),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: fulldaycharge.isNotEmpty
                                  ? Text(
                                fulldaycharge[0].amount,
                                style:   GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              )
                                  : IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => addcarfullday(onEditSuccess: () {

                                      setState(() {
                                        selectedIndex = 0; // Change to the third tab
                                      });
                                    },vendorid: widget.vendorid,)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5,),
                  // Second Container wrapped with Expanded to fit the screen width
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => addMonthlysubscription(onEditSuccess: () {

                            setState(() {
                              selectedIndex = 0; // Change to the third tab
                            });
                          },vendorid: widget.vendorid,)),
                        );
                      },
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: ColorUtils.primarycolor(),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Text(
                              "Monthly Subscription",
                              style:   GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            // Text(
                            //   monthlycharge.isNotEmpty ? monthlycharge[0].type : '',
                            //   style: TextStyle(
                            //     fontSize: 14,
                            //     fontWeight: FontWeight.bold,
                            //     color: Colors.white,
                            //   ),
                            // ),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: monthlycharge.isNotEmpty
                                  ? Text(
                                monthlycharge[0].amount,
                                style:  GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              )
                                  : IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => addMonthlysubscription(onEditSuccess: () {

                                      setState(() {
                                        selectedIndex = 0; // Change to the third tab
                                      });
                                    },vendorid: widget.vendorid,)),
                                  );
                                },
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
          ),
        ),



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
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => addbikeminimumcharge(
                                  vendorid: widget.vendorid,
                                  onEditSuccess: () {

                                    setState(() {
                                      selectedIndex = 1; // Change to the third tab
                                    });
                                  }, // Pass the TabController
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Minimum Charge",
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  minimumbikeCharges.isNotEmpty ? minimumbikeCharges[0].type : '',
                                  style:   GoogleFonts.poppins(
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
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => addbikeminimumcharge(
                                            vendorid: widget.vendorid,
                                            onEditSuccess: () {
                                              setState(() {
                                                selectedIndex = 1; // Change to the third tab
                                              });
                                            }, // Pass the TabController
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5,),

                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addbikeadditionalcharge(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 1; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(), // Change color if selected
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Additional Charge", // You can change the title dynamically
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                // Display the type of charge at the top
                                Text(
                                  " ${additionalbikeCharges.isNotEmpty ? additionalbikeCharges[0].type : ''}", // Display type or ' if no data
                                  style:   GoogleFonts.poppins(
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
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16, // Adjust font size as needed
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addbikeadditionalcharge(onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 1; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5,),
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addbikefullday(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 1; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                   'Full day',
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: fulldaybikecharge.isNotEmpty
                                      ? Text(
                                    fulldaybikecharge[0].amount,
                                    style:  GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addbikefullday(onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 1; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5,),
                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addbikeMonthlysubscription(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 1; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Monthly Subscription",
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: monthlybikecharge.isNotEmpty
                                      ? Text(
                                    monthlybikecharge[0].amount,
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addbikeMonthlysubscription(onEditSuccess: () {
                                                setState(() {
                                                  selectedIndex = 1; // Change to the third tab
                                                });
                                              },vendorid: widget.vendorid,)),
                                      );
                                    },
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
              ),
            ),
            // Provide content for the "On Parking" tab
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
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersminimumcharge(     onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 2; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Minimum Charge",
                                  style:   GoogleFonts.poppins(
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
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersminimumcharge(     onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 2; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5,),

                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersadditionalcharge(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 2; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(), // Change color if selected
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Additional Charge", // You can change the title dynamically
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                // Display the type of charge at the top
                                Text(
                                  " ${additionalotherCharges.isNotEmpty ? additionalotherCharges[0].type : ''}", // Display type or '' if no data
                                  style:   GoogleFonts.poppins(
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
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16, // Adjust font size as needed
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersadditionalcharge(onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 2; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5,),
                  Row(
                    children: [
                      // First Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersfullday(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 2; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Full Day",
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: fulldayothercharge.isNotEmpty
                                      ? Text(
                                    fulldayothercharge[0].amount,
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 12,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersfullday(onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 2; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5,),
                      // Second Container wrapped with Expanded to fit the screen width
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => addothersMonthlysubscription(onEditSuccess: () {
                                setState(() {
                                  selectedIndex = 2; // Change to the third tab
                                });
                              },vendorid: widget.vendorid,)),
                            );
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: ColorUtils.primarycolor(),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Text(
                                  "Monthly Subscription",
                                  style:   GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: monthlyothercharge.isNotEmpty
                                      ? Text(
                                    monthlyothercharge[0].amount,
                                    style:   GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                      : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => addothersMonthlysubscription(onEditSuccess: () {
                                          setState(() {
                                            selectedIndex = 2; // Change to the third tab
                                          });
                                        },vendorid: widget.vendorid,)),
                                      );
                                    },
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
              ),
            ),



// Example content
          ],
        ),
      ),





      ),);
  }
  List<Widget> _getTabs() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drive_eta,
            color: selectedTabIndex == 0 ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Cars',
            style:   GoogleFonts.poppins(
              color: selectedTabIndex == 0 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
      // Customer Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pedal_bike,
            color: selectedTabIndex == 1 ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Bikes',
            style:   GoogleFonts.poppins(
              color: selectedTabIndex == 1 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
      // Vendor Tab
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.miscellaneous_services,
            color: selectedTabIndex == 2 ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Others',
            style:   GoogleFonts.poppins(
              color: selectedTabIndex == 2 ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    ];
  }


}
class ParkingCharge {
  final String id;
  final String amount;
  final String type;
  final String category;
  final String chargeid;

  ParkingCharge({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.chargeid = '',
  });

  factory ParkingCharge.fromJson(Map<String, dynamic> json) {
    return ParkingCharge(
      id: json['_id']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      type: json['type']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      chargeid: json['chargeid']?.toString() ?? '',
    );
  }
}
class ParkingbikeCharge {
  final String id;
  final String amount;
  final String type;
  final String category;

  ParkingbikeCharge({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
  });

  factory ParkingbikeCharge.fromJson(Map<String, dynamic> json) {
    return ParkingbikeCharge(
      id: json['_id'],
      amount: json['amount'],
      type: json['type'],
      category: json['category'],
    );
  }
}
class ParkingotherCharge {
  final String id;
  final String amount;
  final String type;
  final String category;

  ParkingotherCharge({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
  });

  factory ParkingotherCharge.fromJson(Map<String, dynamic> json) {
    return ParkingotherCharge(
      id: json['_id'],
      amount: json['amount'],
      type: json['type'],
      category: json['category'],
    );
  }
}