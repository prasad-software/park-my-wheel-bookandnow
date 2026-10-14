import 'dart:convert';
import 'package:mywheels/services/plutus_smart.dart';

class PineLabsPrintHelper {
  static Future<String> detectPineLabsPrinter() async {
    try {
      final isPineLabs = await PlutusSmart.isPineLabsDevice().timeout(const Duration(seconds: 2));
      if (isPineLabs) {
        return 'pinelabs_builtin';
      }
    } catch (e) {
      print('PineLabs detection error: $e');
    }
    return 'none';
  }

  static Future<void> printTicket({
    required String vendorName,
    required String bookingId,
    String? invoiceId,
    required String vehicleType,
    required String vehicleNumber,
    required String parkingDate,
    required String parkingTime,
    required String amount,
    required String personName,
    required String mobileNumber,
    required String duration,
    String? sts,
    String? bookType,
    bool isEntryReceipt = false,
  }) async {
    // Generate PineLabs JSON Payload
    final receiptTitle = isEntryReceipt ? "PARKING ENTRY" : "PARKING RECEIPT";
    final invId = invoiceId != null && invoiceId.isNotEmpty ? invoiceId : bookingId;
    
    final Map<String, dynamic> printData = {
      "PrintDataType": "0",
      "PrinterWidth": 384,
      "IsCenterLogo": false,
      "IsSummaryReport": false,
      "PrintData": [
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": vendorName, "IsBold": true, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": receiptTitle, "IsBold": true, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "--------------------------------", "IsBold": false, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Booking ID: $invId", "IsBold": true, "IsCenter": false},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Vehicle: $vehicleNumber ($vehicleType)", "IsBold": false, "IsCenter": false},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Time: $parkingDate $parkingTime", "IsBold": false, "IsCenter": false},
      ]
    };
    
    if (duration.isNotEmpty) {
        (printData["PrintData"] as List).add(
          {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Duration: $duration", "IsBold": false, "IsCenter": false}
        );
    }
    
    (printData["PrintData"] as List).addAll([
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Amount: Rs. $amount", "IsBold": true, "IsCenter": false},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Name: $personName", "IsBold": false, "IsCenter": false},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Mobile: $mobileNumber", "IsBold": false, "IsCenter": false},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "--------------------------------", "IsBold": false, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": "Thank You! Drive Safe.", "IsBold": true, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": " ", "IsBold": false, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": " ", "IsBold": false, "IsCenter": true}
    ]);

    String jsonPayload = json.encode(printData);
    print("PineLabs Print Payload: $jsonPayload");
    
    try {
      final result = await PlutusSmart.startPrintJob(jsonPayload);
      print("PineLabs print result: $result");
    } catch (e) {
      print("PineLabs print exception: $e");
    }
  }

  static Future<void> printLines(List<String> lines) async {
    final Map<String, dynamic> printData = {
      "PrintDataType": "0",
      "PrinterWidth": 384,
      "IsCenterLogo": false,
      "IsSummaryReport": false,
      "PrintData": lines.map((line) {
        return {
          "PrintDataType": "0", 
          "PrinterWidth": 24, 
          "IsCenterLogo": false, 
          "PrintData": line.trim().isEmpty ? " " : line, 
          "IsBold": false, 
          "IsCenter": false
        };
      }).toList()
    };
    
    // Add bottom padding
    (printData["PrintData"] as List).addAll([
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": " ", "IsBold": false, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": " ", "IsBold": false, "IsCenter": true},
        {"PrintDataType": "0", "PrinterWidth": 24, "IsCenterLogo": false, "PrintData": " ", "IsBold": false, "IsCenter": true}
    ]);

    String jsonPayload = json.encode(printData);
    print("PineLabs Print Lines Payload: $jsonPayload");
    
    try {
      final result = await PlutusSmart.startPrintJob(jsonPayload);
      print("PineLabs print result: $result");
    } catch (e) {
      print("PineLabs print exception: $e");
    }
  }
}
