import 'dart:convert';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/customer/scanpark.dart';
import 'package:mywheels/auth/customer/splashregister/register.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/customer/bottom.dart';
import 'package:mywheels/auth/customer/customerdash.dart';
import 'package:mywheels/auth/customer/drawer/customdrawer.dart';

import 'package:mywheels/model/user.dart';
import 'package:mywheels/pageloader.dart';

import '../../config/colorcode.dart'; // Make sure this path is correct
import 'package:http/http.dart' as http;

import '../vendor/editpage/editvendorprofile.dart';
import 'addcarviewcar/mycars.dart';



class CProfilePage extends StatefulWidget {
  final String userId;
  const CProfilePage({super.key, required this.userId});

  @override
  _CProfilePageState createState() => _CProfilePageState();
}

class _CProfilePageState extends State<CProfilePage> {
  bool _isSlotListingExpanded = false;
  final bool _isEditing = false;
  bool issLoading = true;
  bool _isLoading = false; // Track loading state
  void _TabChange(int index) {
    _navigatePage(index);
  }
  User? _user;
  File? _selectedImage;
  int _selecteIndex = 4;
  int bookings = 0;
  int onProcess = 0;
  int cancelled = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _pages = [
      customdashScreen(userId: widget.userId),
      CarPage(userId: widget.userId),
      scanpark(userId: widget.userId),
      ParkingPage(userId: widget.userId),
      CProfilePage(userId: widget.userId),
    ];
    fetchcount();
  }
  Future<void> fetchcount() async {
    final url = Uri.parse('${ApiConfig.baseUrl}cancelled-count/${widget.userId}'); // Replace with your API URL
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          bookings = data['totalPendingCount'] ?? 0;       // assuming these fields are in the response
          onProcess = data['totalParkedCount'] ?? 0;
          cancelled = data['totalCancelledCount'] ?? 0;
          issLoading = false;
        });
      } else {
        // Handle error
        setState(() {
          issLoading = false;
        });
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception: $e');
      setState(() {
        issLoading = false;
      });
    }
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

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            _nameController.text = _user?.username ?? '';
            _mobileNumberController.text = _user?.mobileNumber ?? '';
            _emailController.text = _user?.email ?? '';
            _vehicleController.text = _user?.vehicleNumber ?? '';
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return  Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
actions: [
  IconButton(
    icon: const Icon(
      Icons.edit,
      color: Colors.black,
      size: 24,
    ),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfilePage(userId: widget.userId),
        ),
      );
    },
  ),
],
      ),
      drawer: CustomDrawer(
        userid:widget.userId,
        // userid:_user?.id ?? '',
        imageUrl: _user?.imageUrl ?? '',
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
        child: _isLoading
            ? const LoadingGif()
            // Show loading indicator
            : SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_user?.imageUrl.isNotEmpty ?? false
                          ? NetworkImage(_user!.imageUrl)
                          : null),
                      child: _selectedImage == null && (_user?.imageUrl.isEmpty ?? true)
                          ? const Icon(Icons.person, size: 50, color: Colors.black54)
                          : null,
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _user?.username ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      _user?.mobileNumber ?? '',
                      style: const TextStyle(color: Colors.black, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              issLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusCard('Bookings', bookings),
                        _buildStatusCard('On Process', onProcess),
                        _buildStatusCard('Cancelled', cancelled),
                      ],
                    ),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        selectedIndex: _selecteIndex,
        onTabChange: _TabChange,
      ),
    );
  }
