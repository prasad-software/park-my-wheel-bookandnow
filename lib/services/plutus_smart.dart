import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlutusSmart {
  static const MethodChannel _channel = MethodChannel('PLUTUS-API');

  static Future<bool> isPineLabsDevice() async {
    try {
      final result = await _channel.invokeMethod('isPineLabsDevice');
      if (kDebugMode) {
        print('isPineLabsDevice result: $result');
      }
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('isPineLabsDevice error: $e');
      }
      return false;
    }
  }

  static Future<String> startTransaction(String transactionData) async {
    try {
      final result = await _channel.invokeMethod('startTransaction', {
        'transactionData': transactionData,
      });
      return result;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String> startPrintJob(String printData) async {
    try {
      final result = await _channel.invokeMethod('startPrintJob', {
        'printData': printData,
      });
      return result;
    } catch (e) {
      return e.toString();
    }
  }
}
