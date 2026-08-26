import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/colorcode.dart';

class GlobalVendorState {
  static String? menuImageUrl;
}

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;
  final String? menuImageUrl;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
    this.menuImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (menuImageUrl != null && menuImageUrl!.isNotEmpty) {
      GlobalVendorState.menuImageUrl = menuImageUrl;
    }
    
    final displayImage = (menuImageUrl != null && menuImageUrl!.isNotEmpty)
        ? menuImageUrl
        : GlobalVendorState.menuImageUrl;

    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTabChange,
      type: BottomNavigationBarType.fixed,
      backgroundColor: ColorUtils.primarycolor(),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.black,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Bookings',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner_outlined),
          label: 'Entry Scan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_parking),
          label: 'Manage',
        ),
        BottomNavigationBarItem(
          icon: displayImage != null && displayImage.isNotEmpty
              ? ClipOval(
            child: Image.network(
              displayImage,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _defaultProfileIcon(),
            ),
          )
              : _defaultProfileIcon(),
          label: 'Menu',
        ),
      ],
    );
  }

  Widget _defaultProfileIcon() {
    return const CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 18, color: Colors.black),
    );
  }
}
