import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/colorcode.dart';

class CustommTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboard;
  final List<TextInputFormatter> inputFormatter;
  final bool obscure;
  final TextInputAction textInputAction;
  final String label;
  final bool enabled;
  final IconData? prefixIcon;
  final Function(String)? onSubmitted;
  final Color borderColor;

  const CustommTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboard,
    this.inputFormatter = const [],
    this.obscure = false,
    required this.textInputAction,
    required this.label,
    this.enabled = true,
    this.prefixIcon,
    this.onSubmitted,
    this.borderColor = Colors.grey, // Default border color
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        obscureText: obscure,
        textInputAction: textInputAction,
        inputFormatters: inputFormatter,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: ColorUtils.primarycolor()) : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), // Reduce height
          filled: true, // Enables background color
          fillColor: Colors.white, // White background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide( color: Colors.grey, width: 0.3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.3), // Consistent border color
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Colors.grey, width: 0.3), // Thicker on focus
          ),
        ),
        style: GoogleFonts.poppins(
          color: enabled ? ColorUtils.primarycolor() : Colors.grey, // Disabled color changed for clarity
        ),
      ),
    );

  }

}
