import 'dart:io';

void main() {
  final file = File('lib/auth/vendor/qrcodeallowparking.dart');
  String content = file.readAsStringSync();

  // Find the if block that contains the buttons
  final startStr = "if (bookingDetails != null &&";
  final parkedStr = "bookingDetails!['status'] ==";
  final vendorStr = "bookingDetails!['vendorId']";
  
  // This is too fragile to do with simple strings if it's formatted heavily.
  // We can look for the padding that wraps the buttons and just replace it with an empty container.
  
  // Actually, I can use regex to extract the ElevatedButtons.
  // Let's replace the whole top row buttons section with an empty Container.
  // And then insert the buttons below the main card.
}
