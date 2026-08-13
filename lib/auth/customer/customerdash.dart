import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mywheels/auth/customer/Notification.dart';
import 'package:mywheels/auth/customer/addcarviewcar/filterscreen.dart';
import 'package:mywheels/auth/customer/drawer/favourites.dart';
import 'package:mywheels/auth/customer/dummypages/commercial.dart';

import 'package:mywheels/auth/customer/moreservices.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/customer/scanpark.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/customer/bottom.dart';
import 'package:mywheels/auth/customer/drawer/Searchscreen.dart';
import 'package:mywheels/auth/customer/drawer/customdrawer.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/model/user.dart';
// import 'package:parkmywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'addcarviewcar/Addmycar.dart';
import 'addcarviewcar/mycars.dart';
import 'customerprofile.dart';
import 'dart:convert'; // For json.decode
import 'package:http/http.dart' as http;
import 'dart:async';

// For image processing and custom markers


import 'drawer/mylist.dart';
import 'dummypages/usersubcription.dart';

class customdashScreen extends StatefulWidget {
  final String userId;
  final LatLng? initialPosition;
  const customdashScreen({super.key,
     this.initialPosition,
    required this.userId,
  });

  @override
  State<customdashScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<customdashScreen> with TickerProviderStateMixin {
  final LatLng _center = const LatLng(12.9716, 77.5946);
  GoogleMapController? _mapController;
  bool _isSlotListingExpanded = false;
  bool _isLoading = false;
  int myActiveIndex = 0;
  String? selectedParkingOption;
  String? selectedbookOption;
  final Set<Marker> _markers = {};
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  final parkingOptions = [
    {'name': 'Car Parking', 'icon': null, 'svgIcon': null},
    {'name': 'Bike Parking', 'icon': null, 'svgIcon': null},
    {'name': 'Within 2 km', 'icon': null, 'svgIcon': null},
    {'name': 'Within 5 km', 'icon': null, 'svgIcon': null},
    {'name': 'Within 10 km', 'icon': null, 'svgIcon': null},
    {'name': '24 hours parking', 'icon': null, 'svgIcon': null},
    {'name': 'Monthly parking', 'icon': null, 'svgIcon': null},
    {'name': 'Filter', 'icon': Icons.filter_alt, 'svgIcon': null}, // Custom SVG for Filter
    {'name': 'View all', 'icon': Icons.view_list, 'svgIcon': null}, // Custom SVG for View all
  ];
  final bookOptions = [
    'Instant Parking',
    'Schedule Now & Park Later',
    'Monthly Parking Subscription',

  ];
  void _handleParkingOptionSelect(Map<String, dynamic> option) {
    setState(() {
      selectedParkingOption = option['name']; // Store the name field
    });

    // Navigate to FilterScreen with the selected option
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => filterscreen( // Use correct case for FilterScreen
          userid: widget.userId,
          title: "Search Parking",
          selectedOption: option['name'], // Pass the name field
        ),
      ),
    );
  }
  void _handlebookOptionSelect(String option) {
    setState(() {
      selectedParkingOption = option;
    });

    // Navigate to SearchScreen with the selected option
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => filterscreen(
    //       userid: widget.userId,
    //       title: "Search Parking",
    //       selectedOption: option, // Pass the selected option
    //     ),
    //   ),
    // );
  }
  String address = '';
  bool isLoading = true; // Start loading by default
  List<Map<String, dynamic>> vendors = [];
  late AnimationController _searchAnimationController;
  late Animation<Offset> _searchSlideAnimation;

  late AnimationController _carouselAnimationController;
  late Animation<Offset> _carouselSlideAnimation;

  late AnimationController _gridAnimationController;
  late Animation<Offset> _gridSlideAnimation;

  late AnimationController _mapAnimationController;
  late Animation<Offset> _mapSlideAnimation;
  late AnimationController _animationController;


  late AnimationController _leftAnimationController;
  late Animation<Offset> _leftSlideAnimation;

  late AnimationController _rightAnimationController;
  late Animation<Offset> _rightSlideAnimation;
  final CarouselController _controller = CarouselController();
  // Define tab items in Home Page
  User? _user;
  List<String> bannerList = [];
  void _TabChange(int index) {
    _navigatePage(index);
  }
  @override
  void initState() {
    super.initState();
    _requestPermission();
    _requestNotificationPermission();

    _pages = [
      customdashScreen(userId: widget.userId),
      CarPage(userId: widget.userId),
      scanpark(userId: widget.userId),
      ParkingPage(userId: widget.userId),
      CProfilePage(userId: widget.userId),
    ];
    _fetchUserData();
    fetchBanners();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700), // Adjust duration as needed
      vsync: this,
    );

    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from the bottom
      end: Offset.zero, // End at the original position
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize carousel animation
    _carouselAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600), // Adjust duration as needed
      vsync: this,
    );

    _carouselSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _carouselAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize grid animation
    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Adjust duration as needed
      vsync: this,
    );

    _gridSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _gridAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize map animation
    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 900), // Adjust duration as needed
      vsync: this,
    );

    _mapSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize animation controllers
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _leftAnimationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _rightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Define the slide animations

    _leftSlideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0), // Start from the left
      end: Offset.zero, // End at the original position
    ).animate(CurvedAnimation(
      parent: _leftAnimationController,
      curve: Curves.easeInOut,
    ));

    _rightSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0), // Start from the right
      end: Offset.zero, // End at the original position
    ).animate(CurvedAnimation(
      parent: _rightAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start the animations after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchAnimationController.forward();
      _carouselAnimationController.forward();
      _gridAnimationController.forward();
      _mapAnimationController.forward();
      _leftAnimationController.forward();
      _rightAnimationController.forward();
    });
  }
  @override
  void dispose() {
    _searchAnimationController.dispose();
    _carouselAnimationController.dispose();
    _gridAnimationController.dispose();
    _mapAnimationController.dispose();
    _animationController.dispose();
    _leftAnimationController.dispose();
    _rightAnimationController.dispose();
    super.dispose();
  }
  Future<void> fetchBanners() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    const String apiUrl = '${ApiConfig.baseUrl}vendor/getbanner'; // Replace with your API endpoint
    // print('Fetching banners from API: $apiUrl');

    try {
      final response = await http.get(Uri.parse(apiUrl));
      // print('API response received. Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // Assuming the response is a JSON object

        if (data['banners'] != null) {
          setState(() {
            bannerList = List<String>.from(
              data['banners'].map((banner) => banner['image']),
            );
            _isLoading = false; // Stop loading
          });
        } else {
          // print('No banners found in the response.');
          setState(() {
            _isLoading = false; // Stop loading
          });
        }
      } else {
        // print('Failed to load banners. Status code: ${response.statusCode}');
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    } catch (e) {
      // print('Error fetching banners: $e');
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
  Future<void> _requestNotificationPermission() async {
    // Check the current status of the notification permission
    var status = await Permission.notification.status;

    if (status.isDenied) {
      // Request permission if it is denied
      status = await Permission.notification.request();
      if (status.isGranted) {
        // Permission granted
        print("Notification permission granted");
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied, show a dialog to guide the user to settings
        _showPermissionDenieDialog();
      }
    } else if (status.isGranted) {
      // Permission already granted
      print("Notification permission already granted");
    }
  }

  void _showPermissionDenieDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: const Text(
              'Notification permission is required for this feature. Please enable it in the app settings.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']); // Initialize user with fetched data
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      // print('Error fetching user data: $error');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
    }
  }



  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // _showPermissionDeniedDialog();
      }
    }
  }


  String apiUrl = '${ApiConfig.baseUrl}vendor/fetch-all-vendor-data';

  Future<List<Map<String, dynamic>>> fetchVendors() async {
    // print('Fetching vendors from API...');
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 2));
      // print('API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // print('API response body: $jsonResponse');

        if (jsonResponse['data'] != null) {
          List<Map<String, dynamic>> vendorsList = (jsonResponse['data'] as List)
              .map((vendor) => {
            'name': vendor['vendorName'],
            'latitude': double.parse(vendor['latitude']),
            'longitude': double.parse(vendor['longitude']),
            'image': vendor['image'],
            'address': vendor['address'],
            'contactNo': vendor['contactNo'],
          })
              .toList();

          // print('Fetched ${vendorsList.length} vendors');
          return vendorsList;
        } else {
          // print('No vendor data found in response');
          throw Exception('No vendor data found');
        }
      } else {
        // print('Failed to load vendors, status code: ${response.statusCode}');
        throw Exception('Failed to load vendors');
      }
    } catch (e) {
      // print('Error fetching vendors: $e');
      return [];
    }
  }




  final int _selectedIndex = 0;
  int _selecteIndex = 0;
  late List<Widget> _pages;

  void _navigatePage(int index) {
    setState(() {
      _selecteIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }



  final List<Map<String, dynamic>> ramData = [
    {'head': 'Book Parking', 'bottom': '','data': '100', 'icon': 'assets/myspace.svg'},
    {'head': 'My Bookings', 'bottom': '', 'data': '100', 'icon': 'assets/parking.svg' },
    {'head': 'Monthly', 'bottom': 'Subscription', 'data': '100', 'icon': 'assets/blockspot.svg' },
    // {'head': 'Monthly','bottom': 'Booking',  'data': '100', 'icon': Icons.business_center},
    {'head': 'Explore','bottom': '', 'data': '100', 'icon': 'assets/explore.svg'},
    // {'head': 'Create Parking', 'data': '100', 'icon': Icons.create},
    {'head': 'Favourite','bottom': 'Parking', 'data': '100', 'icon': 'assets/favourite.svg'},

    {'head': 'My', 'bottom': 'Business','data': '100', 'icon': 'assets/bookparking.svg'},
    {'head': 'Corporate','bottom':'Solutions',  'data': '100', 'icon': 'assets/corporate.svg'},
    {'head': 'More', 'bottom':'Services', 'data': '100', 'icon': 'assets/grid.svg',},
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: Colors.white,
        titleSpacing: 0,
        toolbarHeight: 44,
        title: SlideTransition(
          position: _leftSlideAnimation,
          child: Image.asset(
            'assets/top.png', // Replace with the path to your logo asset
            height: 20, // Adjust height to fit the AppBar
          ),
        ),
        actions: [
          SlideTransition(
            position: _rightSlideAnimation,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddMyCar(userId: widget.userId)),
                );
              },
              child: Container(
                height: 30,
                width: 110,
                decoration: BoxDecoration(
                  color: ColorUtils.primarycolor(), // Background color
                  border: Border.all(color: ColorUtils.primarycolor(), width: 1), // Border color and width
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center content horizontally
                  crossAxisAlignment: CrossAxisAlignment.center, // Center content vertically
                  children: [
                    Text(
                      'Add vehicle', // The text to display
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ), // Customize the text style
                    ),
                    const SizedBox(width: 5), // Add spacing between the text and icon
                    const Icon(
                      Icons.add_circle,
                      size: 16, // Adjust the size of the icon
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SlideTransition(
            position: _rightSlideAnimation,
            child: IconButton(
              icon: CircleAvatar(
                backgroundColor: ColorUtils.primarycolor(), // Customize the background color
                child: const Icon(
                  size: 20,
                  Icons.notifications,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationScreen(userid:widget.userId)),
                );
              },
            ),
          ),
        ],
        // backgroundColor: ColorUtils.primarycolor(),
        leading: SlideTransition(
          position: _leftSlideAnimation,
          child: Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.menu,
                color: ColorUtils.primarycolor(), // Keeps the menu icon aligned with your theme
                size: 24, // Adjust the size if needed
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Opens the drawer
              },
            ),
          ),
        ),
      ),
      drawer: CustomDrawer(
userid:widget.userId,
        imageUrl: _user?.imageUrl?? '',
        username: _user?.username ?? '',
        mobileNumber: _user?.mobileNumber ?? '',
        onLogout: () {
          // Handle logout logic here
        },
        isSlotListingExpanded: _isSlotListingExpanded,
        onSlotListingToggle: () {
          setState(() {
            _isSlotListingExpanded = !_isSlotListingExpanded;
          });
        },
      ),
      body: SafeArea(
        child: _buildRamScreen(),
      ),
        bottomNavigationBar: CustomerBottomNavBar(
          selectedIndex: _selecteIndex,
          onTabChange: _TabChange,
        ),

    );
  }
  Widget _buildSkeletonLoader() {
    return SafeArea(
      child: Center( // Ensures content is centered
        child: SizedBox(
          height: 86,
          width: 100,
          child: LoadingAnimationWidget.halfTriangleDot(
            color: ColorUtils.primarycolor(),
            size: 50, // Adjusted size for better fit
          ),
        ),
      ),
    );
  }

  Widget _buildRamScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          SlideTransition(
            position: _carouselSlideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              child: Column(
                        children: [
                          _isLoading
            ? _buildSkeletonLoader()
            : CarouselSlider(
                            items: bannerList.map((banner) {
            return Container(

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: ColorUtils.primarylight(),
                  width: 0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  banner,
                  fit: BoxFit.cover, // Ensures image fits entire width & height
                  width: double.infinity,

                  // fit: BoxFit.fill, // Ensures the image fits horizontally
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Image.asset('assets/gifload.gif',),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error);
                  },
                ),
              ),
            );
                            }).toList(),
                            options: CarouselOptions(

            height: MediaQuery.of(context).size.height * 0.17, // Adjust height as needed
            autoPlay: true,
            enableInfiniteScroll: false,
            viewportFraction: 1.0, // Full width
            scrollPhysics: const BouncingScrollPhysics(),
            aspectRatio: 16 / 8, // Adjust aspect ratio as needed
            enlargeCenterPage: true,
            scrollDirection: Axis.horizontal,
            autoPlayCurve: Curves.fastOutSlowIn,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            onPageChanged: (index, reason) {
              setState(() {
                myActiveIndex = index;
              });
            },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: bannerList.asMap().entries.map((entry) {
            return GestureDetector(
              child: Container(
                width: myActiveIndex == entry.key ? 20 : 12,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: ColorUtils.primarycolor().withOpacity(
                      myActiveIndex == entry.key ? 0.9 : 0.4),
                ),
              ),
            );
                            }).toList(),
                          ),

                        ],
              ),
            ),
          ),


          SlideTransition(
            position: _searchSlideAnimation,
            child:  Container(
              decoration: const BoxDecoration(
                // color: Colors.white, // Background color
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15), // Curved top-left corner
                  topRight: Radius.circular(15), // Curved top-right corner
                ),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.black.withOpacity(0.2), // Shadow color
                //     offset: Offset(0, 2), // Horizontal and vertical offset
                //     blurRadius: 40, // Blur radius
                //     spreadRadius: 3, // Spread radius
                //   ),
                // ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric( horizontal: 15),
                    child: Row(
                      children: [
                        const Text(
                          " Search Nearby Spots",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Icon(Icons.arrow_circle_right,size: 20, color: ColorUtils.primarycolor(),),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5,),
                  Padding(
                    padding: const EdgeInsets.symmetric( horizontal: 15),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  SearchScreen(userid: widget.userId,title:"Search Parking" ,)),
                        );
                      },
                      child: TextFormField(
                        readOnly: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  SearchScreen(userid: widget.userId,title:"Search Parking" )),
                          );
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 0.5,
                            ),
                          ),
                          prefixIcon: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>  SearchScreen(userid: widget.userId,title:"Search Parking")),
                              );
                            },
                            child: Icon(
                              Icons.search,
                              color: ColorUtils.primarycolor(),
                            ),
                          ),
                          constraints: const BoxConstraints(
                            maxHeight: 36,
                            maxWidth: double.infinity,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          hintText: 'Search Parking Locations...',
                          hintStyle: const TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20,),

                  SlideTransition(
                    position: _gridSlideAnimation,
                    child: _buildGridView(), // Your existing grid view widget
                  ),

                  const SizedBox(height: 20,),
                  SlideTransition(
                    position: _mapSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [



                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [


                                const SizedBox(height: 5), // Reduce space between Row and Container (adjust as needed)
                                Row(
                                  children: [
                                    const Text(
                                                        " Parking Assistance",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.black,
                                                        ),
                                    ),
                                    Icon(Icons.arrow_circle_right,size: 20, color: ColorUtils.primarycolor(),),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Container(

                                  child: GridView.builder(
                                    padding: const EdgeInsets.all(5),
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(), // Avoid scrolling inside a scroll
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3, // 2 items per row
                                      crossAxisSpacing: 5,
                                      mainAxisSpacing: 5,
                                      childAspectRatio: 3.5, // Adjust as needed (width / height)
                                    ),
                                    itemCount: parkingOptions.length,
                                    itemBuilder: (context, index) => ParkingOptionBox(
                                      option: parkingOptions[index],
                                      isSelected: selectedParkingOption == parkingOptions[index],
                                      onTap: () => _handleParkingOptionSelect(parkingOptions[index]),
                                      // textColor: Colors.black,
                                      // textColor: Colors.black, // Make sure your widget supports this
                                    ),
                                  ),
                                )

                              ],
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                const SizedBox(height: 25,),
                                // const SizedBox(height: 5), // Reduce space between Row and Container (adjust as needed)
                                Row(
                                  children: [
                                    const Text(
                                      " Book Now, Pay Later!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Icon(Icons.arrow_circle_right,size: 20, color: ColorUtils.primarycolor(),),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Instant Option
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChooseParkingPage(
                                                userId: widget.userId,
                                                selectedOption: 'Instant',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          height: 35,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.directions_car,
                                                size: 18,
                                                color: ColorUtils.primarycolor(),
                                              ),
                                              const SizedBox(width: 5),
                                              const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Instant',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.normal,
                                                      height: 0.9,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Parking',
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.normal,
                                                      height: 0.9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),
                                    // Schedule Option
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChooseParkingPage(
                                                userId: widget.userId,
                                                selectedOption: 'Schedule',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          height: 35,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:  Colors.white,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 0.5, // Set border width to 0.5
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  Icons.calendar_today,
                                         size: 18,
                                                  color: ColorUtils.primarycolor()
                                              ),
                                              const SizedBox(width: 2),
                                              const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Schedule Now',
                                                    style: TextStyle(
                                                      color:  Colors.black,
                                                      fontSize: 10,
                                                      fontWeight:  FontWeight.normal,
                                                      height: 0.9, // Adjust this value to control spacing
                                                    ),
                                                  ),
                                                  Text(
                                                    'Park Later',
                                                    style: TextStyle(
                                                      color:  Colors.black,
                                                      fontSize: 10,
                                                      fontWeight:  FontWeight.normal,
                                                      height: 0.9, // Same as above for consistency
                                                    ),
                                                  ),
                                                ],
                                              ),

                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChooseParkingPage(
                                                userId: widget.userId,
                                                selectedOption: 'Subscription',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          height: 35,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:  Colors.white,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Colors.grey,
                                              width: 0.5, // Set border width to 0.5
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  Icons.calendar_today,
                                                color: ColorUtils.primarycolor(),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 2),
                                              const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Monthly',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:  Colors.black,
                                                      fontWeight:  FontWeight.normal,
                                                      height: 0.9, // Adjust this value to control spacing
                                                    ),
                                                  ),
                                                  Text(
                                                    'Parking',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:  Colors.black,
                                                      fontWeight:  FontWeight.normal,
                                                      height: 0.9, // Same as above for consistency
                                                    ),
                                                  ),
                                                ],
                                              ),

                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Subscription Option

                                  ],
                                ),

                              ],
                            ),

                          ],
                      ),
                    ),
                  ),



                  const SizedBox(height: 15,),




                  const SizedBox(height: 15,),

                ],
              ),
            ),
          ),












        ],
      ),
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.symmetric( horizontal: 11),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric( horizontal: 4),
            child: Row(
              children: [
                const Text(
                  " Quick Links ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Icon(Icons.arrow_circle_right,size: 20, color: ColorUtils.primarycolor(),),
              ],
            ),
          ),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            // Disable GridView's own scrolling
            shrinkWrap: true,
            // Expand to fit content
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // Number of items per row
              crossAxisSpacing: 6.0, // Space between items horizontally
              // mainAxisSpacing: 1.0, // Space between items vertically
              childAspectRatio: 1.0, // Aspect ratio of each item
            ),
            itemCount: ramData.length,
            itemBuilder: (context, index) {
              return _buildGridItem(context,index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        // Navigate based on the index
        switch (index) {
          case 0: // Book Parking
             Navigator.push(
             context,
              MaterialPageRoute(builder: (context) => ChooseParkingPage(userId: widget.userId,selectedOption: 'Instant')),
            );
            break;
          case 1: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParkingPage(userId: widget.userId,)),
            );
            break;
          case 2: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  BlockSpot(userId: widget.userId)),
            );
            break;
          case 3: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen(userid: widget.userId,title:"Explore Parking Space(s)")),
            );
            break;
          case 4: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  favourites( userid: widget.userId,)),
            );
            break;
          case 5: // My Bookings
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  mybusiness(

                vendorId:widget.userId,
                // username:w

              )),
            );
            break;
          case 6: // My Bookings
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const commercial()),
          );
            break;
          case 7: // My Bookings
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => moreservice(userId: widget.userId,)),
          );
            break;

        // Add more cases for other indices if needed
          default:
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
          decoration: BoxDecoration(
            // color: Colors.white, // Background color of the item
            borderRadius: BorderRadius.circular(5), // Circular border radius
            border: Border.all(
              color: Colors.white, // Change color based on selection
              width: 0.5, // Border width
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Center align text
            children: [
              Container(
                // decoration: BoxDecoration(
                //   shape: BoxShape.circle,
                //   border: Border.all(  // Circular border (outline)
                //     color:  Colors.blue, // Change color based on selection
                //     width: 0.5, // Border width (you can adjust this)
                //   ),
                // ),
                child: ramData[index]['icon'] is String
                    ? SvgPicture.asset(
                  ramData[index]['icon'], // Path to the SVG
                  height: 40, // Adjust size as needed
                  width: 40,
                )
                    : CircleAvatar(
                  radius: 26,
                  backgroundColor: ColorUtils.primarycolor(),
                  child: Icon(
                    ramData[index]['icon'], // Use icon from ramData
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4), // Space between icon and text
              Column(
                children: [
                  Text(
                    ramData[index]['head']!,
                    style: GoogleFonts.rubik(
                      fontSize: 10,
                      // fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2, // Adjust line height (reduce spacing)
                    ),
                  ),
                  Text(
                    ramData[index]['bottom']!,
                    style: GoogleFonts.rubik(
                      fontSize: 12,
                      // fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2, // Adjust line height (reduce spacing)
                    ),
                    overflow: TextOverflow.ellipsis,
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

class ParkingOptionBox extends StatelessWidget {
  final Map<String, dynamic> option;
  final bool isSelected;
  final VoidCallback onTap;

  const ParkingOptionBox({super.key, 
    required this.option,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the option is "Filter" or "View all"
    final isSpecialOption = option['name'] == 'Filter' || option['name'] == 'View all';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSpecialOption
              ? ColorUtils.primarycolor() // Green background for Filter/View all
              : (isSelected ? ColorUtils.primarycolor().withOpacity(0.1) : Colors.white),
          border: Border.all(
            color: isSelected ? ColorUtils.primarycolor() : Colors.grey,
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option['icon'] != null)
                Icon(
                  option['icon'],
                  size: 16,
                  color: isSpecialOption ? Colors.white : Colors.black, // White icon for Filter/View all
                ),
              if (option['icon'] != null) const SizedBox(width: 4),
              Text(
                option['name'],
                style: GoogleFonts.aBeeZee(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSpecialOption ? Colors.white : Colors.black, // White text for Filter/View all
                ),
                semanticsLabel: option['name'],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


