
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorUtils {
  // color: ColorUtils.primarycolor(),
  static Color primarycolor() {
    return const Color(0xFF3BA775); // Replace with your specific color code
  }
  static Color first() {
    return const Color(0xFFBCC4CE); // Replace with your specific color code
  }
  static Color primarylight() {
    return const Color(0xFFC8FFC8); // Replace with your specific color code
  }
  static Color whiteclr() {
    return const Color(0xFFFFFFFF); // Replace with your specific color code
  }
  // color: ColorUtils.secondarycolor(),
  static Color secondarycolor() {
    return const Color(0xFFF1F2F6); // Replace with your specific color code
  }
  // color: ColorUtils.secondarycolor(),
  static Color buttoncolor() {
    return const Color(0xFFE4AC3F); // Replace with your specific color code
  }
}
class Colortils {
  // color: Colortils.primarycolor(),
  static Color primarycolor() {
    return const Color(0xFF3BA775); // Replace with your specific color code
  }

}
const Color used = Color.fromARGB(255, 59, 167, 117);
class ColorCodes {
  static const Color teal = Color(0xFF3BA775);



}


const kTextColor = Color(0xFF535353);
const kTextLightColor = Color(0xFFACACAC);

const kDefaultPaddin = 20.0;

class AppColors {
  // Define constant colors here
  static const Color primaryWhite = Color(0xFFFFFFFF);
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryBlue = Color(0xFF0000FF);
  static const Color lightBlue = Color(0xFFADD8E6);
  static const Color primaryGrey = Color(0xFFB0B0B0);

  // Neumorphic shadow colors for a design style
  static const List<BoxShadow> neumorpShadow = [
    BoxShadow(
      color: Colors.grey, // Replace with your preferred color
      offset: Offset(10, 10),
      blurRadius: 15,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Colors.white, // Replace with your preferred color
      offset: Offset(-10, -10),
      blurRadius: 15,
      spreadRadius: 1,
    ),
  ];
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Convert the new value to uppercase
    final newText = newValue.text.toUpperCase();
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length), // Move cursor to the end
    );
  }
}