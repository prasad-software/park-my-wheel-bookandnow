import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/auth/customer/chatbox.dart';
import 'package:mywheels/auth/customer/customerdash.dart';
import 'package:mywheels/auth/customer/drawer/about_us_screen.dart';
import 'package:mywheels/auth/customer/drawer/favourites.dart';
import 'package:mywheels/auth/customer/drawer/mylist.dart';
import 'package:mywheels/auth/customer/drawer/refer.dart';
import 'package:mywheels/auth/customer/drawer/transaction.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/privacypolicydataprivacy.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/authconfig.dart';
import '../../../model/user.dart';
import '../parking/parking.dart';
import '../splashregister/register.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
class CustomDrawer extends StatefulWidget  {
  final String username;
  final String imageUrl;
  final String mobileNumber;
  final VoidCallback onLogout;
  final bool isSlotListingExpanded;
  final VoidCallback onSlotListingToggle;
final String userid;
   const CustomDrawer({
    super.key,
     required this.userid,
    required this.username,
    required this.mobileNumber,
    required this.onLogout,
    required this.isSlotListingExpanded,
    required this.onSlotListingToggle,
     required this.imageUrl,
  });
  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}
class _CustomDrawerState extends State<CustomDrawer> with SingleTickerProviderStateMixin {

  User? _user;
  double? currentRating;
  String? currentDescription;
  @override
  Widget build(BuildContext context) {
    return Drawer(
          width: MediaQuery.of(context).size.width * 0.75,
          child: SafeArea(
            child: Column(
                children: [
                  Container(
                    color: ColorUtils.primarycolor(),
                    height: 55,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
                    ),
                  ),
                  Container(
                    color: ColorUtils.primarycolor(),
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                child: widget.imageUrl.isNotEmpty
                    ? ClipOval(
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    width: 65, // Adjust the size to match the CircleAvatar radius
                    height: 65, // Adjust the size to match the CircleAvatar radius
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child; // Image has finished loading
                      } else {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0), // Adjust padding as needed
                            child: Image.asset('assets/gifload.gif'),
                          ),
                        );                        }
                    },
                  ),
                )
                    : const Icon(Icons.person, size: 40, color: Colors.black54),
              ),
            
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            
                    // Show the CircularProgressIndicator if either username or mobileNumber is empty
                    (widget.username.isEmpty || widget.mobileNumber.isEmpty)
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 10,),
                        Text(
                          widget.username,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          widget.mobileNumber,
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
            
                      ],
                    ),
                  ],
                ),
              ),
            
            ],
                    ),
                  ),
                  Expanded(
                    child: GridView.count(
            
            padding: EdgeInsets.zero,
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            children: [
            
              _buildDrawerItem('assets/svg/home.svg', 'Home', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => customdashScreen (userId: widget.userid,)),
                );
            
              }),
              _buildDrawerItem('assets/svg/mylist.svg', 'My Parking', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ParkingPage (userId: widget.userid,)),
                );
              }),
              _buildDrawerItem('assets/svg/listbooking.svg', 'My Business', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  mybusiness(vendorId:widget.userid,)),
                );
              }),
              _buildDrawerItem('assets/svg/transaction.svg', 'Transactions', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  Transactionhistory(userId :widget.userid,)),
                );
              }),
              // _buildDrawerItem('assets/svg/wallet.svg', 'Wallet', () {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(builder: (context) => Wallet(userid: userid,)),
              //   );
              // },),
              _buildDrawerItem('assets/favourite.svg', 'Favorite Parking(s)', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  favourites( userid: widget.userid,)),
                );
              },),
              _buildDrawerItem('assets/svg/about.svg', 'About Us', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                );
              },),
              _buildDrawerItem('assets/svg/support.svg', 'Support', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(userid:widget.userid,)),
                );
              }, ),
              _buildDrawerItem('assets/svg/refer.svg', 'Refer & Earn', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Refer()),
                );
              }, ),
              _buildDrawerItem('assets/svg/share.svg', 'Share', () {
                _sendWhatsAppMessage();
            
              },),
              _buildDrawerItem('assets/svg/feedback.svg', 'Feedback', () {
                String vendorId =widget.userid; // Replace with the actual vendor ID you want to use
                _showFeedbackModal(context, vendorId);
              }, ),
                _buildDrawerItem(
                'assets/svg/logout.svg',
                'Logout',
                () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
            
                // Try to get vendor ID from widget or SharedPreferences
                String? userid = widget.userid ?? prefs.getString('vendorid');
            
                print("Logout button clicked. userid ID: $userid");
            
                if (userid != null && userid.isNotEmpty) {
                try {
                final response = await http.post(
                Uri.parse("${ApiConfig.baseUrl}userlogout"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"uuid": userid}),
                );
            
                print("Status Code: ${response.statusCode}");
                print("Response Body: ${response.body}");
            
                final responseData = jsonDecode(response.body);
            
                if (response.statusCode == 200) {
                print("Logout successful: ${responseData['message']}");
            
                await prefs.clear(); // Clear SharedPreferences
            
                if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const splashlogin()),
                (Route<dynamic> route) => false,
                );
                }
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const splashlogin()),
                        (Route<dynamic> route) => false,
                  );
                print("Logout failed: ${responseData['message'] ?? 'Unknown error'}");
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Logout failed: ${responseData['message']}")),
                );
                }
                } catch (e) {
                print("Logout API Error: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logout failed. Please try again.")),
                );
                }
                } else {
                print("No userid ID found in widget or SharedPreferences");
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("userid ID not found. Please login again.")),
                );
                }
              },
            
              ),
            
                    ],
                    ),
                  ),
                  Container(
                    color: ColorUtils.primarycolor(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: SafeArea(bottom: true,
                      child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VendorPrivacy(
                          // Your privacy policy URL
                        ),
                      ),
                                        );
                                      },
                                      child:  Text(
                                        'Privacy Policy',
                                        style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const dataprivacy(
                                  
                        ),
                      ),
                                        );
                                      },
                                      child:  Text(
                                        'Terms & Services',
                                        style: GoogleFonts.poppins(
                      color:Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                      ),
                    ),
                  ),
                ],
            ),
          ),
    );
  }

  Widget _buildDrawerItem(String svgPath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.all(1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              svgPath,
              height: 60, // Adjust the height as needed
              // color: ColorUtils.primarycolor(), // Set the color if needed
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 10,),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap, {bool isBold = false}) {
  //   return ListTile(
  //     leading: Icon(icon, color: ColorUtils.primarycolor(),),
  //     title: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: <Widget>[
  //         Text(
  //           label,
  //           style: TextStyle(color: Colors.black, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14),
  //         ),
  //         Icon(Icons.navigate_next, color: ColorUtils.primarycolor(),),
  //       ],
  //     ),
  //     onTap: onTap,
  //   );
  // }
  void _sendWhatsAppMessage() async {
    const String message =
        "Hi! I'm sharing an exclusive invite to ParkMyWheels with you. 🚗🅿️\n\n"
        "Enjoy seamless parking with our app – reserve your spot in advance and save time!\n\n"
        "👉 Download now:\n"
        "📱 Android: https://play.google.com/store/apps/details?id=com.park.mywheels\n"
        "📱 iOS: https://apps.apple.com/in/app/parkmywheels/id6745809692\n\n" // Replace 'YOUR_APPLE_ID' with your actual iOS App ID
        "Start parking smart today!";

    try {
      Share.share(message);
    } catch (e) {
      print('Error: $e');
    }
  }

// Submit Feedback API
  Future<bool> submitFeedback(String userId, String vendorId, double rating, String description) async {
    const String createApiUrl = "${ApiConfig.baseUrl}createfeedback";
    String updateApiUrl = "${ApiConfig.baseUrl}updatefeedback/$userId"; // Update URL based on userId

    try {
      // Fetch existing feedback for the given vendorId
      final existingFeedback = await fetchFeedbackByVendorId(vendorId);

      // print("Fetched feedback: $existingFeedback"); // Debugging line

      // Check if feedback exists for the given vendorId
      if (existingFeedback.isNotEmpty) {
        // Update existing feedback
        final response = await http.put(
          Uri.parse(updateApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'vendorId': vendorId,
            'rating': rating,
            'description': description,
          }),
        );

        // print("Update API response: ${response.statusCode}, ${response.body}"); // Debugging line

        // Return true if status code is 200 (success)
        return response.statusCode == 200;
      } else {
        // Create new feedback if none exists
        final response = await http.post(
          Uri.parse(createApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'vendorId': vendorId,
            'rating': rating,
            'description': description,
          }),
        );

        // print("Create API response: ${response.statusCode}, ${response.body}"); // Debugging line

        // Return true if status code is 201 (created)
        return response.statusCode == 201;
      }
    } catch (e) {
      // print("Error submitting feedback: $e"); // Log any errors
      return false;
    }
  }
