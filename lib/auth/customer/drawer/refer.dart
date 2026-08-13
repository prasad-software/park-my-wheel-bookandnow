import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neopop/widgets/buttons/neopop_tilted_button/neopop_tilted_button.dart';
import 'package:mywheels/auth/customer/drawer/searchfriends.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Refer extends StatefulWidget {
  const Refer({super.key});

  @override
  _ReferState createState() => _ReferState();
}

class _ReferState extends State<Refer> with WidgetsBindingObserver {
  List<Contact> contacts = [];

  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkContactsPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkContactsPermission();
    }
  }

  Future<void> _checkContactsPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      _fetchContacts();
    } else {
      // Request permission if it is not granted
      await _requestContactsPermission();
    }
  }



  Future<void> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      await _fetchContacts();
    } else {
      // Handle the case when permission is denied
      setState(() => isLoading = false);
      // Optionally, show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission is required to fetch contacts.')),
      );
    }
  }
  Future<void> _fetchContacts() async {
    try {
      final allContacts = await FastContacts.getAllContacts();
      setState(() {
        contacts = allContacts.where((contact) {
          return contact.displayName.isNotEmpty && contact.phones.isNotEmpty;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching contacts: $e');
    }
  }

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


  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Refer Your Friend',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18, // Adjust size as needed
            // fontWeight: FontWeight.w600, // Adjust weight if needed
          ),
        ),
      ),
      body:
      isLoading
          ? const LoadingGif()
          :SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Center(
              //   child: CircleAvatar(backgroundColor: Colors.black,
              //     radius: 50, // Adjust the radius as needed
              //     backgroundImage: AssetImage('assets/logo.png'), // Path to your logo asset
              //   ),
              // ),
              // const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, // Enable horizontal scrolling

          child: Row(
            children: [
              const SizedBox(width: 16),
              _buildReferralContainer(screenHeight, screenWidth),
              const SizedBox(width: 16), // Space between containers
              _buildReferralContainer2(screenHeight, screenWidth), // Duplicate container
              const SizedBox(width: 16), // Space between containers
              _buildReferralContainer3(screenHeight, screenWidth),
            ],
          ),
        ),
              const SizedBox(height: 16),
              NeoPopTiltedButton(
                isFloating: true,
                onTapUp: () {
                  _sendWhatsAppMessage();
                },
                decoration: const NeoPopTiltedButtonDecoration(
                  color: Color.fromARGB(255, 59, 167, 117),
                  plunkColor: Color.fromARGB(255, 59, 167, 117),
                  shadowColor: Color.fromRGBO(36, 36, 36, 1),
                  showShimmer: true,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 70.0,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // To ensure the row takes only the needed space
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5), // Clip the corners of the SVG
                        child: SvgPicture.asset(
                          "assets/what.svg", // Replace with your SVG file path
                          height: 24, // Adjust the height as needed
                          width: 24, // Adjust the width as needed
                          fit: BoxFit.contain, // Adjust fit as needed
                        ),
                      ),
                      const SizedBox(width: 8), // Space between the icon and the text
                    Text(
                        'Invite Via Whatsapp',
                        style: GoogleFonts.chewy(
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),


              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  // color: Colors.white, // Contrasting background
                  child: Row(

                    children: [
                      // Level 1
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.green, // Indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                height: 2,
                                width: 50, // Adjust this width based on your design
                                color: Colors.grey, // Line color between levels
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.grey, // Inactive indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "LEVEL 1",
                            style: GoogleFonts.lato(fontSize: 10,color:Colors.black,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      // Level 2
                      Column(
                        children: [
                          Row(
                            children: [

                              Container(
                                height: 2,
                                width: 50, // Line connecting to the next level
                                color: Colors.grey, // Inactive line color
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.grey, // Inactive indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "LEVEL 2",
                            style: GoogleFonts.lato(fontSize: 10,color:Colors.black,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      // Level 3
                      Column(
                        children: [
                          Row(
                            children: [

                              Container(
                                height: 2,
                                width: 50,
                                color: Colors.grey, // Line color
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.grey, // Inactive indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "LEVEL 3",
                            style: GoogleFonts.lato(fontSize: 10,color:Colors.black,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Row(
                            children: [

                              Container(
                                height: 2,
                                width: 50,
                                color: Colors.grey, // Line color
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.grey, // Inactive indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "LEVEL 4",
                            style: GoogleFonts.lato(fontSize: 10,color:Colors.black,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // Level 4 (final circle)
                      Column(
                        children: [
                          Row(
                            children: [

                              Container(
                                height: 2,
                                width: 50,
                                color: Colors.grey, // Line color
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.grey, // Inactive indicator color
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "LEVEL 5",
                            style: GoogleFonts.lato(fontSize: 10,color:Colors.black,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),


              Row(
                children: [
                  const Expanded(
                    child: Divider(
                      thickness: 1, // You can adjust the thickness
                      color: Colors.grey, // Change the color as needed
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0), // Add some spacing
                    child: Text(
                      "INVITE FRIENDS",
                      style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      thickness: 1,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  const SearchfiendScreen()),
                  );
                },
                child: SizedBox(height: 40,
                  child: TextFormField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  const SearchfiendScreen()),
                      );
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onPrimary,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ColorUtils.primarycolor(), // Ensure this is not returning black
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ColorUtils.primarycolor(),
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ColorUtils.primarycolor(),
                          width: 1.0,
                        ),
                      ),

                      prefixIcon: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  const SearchfiendScreen()),
                          );
                        },
                        child: Icon(Icons.search, color: ColorUtils.primarycolor()),
                      ),

                      constraints: const BoxConstraints(maxHeight: 80, maxWidth: double.infinity), // Ensure it takes full width
                      contentPadding: const EdgeInsets.only(top: 10),


                      hintText: 'Search friends for invite ',
                      hintStyle: const TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
        Container(
          child: Text("INVITE FRIENDS TO PARK MY WHEELS",style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),),
        ),
              const SizedBox(height: 5),
              Container(
                child: Text("Invite your friends to Park My Wheels and earn cashback",style:GoogleFonts.quicksand(fontSize: 12),),
              ),
              const SizedBox(height: 20),


              isLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : SizedBox(
                height: 400, // Set a fixed height for the ListView
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final phoneNumber = contact.phones.isNotEmpty == true
                        ? contact.phones.first.number
                        : "No phone number";

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey, width: 0.5),
                      ),
                      margin: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        minLeadingWidth: 0,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: ColorUtils.primarycolor(),
                          child: Text(
                            contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : "?",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          phoneNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () async {
                          final Uri smsUrl = Uri.parse("sms:$phoneNumber");
                          if (await canLaunchUrl(smsUrl)) {
                            await launchUrl(smsUrl);
                          }
                        },
                      ),
                    );
                  }))
            ],
          ),
        ),
      ),
    );
  }

}
Widget _buildReferralContainer(double screenHeight, double screenWidth) {
  return Stack(
    children: [

      // Background container
      Container(
        height: screenHeight * 0.23, // Adjust height relative to the screen height
        width: screenWidth * 0.7, // Use full screen width
        decoration: BoxDecoration(
          color: ColorUtils.primarycolor(),
          borderRadius: BorderRadius.circular(5), // Circular border radius
          border: Border.all(color: ColorUtils.primarycolor(), width: 1), // Border color and width
        ),
        padding: const EdgeInsets.all(15), // Padding inside the container
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 15,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between text and SVG
              children: [
                Expanded(
                  child: Text(
                    "Earn 400rs on your next referral",style:
                    GoogleFonts.openSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ), // Text style
                  ),
                ),
                SizedBox(

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      "assets/lights.png",
                      height: screenHeight * 0.12, // Set height dynamically
                      width: screenHeight * 0.14, // Set width dynamically
                      fit: BoxFit.contain, // Adjust fit as needed
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5), // Space between the row and the next container
            Container(
              decoration: BoxDecoration(
                color: Colors.white, // Background color
                borderRadius: BorderRadius.circular(5), // Circular border radius
                border: Border.all(color: Colors.white, width: 1), // Border color and width
              ),
              padding: const EdgeInsets.all(5), // Optional: Add padding inside the container
              child: Text(
                "Boost Activated",
                style:      GoogleFonts.openSans(
                  color: ColorUtils.primarycolor(),
                  fontWeight: FontWeight.bold,
                ), // Text color (optional)
              ),
            ),
          ],
        ),
      ),
      // Positioned container for "Level 1"
      Positioned(
        top: 10, // Adjust this value to position vertically if needed
        left: (screenWidth * 0.8 - 100) / 2, // Center "Level 1" horizontally
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5), // Add some padding inside the container
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(), // Background color of the level box
            borderRadius: BorderRadius.circular(5), // Circular border radius
            border: Border.all(color: Colors.white, width: 1), // Border color and width
          ),
          child: Text(
            "Level 1",
            style:      GoogleFonts.openSans(
              color: Colors.white, // Text color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}


Widget _buildReferralContainer2(double screenHeight, double screenWidth) {
  return Stack(
    children: [
      const SizedBox(height: 10),
      const SizedBox(height: 20),
      // Background container
      Container(
        height: screenHeight * 0.23, // Adjust height relative to the screen height
        width: screenWidth * 0.7, // Use full screen width
        decoration: BoxDecoration(
          color: ColorUtils.primarycolor(),
          borderRadius: BorderRadius.circular(5), // Circular border radius
          border: Border.all(color: ColorUtils.primarycolor(), width: 1), // Border color and width
        ),
        padding: const EdgeInsets.all(15), // Padding inside the container
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between text and SVG
              children: [
                const SizedBox(height: 40),

          Container(
          alignment: Alignment.center, // Center the icon inside the container
          width: 40, // Set the width of the container
          height: 40, // Set the height of the container
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(), // Background color of the container
            borderRadius: BorderRadius.circular(30), // Circular border radius
            border: Border.all(color: Colors.white, width: 2), // Border color and width
          ),
          child: const Icon(
            Icons.lock, // Lock icon
            color: Colors.white, // Icon color
            size: 20, // Size of the icon
          ),
        ),
                const SizedBox(height: 10),
                Container(
                  child: Text(
                    "earn assured 400rs on every referral",
                    style:     GoogleFonts.openSans(
                      fontSize:11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ), // Text style
                  ),
                ),

                Container(
                  child: Text(
                    "Complete 1 Referral to unlock level",
                    style:      GoogleFonts.openSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w100,
                      color: Colors.white,
                    ), // Text style
                  ),
                ),
                // SizedBox(
                //   // Set a width to control the size of the SVG container
                //   child: ClipRRect(
                //     borderRadius: BorderRadius.circular(5), // Clip the corners of the SVG
                //     child: SvgPicture.asset(
                //       "assets/Refer1.svg",
                //       height: screenHeight * 0.17, // Set height dynamically
                //       width: screenHeight * 0.15, // Set width dynamically
                //       fit: BoxFit.contain, // Adjust fit as needed
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 10), // Space between the row and the next container

          ],
        ),
      ),
      // Positioned container for "Level 1"
      Positioned(
        top: screenHeight * 0.00, // Adjust this value to position vertically
        left: (screenWidth * 0.8 - 100) / 2, // Center "Level 1" horizontally
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5), // Add some padding inside the container
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(), // Background color of the level box
            borderRadius: BorderRadius.circular(5), // Circular border radius
            border: Border.all(color: Colors.white, width: 1), // Border color and width
          ),
          child: Text(
            "Level 2",
            style:      GoogleFonts.openSans(
              color: Colors.white, // Text color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildReferralContainer3(double screenHeight, double screenWidth) {
  return Stack(
    children: [
      const SizedBox(height: 10),
      const SizedBox(height: 20),
      // Background container
      Container(
        height: screenHeight * 0.23, // Adjust height relative to the screen height
        width: screenWidth * 0.7, // Use full screen width
        decoration: BoxDecoration(
          color: ColorUtils.primarycolor(),
          borderRadius: BorderRadius.circular(5), // Circular border radius
          border: Border.all(color: ColorUtils.primarycolor(), width: 1), // Border color and width
        ),
        padding: const EdgeInsets.all(15), // Padding inside the container
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between text and SVG
              children: [
                const SizedBox(height: 40),

                Container(
                  alignment: Alignment.center, // Center the icon inside the container
                  width: 40, // Set the width of the container
                  height: 40, // Set the height of the container
                  decoration: BoxDecoration(
                    color: ColorUtils.primarycolor(), // Background color of the container
                    borderRadius: BorderRadius.circular(30), // Circular border radius
                    border: Border.all(color: Colors.white, width: 2), // Border color and width
                  ),
                  child: const Icon(
                    Icons.lock, // Lock icon
                    color: Colors.white, // Icon color
                    size: 20, // Size of the icon
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  child: Text(
                    "earn assured 550rs on every referral",
                    style:      GoogleFonts.openSans(
                      fontSize:11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ), // Text style
                  ),
                ),

                Container(
                  child: Text(
                    "Complete 3 Referral to unlock level",
                    style:      GoogleFonts.openSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w100,
                      color: Colors.white,
                    ), // Text style
                  ),
                ),
                // SizedBox(
                //   // Set a width to control the size of the SVG container
                //   child: ClipRRect(
                //     borderRadius: BorderRadius.circular(5), // Clip the corners of the SVG
                //     child: SvgPicture.asset(
                //       "assets/Refer1.svg",
                //       height: screenHeight * 0.17, // Set height dynamically
                //       width: screenHeight * 0.15, // Set width dynamically
                //       fit: BoxFit.contain, // Adjust fit as needed
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 10), // Space between the row and the next container

          ],
        ),
      ),
      // Positioned container for "Level 1"
      Positioned(
        top: screenHeight * 0.00, // Adjust this value to position vertically
        left: (screenWidth * 0.8 - 100) / 2, // Center "Level 1" horizontally
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5), // Add some padding inside the container
          decoration: BoxDecoration(
            color: ColorUtils.primarycolor(), // Background color of the level box
            borderRadius: BorderRadius.circular(5), // Circular border radius
            border: Border.all(color: Colors.white, width: 1), // Border color and width
          ),
          child: Text(
            "Level 3",
            style:      GoogleFonts.openSans(
              color: Colors.white, // Text color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );

}