Widget _buildStatusCard(String title, int count) {
  return Container(
    width: MediaQuery.of(context).size.width * 0.25,
    decoration: BoxDecoration(
      border: Border.all(color: ColorUtils.primarycolor()),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

}



class EditProfilePage extends StatefulWidget {
  final String userId;
  const EditProfilePage({super.key,

    required this.userId,
    // required this.userName
  });

  @override
  _CdProfilePageState createState() => _CdProfilePageState();
}

class _CdProfilePageState extends State<EditProfilePage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false; // Change from final to regular variable
  User? _user;

  // bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _mobileNumberFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _vehicleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    await Future.delayed(const Duration(seconds: 2)); // Wait for 2 seconds

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}get-userdata?id=${widget.userId}'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() {
            _user = User.fromJson(data['data']);
            _nameController.text = _user?.username ?? '';
            _mobileNumberController.text = _user?.mobileNumber ?? '';
            _emailController.text = _user?.email ?? '';
            _vehicleController.text = _user?.vehicleNumber ?? '';
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (error) {
      print('Error fetching user data: $error');
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _updateUserData() async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}update-userdata?id=${widget.userId}'),
      );

      request.fields['uuid'] = widget.userId;
      request.fields['userName'] = _nameController.text;
      request.fields['userMobile'] = _mobileNumberController.text;
      request.fields['userEmail'] = _emailController.text;
      request.fields['vehicleNo'] = _vehicleController.text;

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _selectedImage!.path,
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (data['success']) {
        await _fetchUserData(); // Refresh data to reflect changes

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Wait for the SnackBar to finish before navigating
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CProfilePage(userId: widget.userId,)), // Navigate to ProfilePage
          );
        });
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: ${data['message']}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while updating data.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerItem(ctx, Icons.camera, 'Camera', ImageSource.camera),
                _buildPickerItem(ctx, Icons.photo_library, 'Gallery', ImageSource.gallery),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerItem(BuildContext ctx, IconData icon, String text, ImageSource source) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _pickImage(source);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34),  // Top Icon
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), // Bottom text
        ],
      ),
    );
  }
  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 10),
              const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                )
              ),

              const SizedBox(height: 10),
              Text(
                'Are you sure you want to delete your account? ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                'Please let us know why you are deleting your account:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel, color: Colors.black54),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        side: const BorderSide(color: Colors.black54),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _deleteAccount(reasonController.text);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),

            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount(String reason) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}delete-account'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'reason': reason,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        // Account deletion successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('once Admin Approved Your Account deleted successfully..'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to login or welcome screen after deletion
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const splashlogin()),
              (route) => false,
        );



      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Failed to delete account'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while deleting account'),
          duration: Duration(seconds: 2),
        ),
      );
      print('Error deleting account: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(titleSpacing: 0,
        // backgroundColor: ColorUtils.primarycolor(),
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.black),
            onPressed: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingGif() // Show loading GIF before the Scaffold
            : SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circle Avatar with Person Icon
              Align(
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_user?.imageUrl.isNotEmpty ?? false
                          ? NetworkImage(_user!.imageUrl)
                          : null),
                      child: _selectedImage == null && (_user?.imageUrl.isEmpty ?? true)
                          ? const Icon(Icons.person, size: 50, color: Colors.black54)
                          : null,
                    ),
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: ColorUtils.primarycolor(),
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 12, color: Colors.black),
                        onPressed: () => _showPicker(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              profileCustomTextField(
                inputFormatter: const [],
                controller: _nameController,
                focusNode: _nameFocusNode,
                keyboard: TextInputType.text,
                obscure: false,


                textInputAction: TextInputAction.next,
                label: 'Name',
                hint: 'Please enter your Name',
              ),
              const SizedBox(height: 10),
              profileCustomTextField(
                inputFormatter: const [],
                controller: _mobileNumberController,
                focusNode: _mobileNumberFocusNode,
                keyboard: TextInputType.phone,
                obscure: false,

                textInputAction: TextInputAction.next,
                label: 'Mobile Number',
                hint: 'Please enter your 10-digit number',
              ),
              const SizedBox(height: 10),
              profileCustomTextField(
                inputFormatter: const [],
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboard: TextInputType.emailAddress,
                obscure: false,

                textInputAction: TextInputAction.next,
                label: 'Email',
                hint: 'Please enter your Email',
              ),
              const SizedBox(height: 10),
              profileCustomTextField(
                inputFormatter: const [],
                controller: _vehicleController,
                focusNode: _vehicleFocusNode,
                keyboard: TextInputType.text,
                obscure: false,

                textInputAction: TextInputAction.done,
                label: 'Vehicle No',
                hint: 'Please enter your vehicle No',
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _updateUserData,
                  icon: const Icon(Icons.save,color: Colors.white,),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }
}

