import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';




class Addamenties extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const Addamenties({super.key,
    required this.vendorid,required this.onEditSuccess

  });

  @override
  _AddamentiesState createState() => _AddamentiesState();
}

class _AddamentiesState extends State<Addamenties> {
  bool _isLoading = false;
  final TextEditingController customAmenityController = TextEditingController();
  final List<String> amenities = [
    'CCTV',

    'Wi-Fi',
    'Covered Parking',
    'Self Car Wash',
    'Charging',
    'Restroom',
    'Security',
    'Gated Parking',
    'Open Parking',

  ];
  final Map<String, IconData> amenitiesWithIcons = {
    'CCTV': Icons.videocam,
    'Wi-Fi': Icons.wifi,
    'Covered Parking': Icons.local_parking,
    'Self Car Wash': Icons.car_repair,
    'Charging': Icons.electrical_services,
    'Restroom': Icons.wc,
    'Security': Icons.security,
    'Gated Parking': Icons.local_parking_sharp,
    'Open Parking': Icons.park,
  };
  final IconData defaultIcon = Icons.more_horiz;
  final List<String> selectedAmenities = [];
  List<Map<String, String>> parkingEntries = [];
  Future<void> _submitData() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Prepare the data to be sent
    final Map<String, dynamic> data = {
      'vendorId': widget.vendorid,
      'amenities': selectedAmenities,
      'parkingEntries': parkingEntries,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}vendor/amenities'), // Replace with your API endpoint
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        // Handle success
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data added successfully!")),
        );
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add data: ${response.body}")),
        );
      }
    } catch (error) {
      // Handle network error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $error")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }
  final TextEditingController text = TextEditingController();
  final TextEditingController amount = TextEditingController();
  String? selectedParkingType;

  void _addParkingEntry() {
    // Validation to ensure both parking type and amount are selected
    if (text.text.isEmpty || amount.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select facilites and amount")),
      );
      return;
    }

    // If valid, add the new entry
    setState(() {
      parkingEntries.add({
        'amount': amount.text,
        'text': text.text,

      });
      amount.clear();
      text.clear();
    });
  }

  void _openAddAmenityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3), // Reduced outer border radius
          ),
          backgroundColor: Colors.white,
          title: const Text("Add Other Amenities"),
          content: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200], // Background color of the text field
              borderRadius: BorderRadius.circular(3), // Reduced rounded corners
              boxShadow: const [

              ],
              border: Border.all(
                color: ColorUtils.primarycolor(), // Border color
                width: 0.5, // Border width
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), // Padding inside the container
            child: SizedBox(
              height: 40, // Set a specific height for the TextFormField
              child: TextFormField(
                controller: customAmenityController,
                decoration:  InputDecoration(
                  hintText: "Enter New Amenity",
                  hintStyle:  GoogleFonts.poppins(
                    color: Colors.grey, // Hint text color
                    fontStyle: FontStyle.italic, // Hint text style
                  ),
                  border: InputBorder.none, // Removes default border
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0), // Adjust vertical padding to reduce height
                ),
                style:   GoogleFonts.poppins(
                  color: Colors.black, // Input text color
                  fontSize: 16, // Input text size
                ),
              ),
            ),
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                    blurRadius: 6, // Blur radius for soft edges
                    offset: const Offset(0, 4), // Position of the shadow
                  ),
                ],
                borderRadius: BorderRadius.circular(3), // Reduced rounded corners for the button
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(), // Button background color
                  foregroundColor: Colors.black, // Button text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3), // Match container's border radius
                  ),
                ),
                child: const Text("Cancel"),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                    blurRadius: 6, // Blur radius for soft edges
                    offset: const Offset(0, 4), // Position of the shadow
                  ),
                ],
                borderRadius: BorderRadius.circular(3), // Reduced rounded corners for the button
              ),
              child: ElevatedButton(
                onPressed: () {
                  String newAmenity = customAmenityController.text.trim();
                  if (newAmenity.isNotEmpty) {
                    setState(() {
                      selectedAmenities.add(newAmenity);
                      amenities.add(newAmenity); // Add to the amenities list
                      customAmenityController.clear(); // Clear the input field
                    });
                    Navigator.of(context).pop(); // Close dialog
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Amenity cannot be empty")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primarycolor(), // Button background color
                  foregroundColor: Colors.black, // Button text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3), // Match container's border radius
                  ),
                ),
                child: const Text("Add"),
              ),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return  Scaffold(backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Text(
              'Add Amenities',
              style:   GoogleFonts.poppins(color: Colors.black),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
      ),

      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Text(widget.vendorid),
              const SizedBox(height: 10,),
              Row(
                children: [
                  Container(
                    alignment: Alignment.centerLeft, // Aligns content to the left
                    child:  Text(
                      "Choose Amenities",
                      style:   GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: const BoxDecoration(

                    ),
                    child: ElevatedButton.icon(
                      onPressed: _openAddAmenityDialog,
                      icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
                      label: const Text("Add Amenities"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, // Text color
                        backgroundColor: ColorUtils.primarycolor(), // Button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5), // Circular border radius
                        ),
                        minimumSize: const Size(0, 20), // Reduced height
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), // Adjust padding
                      ),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 5,),
              // Subscription Radiso Button
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: amenities.map((amenity) {
                  final isSelected = selectedAmenities.contains(amenity);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedAmenities.remove(amenity);
                        } else {
                          selectedAmenities.add(amenity);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white // Selected color
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6.0,
                            offset: Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            amenitiesWithIcons[amenity] ?? defaultIcon,
                            color: isSelected ? ColorUtils.primarycolor() : ColorUtils.primarycolor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            amenity,
                            style:   GoogleFonts.poppins(
                              color: isSelected ? ColorUtils.primarycolor() : ColorUtils.primarycolor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15,),

              const SizedBox(height: 5,),
              Container(
                alignment: Alignment.centerLeft,
  child:  Text("Additional Services ",style:   GoogleFonts.poppins(fontWeight: FontWeight.bold,fontSize: 18,color: Colors.black),),
),
              const SizedBox(height: 5,),
              ListView.builder(
                shrinkWrap: true,
                itemCount: parkingEntries.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [

                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              initialValue: parkingEntries[index]['text'],
                              readOnly: true,
                              style:   GoogleFonts.poppins(color: Colors.black), // Text color (adjust to your desired color)
                              decoration: InputDecoration(
                                labelText: 'Services',
                                labelStyle:  GoogleFonts.poppins(
                                  color: ColorUtils.primarycolor(), // Set label text color
                                  fontSize: 12, // Set label text size
                                  fontWeight: FontWeight.bold, // Set label text weight
                                ),
                                hintStyle:   GoogleFonts.poppins(
                                  color: Colors.grey, // Set hint text color
                                  fontSize: 11, // Set hint text size
                                ),
                                // Label color
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color on focus
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color when enabled
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 40,
                            child: TextFormField(
                              initialValue: parkingEntries[index]['amount'],
                              readOnly: true,
                              style:   GoogleFonts.poppins(color: Colors.black), // Text color (adjust to your desired color)
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                labelStyle:   GoogleFonts.poppins(
                                  color: ColorUtils.primarycolor(), // Set label text color
                                  fontSize: 12, // Set label text size
                                  fontWeight: FontWeight.bold, // Set label text weight
                                ),
                                hintStyle:   GoogleFonts.poppins(
                                  color: Colors.grey, // Set hint text color
                                  fontSize: 11, // Set hint text size
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                                // Label color
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color on focus
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color when enabled
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),





                        Container(height: 40,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(topRight: Radius.circular(5),bottomRight: Radius.circular(5)),
                            color: Colors.redAccent,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                parkingEntries.removeAt(index);
                              });
                            },
                          ),
                        ),

                        // IconButton(
                        //   icon: Icon(Icons.delete, color: Colors.red),
                        //   onPressed: () {
                        //     setState(() {
                        //       parkingEntries.removeAt(index);
                        //     });
                        //   },
                        // ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
              Row(
                children: [

                  const SizedBox(width: 2),
                  Expanded(

                    child: SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: text,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Services',
                          hintText: 'Services',
                          labelStyle:   GoogleFonts.poppins(color: Colors.black), // Set label text color to black
                          hintStyle:   GoogleFonts.poppins(color: Colors.black),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Set the primary color for the border
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color on focus
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color when enabled
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
                          labelStyle:   GoogleFonts.poppins(color: Colors.black), // Set label text color to black
                          hintStyle:   GoogleFonts.poppins(color: Colors.black),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Set the primary color for the border
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color on focus
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: ColorUtils.primarycolor(),), // Primary color when enabled
                          ),

                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2,),
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
                      icon: const Icon(Icons.add_circle_rounded), // Add circle icon
                      color: Colors.white, // Icon color set to white
                      onPressed: _addParkingEntry, // Action when icon is pressed
                      padding: EdgeInsets.zero, // Optional: remove any extra padding around the icon
                    ),
                  ),


                ],
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(minHeight: 10), // Further reduced height
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                  height: 30, // Set a specific height
                  child: ElevatedButton.icon(
                    onPressed: _submitData,
                    icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 16), // Reduced icon size
                    label: Text(
                      "Add",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12), // Reduced font size
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: ColorUtils.primarycolor(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8), // Less padding
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
