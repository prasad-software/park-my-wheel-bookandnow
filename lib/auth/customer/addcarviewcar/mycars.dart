import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:mywheels/auth/customer/scanpark.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/customer/bottom.dart';
import 'package:mywheels/auth/customer/customerprofile.dart';
import 'package:mywheels/auth/customer/drawer/customdrawer.dart';
import 'package:mywheels/model/user.dart';
import 'package:mywheels/pageloader.dart';
import '../customerdash.dart';
import '../parking/parking.dart';
import 'Addmycar.dart';

class CarPage extends StatefulWidget {
  final String userId;
  const CarPage({super.key, required this.userId});

  @override
  _CarPageState createState() => _CarPageState();
}

class _CarPageState extends State<CarPage> with SingleTickerProviderStateMixin {
  int _selecteIndex = 1;
  bool _isSlotListingExpanded = false;
  User? _user;
  bool _isLoading = true;
  List<Car>? _cars;
  bool _isDeleting = false;

  // Animation controller
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations = [];
  late List<Widget> _pages;

  void _TabChange(int index) {
    _navigatePage(index);
  }

  void onDeleteCar(Car car) {
    deleteCar(car.id);
  }

  void _navigatePage(int index) {
    setState(() {
      _selecteIndex = index;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => _pages[index]),
    );
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Snappier animation
    );

    // Initialize the _pages list
    _pages = [
      customdashScreen(userId: widget.userId),
      CarPage(userId: widget.userId),
      scanpark(userId: widget.userId),
      ParkingPage(userId: widget.userId),
      CProfilePage(userId: widget.userId),
    ];

    _fetchUserData();
    _fetchCars();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeItemAnimations(int count) {
    _itemAnimations = List.generate(count, (index) {
      // Staggered animation with slight overlap
      double start = index * 0.1; // 100ms delay per item
      double end = (index * 0.1) + 0.6; // 600ms animation per item

      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic, // Smooth, natural easing
          ),
        ),
      );
    });

    _animationController.forward();
  }

  Future<void> deleteCar(String carId) async {
    try {
      print('Deleting vehicle with ID: $carId');
      final url = Uri.parse('${ApiConfig.baseUrl}deletevehicle?vehicleId=$carId');
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle deleted successfully')),
          );
          _fetchCars();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete vehicle')),
        );
      }
    } catch (error) {
      print('Error deleting vehicle: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting vehicle')),
      );
    }
  }

  final ApiService apiService = ApiService();

  Future<bool> _confirmDelete(Car car) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // important for edge-to-edge fix
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Confirm Delete',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this vehicle?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () async {
                          await deleteCar(car.id);
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: Text('Delete', style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;

  }

  Widget getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return const Icon(Icons.directions_car, size: 24, color: Colors.white);
      case 'bike':
        return const Icon(Icons.motorcycle, size: 24, color: Colors.white);
      default:
        return const Icon(Icons.directions_transit, size: 24, color: Colors.white);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
    }
  }

  Future<void> _fetchCars() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Car> cars = await apiService.fetchCars(widget.userId);

      setState(() {
        _cars = cars;
        _isLoading = false;

        // Initialize animations after data is loaded
        if (_cars != null && _cars!.isNotEmpty) {
          _initializeItemAnimations(_cars!.length);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching cars: $e');
      // Removed snack bar to prevent the "Failed to load vehicles" alert from appearing
    }
  }

  Widget _buildCarItem(Car car, int index) {
    if (index >= _itemAnimations.length) {
      return const SizedBox.shrink();
    }

    final animation = _itemAnimations[index];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animation.value) * 100), // Pronounced slide-up effect
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Slidable(
        key: Key(car.vehicleNumber),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) async {
                if (_isDeleting) return;
                _isDeleting = true;
                if (await _confirmDelete(car)) {
                  _animationController.reset();
                  _fetchCars(); // Re-fetch and re-animate after deletion
                }
                _isDeleting = false;
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
          child: Container(
            padding: const EdgeInsets.only(left: 10, bottom: 0.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    car.image.isNotEmpty
                        ? CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(car.image),
                    )
                        : const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.directions_car, size: 24, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        car.vehicleNumber,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            car.make == 'Unknown' ? '' : car.make,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            car.model == 'Unknown' ? '' : car.model,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20.0),
                        bottomRight: Radius.circular(20.0),
                      ),
                    ),
                    child: getVehicleIcon(car.type),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'My Vehicle(s)',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            // fontWeight: FontWeight.w600,
          ),
        ),
        // backgroundColor: ColorUtils.primarycolor(),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.add_circle,
              color: Colors.black,
              size: 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddMyCar(userId: widget.userId)),
              );
            },
          ),
        ],
      ),
      drawer: CustomDrawer(
        userid: widget.userId,
        imageUrl: _user?.imageUrl ?? '',
        username: _user?.username ?? '',
        mobileNumber: _user?.mobileNumber ?? '',
        onLogout: () {},
        isSlotListingExpanded: _isSlotListingExpanded,
        onSlotListingToggle: () {
          setState(() {
            _isSlotListingExpanded = !_isSlotListingExpanded;
          });
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif()
            : Column(
          children: [
          // const SizedBox(height: 10),
          Expanded(
            child: _cars == null || _cars!.isEmpty
                ? Center(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.width * 0.3),
                  Image.asset(
                    'assets/logo.png',
                    width: MediaQuery.of(context).size.width * 0.6,
                    fit: BoxFit.cover,
                  ),
                  Text(
                    "No Vehicles Found!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _cars?.length ?? 0,
              itemBuilder: (context, index) {
                return _buildCarItem(_cars![index], index);
              },
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        selectedIndex: _selecteIndex,
        onTabChange: _TabChange,
      ),
    );
  }
}

class Car {
  final String id;
  final String type;
  final String make;
  final String model;
  final String color;
  final String vehicleNumber;
  final String image;

  Car({
    required this.id,
    required this.type,
    required this.make,
    required this.model,
    required this.color,
    required this.vehicleNumber,
    required this.image,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['_id']?.toString() ?? 'Unknown',
      type: json['type']?.toString() ?? 'Unknown',
      make: json['make']?.toString() ?? 'Unknown',
      model: json['model']?.toString() ?? 'Unknown',
      color: json['color']?.toString() ?? 'Unknown',
      vehicleNumber: json['vehicleNo']?.toString() ?? 'Unknown',
      image: json['image']?.toString() ?? '',
    );
  }
}

class ApiService {
  Future<List<Car>> fetchCars(String userId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-vehicle?id=$userId'));

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<dynamic> vehiclesJson = jsonResponse['vehicles'] ?? [];
      return vehiclesJson.map((car) => Car.fromJson(car)).toList();
    } else {
      throw Exception('Failed to load cars');
    }
  }
}