import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/services/local_db_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  final StreamController<void> _syncCompleteController =
      StreamController<void>.broadcast();
  Stream<void> get onSyncComplete => _syncCompleteController.stream;

  void initialize() {
    // Check initial connectivity and sync if already online on startup
    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncPendingActions();
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _syncPendingActions();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> _syncPendingActions() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final initialActions = LocalDbService.getPendingActions();
      if (initialActions.isEmpty) {
        _isSyncing = false;
        return;
      }

      print(
        'Starting background sync for ${initialActions.length} pending actions.',
      );
      Set<String> failedOfflineIds = {};

      for (var initialAction in initialActions) {
        final syncKey = initialAction['sync_key'];

        // Re-fetch action to get freshly reconciled IDs (e.g. updated bookingId)
        final box = Hive.box(LocalDbService.pendingSyncBoxName);
        final rawValue = box.get(syncKey);
        if (rawValue == null) continue; // Already processed or deleted

        Map<String, dynamic> action;
        try {
          action = jsonDecode(rawValue as String) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final type = action['type'];
        final payload = action['payload'] as Map<String, dynamic>? ?? {};
        String? oldOfflineId = action['offline_id'];

        if (oldOfflineId != null && failedOfflineIds.contains(oldOfflineId)) {
          print(
            'Skipping $type for $oldOfflineId because a prior action failed.',
          );
          continue;
        }

        bool success = false;

        try {
          if (type == 'CREATE_BOOKING') {
            success = await _syncCreateBooking(payload, oldOfflineId);
          } else if (type == 'EXIT_BOOKING') {
            success = await _syncExitBooking(payload);
          } else if (type == 'ENTRY_SCAN') {
            success = await _syncEntryScan(payload);
          } else {
            success = true;
          }

          if (success) {
            await LocalDbService.removePendingAction(syncKey);
            Fluttertoast.showToast(
              msg: "Offline action $type synced successfully!",
            );
          } else {
            print(
              'Failed to sync action: $type for $oldOfflineId. Will retry later.',
            );
            Fluttertoast.showToast(msg: "Failed to sync offline $type.");
            if (oldOfflineId != null) failedOfflineIds.add(oldOfflineId);
          }
        } catch (e) {
          print('Exception syncing action: $type for $oldOfflineId. Error: $e');
          Fluttertoast.showToast(msg: "Error syncing $type: $e");
          if (oldOfflineId != null) failedOfflineIds.add(oldOfflineId);
        }
      }
    } catch (e) {
      print('Error during background sync: $e');
    } finally {
      _isSyncing = false;
      _syncCompleteController.add(null);
    }
  }

  Future<bool> _syncCreateBooking(
    Map<String, dynamic> payload,
    String? oldOfflineId,
  ) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/machinecreatebooking');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer your_token', // Ensure actual token logic is used here if needed
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Ensure it's not a logical error returned as 200
        if (responseData is Map &&
            (responseData['message'] == 'Booking created successfully' ||
                responseData['bookingId'] != null ||
                responseData['data'] != null)) {
          // The server created a real record, now we need to crawl through local cache
          // and replace oldOfflineId with real MongoDB _id

          final realId =
              responseData['data']?['_id'] ?? responseData['bookingId'];
          if (realId != null && oldOfflineId != null) {
            await _reconcileLocalCache(oldOfflineId, realId);
          }
          return true;
        } else {
          print('Sync CREATE_BOOKING logically failed: ${response.body}');
          final errMsg =
              responseData is Map ? responseData['message'] : 'Unknown Error';
          Fluttertoast.showToast(msg: "Backend rejected sync: $errMsg");
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Sync CREATE_BOOKING failed: $e');
      return false;
    }
  }

  Future<bool> _syncExitBooking(Map<String, dynamic> payload) async {
    try {
      final bookingId = payload['bookingId'];
      if (bookingId == null) return false;

      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/exitvehicle/$bookingId',
      );
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print('Sync EXIT_BOOKING response: ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == false || data['success'] == false) return false;
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      print('Sync EXIT_BOOKING failed: $e');
      return false;
    }
  }

  Future<bool> _syncEntryScan(Map<String, dynamic> payload) async {
    try {
      final bookingId = payload['bookingId'];
      if (bookingId == null) return false;

      final url = Uri.parse(
        '${ApiConfig.baseUrl}vendor/qrallowpark/$bookingId',
      );
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print('Sync EXIT_BOOKING response: ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['status'] == false || data['success'] == false) return false;
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      print('Sync ENTRY_SCAN failed: $e');
      return false;
    }
  }

  Future<void> _reconcileLocalCache(String oldOfflineId, String realId) async {
    print('Reconciling cache: replacing $oldOfflineId with $realId');
    await LocalDbService.replaceOfflineIdInCache(oldOfflineId, realId);
    await LocalDbService.replaceOfflineIdInPending(oldOfflineId, realId);
  }
}