// Fetch Feedback by Vendor ID
  Future<List<dynamic>> fetchFeedbackByVendorId(String vendorId) async {
    final String apiUrl = "${ApiConfig.baseUrl}feedbackbyvendor/$vendorId"; // New endpoint for fetching feedback by vendorId

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return [];
      }
    } catch (e) {
      // print("Exception occurred while fetching feedback: $e");
      return [];
    }
  }
// Fetch Feedback by User ID
  Future<List<dynamic>> fetchFeedback(String userId) async {
    final String apiUrl = "${ApiConfig.baseUrl}feedbackbyid/$userId";

    try {
      // print("Making GET request to: $apiUrl"); // Debug: Check API URL
      final response = await http.get(Uri.parse(apiUrl));

      // print("Response status code: ${response.statusCode}"); // Debug: Check status code
      // print("Response body: ${response.body}"); // Debug: Check response body

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Decoded response data: $data"); // Debug: Check decoded data
        return data;
      } else {
        print("Error fetching feedback: ${response.statusCode}"); // Debug: Log non-200 status
        return [];
      }
    } catch (e) {
      print("Exception occurred while fetching feedback: $e"); // Debug: Log exceptions
      return [];
    }
  }
  void _showFeedbackModal(BuildContext context, String vendorId) {
    double? currentRating;
    String? currentDescription;

    // Fetch existing feedback when the modal is opened
    fetchFeedback(widget.userid).then((feedback) {
      if (feedback.isNotEmpty) {
        currentRating = feedback[0]['rating']?.toDouble();
        currentDescription = feedback[0]['description'];
      }

      // Show the modal bottom sheet after fetching feedback
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          final descriptionController =
          TextEditingController(text: currentDescription);

          return SafeArea( // ✅ Fix edge-to-edge issue
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/feedback.svg', height: 200),
                      const Text(
                        'Enjoying ParkMyWheel Service?',
                        style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'We\'d love your feedback so that we serve you better',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w100),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      RatingBar.builder(
                        initialRating: currentRating ?? 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 40.0,
                        unratedColor: Colors.grey,
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (rating) {
                          currentRating = rating; // Update rating locally
                        },
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                            BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                            BorderSide(color: ColorUtils.primarycolor()),
                          ),
                          labelText: 'Description',
                          labelStyle:
                          TextStyle(color: ColorUtils.primarycolor()),
                          hintText: 'Enter your feedback here',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () async {
                          final userId = widget.userid;
                          final success = await submitFeedback(
                            userId,
                            vendorId,
                            currentRating ?? 0,
                            descriptionController.text,
                          );

                          if (success) {
                            Navigator.pop(context);
                            Navigator.of(context).pop();

                            void showSuccessMessage(
                                BuildContext context, String message) {
                              final snackBar = SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);

                              Fluttertoast.showToast(
                                msg: message,
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            }

                            showSuccessMessage(
                                context, 'Feedback submitted successfully!');
                            print('Feedback submitted successfully');
                          } else {
                            Navigator.pop(context);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                Text('Feedback submitted Sucessfully.'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          height: 50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: ColorUtils.primarycolor(),
                          ),
                          child: const Center(
                            child: Text(
                              'Submit ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.white,
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
        },
      );
    });
  }

}
