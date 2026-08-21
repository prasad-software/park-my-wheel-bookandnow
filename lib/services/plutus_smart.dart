import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlutusSmart {
  static const MethodChannel _channel = MethodChannel('PLUTUS-API');

  static Future<String> bindToService() async {
    try {
      final result = await _channel.invokeMethod('bindToService');
      if (kDebugMode) {
        print('bindToService result: $result');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('bindToService error: $e');
      }
      return e.toString();
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
