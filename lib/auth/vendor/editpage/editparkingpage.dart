import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/authconfig.dart';
import 'dart:convert'; // For json.decode
import 'package:http/http.dart' as http;
import 'package:mywheels/pageloader.dart';
import '../../../config/colorcode.dart';


class editParkingPage extends StatefulWidget {
  final String vendorId;
  final Function onEditSuccess;
  const editParkingPage({super.key, required this.vendorId,required this.onEditSuccess});



  @override
  _editParkingPageState createState() => _editParkingPageState();
}


class _editParkingPageState extends State<editParkingPage> {
  List<Map<String, String>> parkingEntries = []; // List to hold parking entries
  bool _isLoading = false; // Flag for loading state
  final TextEditingController text = TextEditingController(); // Controller for 'Services'
  final TextEditingController amount = TextEditingController(); // Controller for 'Amount'
  // Submit data method
  void _submitData(List<Map<String, String>> parkingEntries) async {
    // Add the current input fields to the parkingEntries if they are not empty
    if (text.text.isNotEmpty && amount.text.isNotEmpty) {
      setState(() {
        parkingEntries.add({
          'text': text.text,
          'amount': amount.text,
        });
        text.clear();
        amount.clear();
      });
    }

    setState(() {
      _isLoading = true; // Set loading state to true
    });

    try {
      await updateParkingEntries(widget.vendorId, parkingEntries);
      widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
      Navigator.pop(context);
      // Optionally, you can show a success message or navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking entries updated successfully!')),
      );
    } catch (error) {
      // Handle error appropriately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update parking entries: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Reset loading state
      });
    }
  }

  Future<void> updateParkingEntries(String vendorid, List<Map<String, dynamic>> parkingEntries) async {

    final url = '${ApiConfig.baseUrl}vendor/updateparkingentries/$vendorid';

    final response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'parkingEntries': parkingEntries}),
    );

    if (response.statusCode == 200) {
      print('Parking entries updated successfully: ${response.body}');
    } else {
      print('Failed to update parking entries: ${response.statusCode} ${response.body}');
    }
  }
  // Fetch amenities and parking data from the API
  Future<AmenitiesAndParking> fetchAmenitiesAndParking(String vendorId) async {
    setState(() {
      _isLoading = true; // Set loading state to true
    });

    final url = Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/$vendorId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Print the response data to ensure structure
        print('Response Data: $data');

        // Check if 'AmenitiesData' and 'parkingEntries' are available
        if (data['AmenitiesData'] != null && data['AmenitiesData']['parkingEntries'] != null) {
          var parkingEntries = data['AmenitiesData']['parkingEntries'];

          // Check if parkingEntries is not empty
          if (parkingEntries.isNotEmpty) {
            return AmenitiesAndParking.fromJson({'parkingEntries': parkingEntries});
          } else {
            print("No parking entries found.");
            return AmenitiesAndParking(parkingEntries: []);
          }
        } else {
          print("Error: 'parkingEntries' or 'AmenitiesData' key is missing or null.");
          return AmenitiesAndParking(parkingEntries: []);
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Reset loading state
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchAmenitiesAndParking(widget.vendorId).then((data) {
      setState(() {
        parkingEntries = data.parkingEntries; // Use the fetched data
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.white,
      appBar: AppBar(titleSpacing: 0,backgroundColor: ColorUtils.secondarycolor(),
          title:  Text("Edit Services",  style: GoogleFonts.poppins(color: Colors.black,),)),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : SingleChildScrollView(
          child: Column(
            children: [
            // ListView.builder to display the parking entries
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: parkingEntries.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        // Services TextFormField
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              initialValue: parkingEntries[index]['text'],
                              readOnly: true,
                              style:    GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Services',
                                labelStyle:   GoogleFonts.poppins(
                                  color: ColorUtils.primarycolor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                hintStyle:  GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor()),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor()),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Amount TextFormField
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              // initialValue: parkingEntries[index]['amount'],
                              controller: TextEditingController(text: parkingEntries[index]['amount']),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                parkingEntries[index]['amount'] = value; // Update the amount in the entry
                              },
                              style:   GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                labelStyle:   GoogleFonts.poppins(
                                  color: ColorUtils.primarycolor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                hintStyle:    GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),

                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor()),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor()),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Delete button to remove item from the list
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
                                parkingEntries.removeAt(index); // Remove item
                              });
                              _submitData( parkingEntries);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Padding for the next input fields (Services and Amount)
            Padding(
              padding: const EdgeInsets.only(left:  5.0,right: 5.0,),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextFormField(
                            controller: text,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Services',
                              hintText: 'Services',
                              labelStyle:   GoogleFonts.poppins(color: Colors.black),
                              hintStyle:  GoogleFonts.poppins(color: Colors.black),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
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
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextFormField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              hintText: 'Amount',
                              labelStyle:   GoogleFonts.poppins(color: Colors.black),
                              hintStyle:  GoogleFonts.poppins(color: Colors.black),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
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
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(5),
                            bottomRight: Radius.circular(5),
                          ),
                          color: ColorUtils.primarycolor(),
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
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 40,
                  width: 140, // Full-width button
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _submitData( parkingEntries), // Pass the correct parameters here
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.browser_updated_sharp, color: Colors.white),
                    label: _isLoading
                        ? const Text("")
                        : Text("Update", style:   GoogleFonts.poppins(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.primarycolor(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
                    ],
                  ),
          ),
      ),    );



  }

  // Method to add parking entry
  void _addParkingEntry() {
    setState(() {
      parkingEntries.add({
        'text': text.text,
        'amount': amount.text,
      });
      text.clear();
      amount.clear();
    });
    _submitData( parkingEntries);
  }

  // Submit data method


}

class AmenitiesAndParking {
  final List<Map<String, String>> parkingEntries;

  AmenitiesAndParking({required this.parkingEntries});

  // Updated factory constructor to handle the new structure
  factory AmenitiesAndParking.fromJson(Map<String, dynamic> json) {
    return AmenitiesAndParking(
      parkingEntries: List<Map<String, String>>.from(
        json['parkingEntries'].map((entry) {
          return {
            'text': entry['text']?.toString() ?? '',  // Safely convert to String
            'amount': entry['amount']?.toString() ?? '0',  // Ensure amount is a String, default to '0'
          };
        }),
      ),
    );
  }



}
