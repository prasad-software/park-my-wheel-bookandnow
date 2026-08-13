import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/pageloader.dart';

import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Editamenities extends StatefulWidget {
  final String vendorid;
  final Function onEditSuccess;
  const Editamenities({super.key, required this.vendorid,required this.onEditSuccess});

  @override
  _EditamenitiesState createState() => _EditamenitiesState();
}

class _EditamenitiesState extends State<Editamenities> {
  bool _isLoading = false;
  bool _isFetchingData = true;
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
  List<String> selectedAmenities = [];
  List<String> customAmenities = [];
  void _openAddAmenityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Reduced outer border radius
          ),
          backgroundColor: Colors.white,
          title: const Center(child: Text("Add Amenities")),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Prevent excessive height
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200], // Background color of the text field
                  borderRadius: BorderRadius.circular(5), // Rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1), // Subtle shadow color
                      blurRadius: 5, // Blur radius
                      offset: const Offset(0, 3), // Offset for the shadow
                    ),
                  ],
                  border: Border.all(
                    color: ColorUtils.primarycolor(), // Border color
                    width: 0.5, // Border width
                  ),
                ),
                // padding: const EdgeInsets.symmetric(horizontal: 10), // Adjust padding inside the container
                child: SizedBox(
                  height: 40, // Reduce the height of the text field
                  child: TextFormField(
                    controller: customAmenityController,
                    decoration: InputDecoration(
                      hintText: "Enter New Amenity",

                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey, // Hint text color

                        fontSize: 12// Hint text style
                      ),
                      border: InputBorder.none, // Removes default border
                      contentPadding: const EdgeInsets.symmetric( horizontal: 15.0), // Reduce padding
                    ),
                    style: GoogleFonts.poppins(
                      color: Colors.black, // Input text color
                      fontSize: 14, // Input text size
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                //     blurRadius: 6, // Blur radius for soft edges
                //     offset: const Offset(0, 4), // Position of the shadow
                //   ),
                // ],
                borderRadius: BorderRadius.circular(5), // Rounded corners for the container
              ),
              child: SizedBox(
                height: 25,
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
                      borderRadius: BorderRadius.circular(5), // Match container's border radius
                    ),
                    // padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15), // Reduce padding inside button
                    // minimumSize: const Size(60, 35), // Reduce button height
                  ),
                  child: Text(
                    "Add",
                    style: GoogleFonts.poppins(color: Colors.white,fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }
  Future<void> _submitData() async {
    setState(() {
      _isLoading = true;
    });

    final Map<String, dynamic> data = {
      'amenities': selectedAmenities,
    };

    try {
      print("Preparing to send data: $data");

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}vendor/updateamenitiesdata/${widget.vendorid}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        widget.onEditSuccess(); // This will trigger the parent to navigate to the third tab
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data updated successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update data: ${response.body}"),
          ),
        );
      }
    } catch (error) {
      print("Error occurred: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred: $error"),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print("Finished updating data.");
    }
  }


  Future<void> _fetchExistingData() async {
    setState(() {
      _isFetchingData = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/getamenitiesdata/${widget.vendorid}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          selectedAmenities.clear();

          if (data['AmenitiesData']['amenities'] != null &&
              data['AmenitiesData']['amenities'] is List) {
            selectedAmenities.addAll(List<String>.from(data['AmenitiesData']['amenities']));

            // Merge dynamic amenities into the static amenities list
            for (var amenity in selectedAmenities) {
              if (!amenities.contains(amenity)) {
                amenities.add(amenity);
              }
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch data: ${response.body}")));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred: $error")));
    } finally {
      setState(() {
        _isFetchingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return  _isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: Container(
          decoration: const BoxDecoration(

          ),
          child: AppBar(titleSpacing: 0,
            backgroundColor: ColorUtils.secondarycolor(),
            title:  Text(
              'Edit Amenities',
              style: GoogleFonts.poppins(color: Colors.black),
            ),
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: Icon(Icons.add_circle, color: ColorUtils.primarycolor(),), // Change color as needed
                onPressed: _openAddAmenityDialog,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
      body: _isFetchingData
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Image.asset('assets/gifload.gif',),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                alignment: Alignment.centerLeft,
                child:  Text(
                  "Choose Amenities",
                  style:  GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 5),
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
                            ? Colors.grey[300] // Selected color
                            :Colors.white,  // Unselected color
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6.0,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            amenitiesWithIcons[amenity] ?? defaultIcon,
                            color: isSelected ? ColorUtils.primarycolor() : ColorUtils.primarycolor()
                          ),
                          const SizedBox(width: 4),
                          Text(
                            amenity,
                            style: GoogleFonts.poppins(
                              color: isSelected ? ColorUtils.primarycolor():ColorUtils.primarycolor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end, // Aligns children to the bottom
                  crossAxisAlignment: CrossAxisAlignment.end, // Aligns children to the right
                  children: [
                    // Uncomment this section if you want to include the "Add Amenities" button
                    // Container(
                    //   decoration: BoxDecoration(
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: Colors.black.withOpacity(0.2), // Shadow color with opacity
                    //         offset: Offset(0, 4), // Offset in x and y direction
                    //         blurRadius: 6, // Blur radius for the shadow
                    //       ),
                    //     ],
                    //   ),

                    const SizedBox(height: 10), // Space between buttons if needed
                    _isLoading
                        ? const CircularProgressIndicator()
                        :ElevatedButton(
                      onPressed: _submitData,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: ColorUtils.primarycolor(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        minimumSize: const Size(0, 35), // Width (0 = auto), Height reduced to 35
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Adjust padding if needed
                      ),
                      child: const Text("Update Amenities"),
                    ),

                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
