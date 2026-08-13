import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/colorcode.dart';

class CustomerBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const CustomerBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTabChange,
      type: BottomNavigationBarType.fixed,
      backgroundColor: ColorUtils.primarycolor(),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/home.svg',
            height: 20,
            color: selectedIndex == 0 ? Colors.white : Colors.white70,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/car.svg',
            height: 20,
            color: selectedIndex == 1 ? Colors.white : Colors.white70,
          ),
          label: 'Vehicle',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.qr_code_scanner_outlined,
            color: selectedIndex == 2 ? Colors.white : Colors.white70,
          ),
          label: 'Scan & Park',
        ),

        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/bookingbottom.svg',
            height: 20,
            color: selectedIndex == 3 ? Colors.white : Colors.white70,
          ),
          label: 'My Parking',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/profile.svg',
            height: 20,
            color: selectedIndex == 4 ? Colors.white : Colors.white70,
          ),
          label: 'Profile',
        ),
      ],
    );
  }
}
