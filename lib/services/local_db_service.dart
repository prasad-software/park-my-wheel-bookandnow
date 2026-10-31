import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mywheels/config/authconfig.dart';

class GlobalRecentExits {
  static final Set<String> exitedBookingIds = {};
}

class LocalDbService {
  static const String apiCacheBoxName = 'api_cache_box';
  static const String cachedBookingsBoxName = 'cached_bookings_box';
  static const String pendingSyncBoxName = 'pending_sync_box';
  static const String idMappingBoxName = 'id_mapping_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(apiCacheBoxName);
    await Hive.openBox(cachedBookingsBoxName);
    await Hive.openBox(pendingSyncBoxName);
    await Hive.openBox(idMappingBoxName);
  }

  // Persistent Offline -> Online ID Mapping
  static Future<void> saveOfflineIdMapping(
    String realId,
    String offlineId,
  ) async {
    final box = Hive.box(idMappingBoxName);
    await box.put(realId, offlineId);
  }

  static String? getOfflineMappedId(String id) {
    final box = Hive.box(idMappingBoxName);
    final mapped = box.get(id)?.toString();
    // Prevent corrupted reverse mappings (where mapped value is a Mongo ID) from leaking out
    if (mapped != null && mapped.length == 24) {
      return null;
    }
    return mapped;
  }

  // Generic Cache API Response
  static Future<void> cacheApiResponse(String url, dynamic data) async {
    final box = Hive.box(apiCacheBoxName);

    try {
      if (data is Map && data['bookings'] is List) {
        final pendingActions = getPendingActions();
        final pendingExitIds =
            pendingActions
                .where((a) => a['type'] == 'EXIT_BOOKING')
                .map((a) => (a['payload']?['bookingId'] ?? '').toString())
                .toSet();

        pendingExitIds.addAll(GlobalRecentExits.exitedBookingIds);

        if (pendingExitIds.isNotEmpty) {
          List<dynamic> newBookings = List<dynamic>.from(data['bookings']);
          bool changed = false;

          if (url.contains('/onparking')) {
            // Remove bookings that have a pending exit
            newBookings.removeWhere((b) {
              final bid = b['_id']?.toString() ?? b['id']?.toString() ?? '';
              return pendingExitIds.contains(bid);
            });
            changed = true;
          } else if (url.contains('/completed')) {
            // Add exited bookings to completed if missing
            final oldCacheStr = box.get(url);
            if (oldCacheStr != null) {
              final oldCache = jsonDecode(oldCacheStr as String);
              if (oldCache is Map && oldCache['bookings'] is List) {
                final oldBookings = oldCache['bookings'] as List<dynamic>;
                for (var oldBooking in oldBookings) {
                  final id =
                      oldBooking['_id']?.toString() ??
                      oldBooking['id']?.toString() ??
                      '';
                  if (pendingExitIds.contains(id)) {
                    bool exists = newBookings.any((b) {
                      final bid =
                          b['_id']?.toString() ?? b['id']?.toString() ?? '';
                      return bid == id;
                    });
                    if (!exists) {
                      newBookings.insert(0, oldBooking);
                      changed = true;
                    }
                  }
                }
              }
            }
          } else {
            // For endpoints like search, update status to COMPLETED
            for (var b in newBookings) {
              final bid = b['_id']?.toString() ?? b['id']?.toString() ?? '';
              if (pendingExitIds.contains(bid) && b['status'] != 'COMPLETED') {
                b['status'] = 'COMPLETED';
                final now = DateTime.now();
                b['exitvehicledate'] ??=
                    "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
                b['exitvehicletime'] ??=
                    "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
                changed = true;
              }
            }
          }

          if (changed) {
            data['bookings'] = newBookings;
          }
        }
      }
    } catch (e) {
      print('Error applying pending exits to API response: $e');
    }

    await box.put(url, jsonEncode(data));
  }

  // Get generic cached API response (synchronous)
  static dynamic getCachedApiResponse(String url) {
    final box = Hive.box(apiCacheBoxName);
    final data = box.get(url);
    if (data != null) {
      try {
        return jsonDecode(data as String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Cache specific bookings list
  static Future<void> cacheBookings(String vendorId, dynamic data) async {
    final box = Hive.box(cachedBookingsBoxName);
    await box.put(vendorId, jsonEncode(data));
  }

  static dynamic getCachedBookings(String vendorId) {
    final box = Hive.box(cachedBookingsBoxName);
    final data = box.get(vendorId);
    if (data != null) {
      try {
        return jsonDecode(data as String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Queue an action for background synchronization
  static Future<void> addPendingAction(Map<String, dynamic> action) async {
    final box = Hive.box(pendingSyncBoxName);
    // Use provided offline_id or current timestamp as a simple unique key
    final timestamp =
        action['offline_id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    action['offline_id'] = timestamp;
    await box.put(timestamp, jsonEncode(action));
  }

  static List<Map<String, dynamic>> getPendingActions() {
    final box = Hive.box(pendingSyncBoxName);
    List<Map<String, dynamic>> actions = [];
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        try {
          final decoded = jsonDecode(value as String);
          decoded['sync_key'] =
              key; // Attach the Hive key so we can delete it later
          actions.add(decoded as Map<String, dynamic>);
        } catch (_) {}
      }
    }
    // Sort chronologically based on offline_id (which is a timestamp)
    actions.sort(
      (a, b) =>
          (a['offline_id'] as String).compareTo(b['offline_id'] as String),
    );
    return actions;
  }

  static Future<void> removePendingAction(String syncKey) async {
    final box = Hive.box(pendingSyncBoxName);
    await box.delete(syncKey);
  }

  /// Appends an offline booking to the cached API response for a booking list URL.
  /// This makes the booking visible in the dashboard even when offline.
  static Future<void> addOfflineBookingToCache(
    String url,
    Map<String, dynamic> bookingData,
  ) async {
    final box = Hive.box(apiCacheBoxName);
    final existing = box.get(url);
    List<dynamic> bookings = [];
    if (existing != null) {
      try {
        final decoded = jsonDecode(existing as String);
        if (decoded is Map && decoded['bookings'] is List) {
          bookings = List<dynamic>.from(decoded['bookings']);
        }
      } catch (_) {}
    }
    bookings.insert(0, bookingData); // Add to top of list
    await box.put(url, jsonEncode({'bookings': bookings}));
  }

  static List<Map<String, dynamic>> getOfflineBookingsForVendor(
    String vendorId,
    String vehicleType, {
    String? filter,
  }) {
    final actions = getPendingActions();
    final exitPayloads = <String, Map<String, dynamic>>{};
    for (var a in actions) {
      if (a['type'] == 'EXIT_BOOKING') {
        final payload = a['payload'] as Map<String, dynamic>? ?? {};
        final bookingId = payload['bookingId']?.toString() ?? '';
        if (bookingId.isNotEmpty) {
          exitPayloads[bookingId] = payload;
        }
      }
    }

    final List<Map<String, dynamic>> result = [];
    for (var action in actions) {
      if (action['type'] != 'CREATE_BOOKING') continue;
      final payload = action['payload'] as Map<String, dynamic>? ?? {};
      if (payload['vendorId'] != vendorId) continue;
      if (vehicleType.isNotEmpty &&
          (payload['vehicleType'] ?? '') != vehicleType)
        continue;

      final offlineId = action['offline_id']?.toString() ?? '';
      // A booking might be matched by its offlineId OR its fallbackId if it hasn't synced yet.
      // Wait, CREATE_BOOKING offline_id is the PMW id!
      // The EXIT_BOOKING payload['bookingId'] uses this PMW id!
      final isExited = exitPayloads.containsKey(offlineId);
      final exitPayload = isExited ? exitPayloads[offlineId] : null;
      final status =
          isExited
              ? 'COMPLETED'
              : (payload['status'] ?? '').toString().toUpperCase();

      if (filter == 'onparking' && status != 'PARKED') continue;
      if (filter == 'completed' && status != 'COMPLETED') continue;

      // Build a booking-like map with the offline_id as _id
      final booking = Map<String, dynamic>.from(payload);
      final fallbackId =
          'PMW${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
      booking['_id'] = offlineId.isNotEmpty ? offlineId : fallbackId;
      booking['status'] = status;
      booking['invoiceid'] = booking['_id'];
      if (isExited && exitPayload != null) {
        final now = DateTime.now();
        booking['exitvehicledate'] =
            exitPayload['exitvehicledate'] ??
            "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
        booking['exitvehicletime'] =
            exitPayload['exitvehicletime'] ??
            "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

        if (exitPayload['amount'] != null) {
          booking['amount'] = exitPayload['amount'].toString();
          booking['totalamout'] = exitPayload['amount'].toString();
        }
        if (exitPayload['totalamout'] != null) {
          booking['totalamout'] = exitPayload['totalamout'].toString();
        }
        if (exitPayload['paymentMode'] != null) {
          booking['paymentMode'] = exitPayload['paymentMode'];
          booking['paymentmode'] = exitPayload['paymentMode'];
        }
      }
      booking['isOffline'] = true;
      result.add(booking);
    }
    return result;
  }

  /// Manually moves a booking from 'onparking' to 'completed' across all API caches.
  static Future<void> markBookingCompletedOffline(
    String bookingId, {
    double? amount,
    String? paymentMode,
  }) async {
    final box = Hive.box(apiCacheBoxName);
    Map<String, dynamic>? targetBooking;

    final now = DateTime.now();
    final exitDate =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final exitTime =
        "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    // 1. Scan ALL caches to find the booking and update its status in-place.
    // If it's in an 'onparking' cache, remove it and save it as targetBooking.
    for (var key in box.keys.toList()) {
      final keyStr = key.toString();
      final value = box.get(key);
      if (value != null) {
        try {
          final decoded = jsonDecode(value as String);
          if (decoded is Map && decoded['bookings'] is List) {
            final bookings = List<dynamic>.from(decoded['bookings']);
            final index = bookings.indexWhere(
              (b) =>
                  b['_id'] == bookingId ||
                  b['id'] == bookingId ||
                  b['offlineId'] == bookingId,
            );

            if (index != -1) {
              final amtStr = (amount != null && amount > 0)
                  ? ((amount == amount.roundToDouble())
                      ? amount.round().toString()
                      : amount.toStringAsFixed(2))
                  : null;

              if (keyStr.contains('/onparking')) {
                targetBooking = Map<String, dynamic>.from(
                  bookings.removeAt(index),
                );
                targetBooking!['status'] = 'COMPLETED';
                targetBooking['exitvehicledate'] = exitDate;
                targetBooking['exitvehicletime'] = exitTime;
                if (amtStr != null) {
                  targetBooking['amount'] = amtStr;
                  targetBooking['totalamout'] = amtStr;
                }
                if (paymentMode != null && paymentMode.isNotEmpty) {
                  targetBooking['paymentMode'] = paymentMode;
                  targetBooking['paymentmode'] = paymentMode;
                }
                await box.put(key, jsonEncode({'bookings': bookings}));
              } else {
                bookings[index]['status'] = 'COMPLETED';
                bookings[index]['exitvehicledate'] = exitDate;
                bookings[index]['exitvehicletime'] = exitTime;
                if (amtStr != null) {
                  bookings[index]['amount'] = amtStr;
                  bookings[index]['totalamout'] = amtStr;
                }
                if (paymentMode != null && paymentMode.isNotEmpty) {
                  bookings[index]['paymentMode'] = paymentMode;
                  bookings[index]['paymentmode'] = paymentMode;
                }
                if (targetBooking == null) {
                  targetBooking = Map<String, dynamic>.from(bookings[index]);
                }
                await box.put(key, jsonEncode({'bookings': bookings}));
              }
            }
          }
        } catch (_) {}
      }
    }

    // 2. Ensure the booking is explicitly added to the 'completed' cache.
    if (targetBooking != null) {
      final vendorId = targetBooking['vendorId']?.toString() ?? '';
      final vehicleType = targetBooking['vehicleType']?.toString() ?? 'Car';

      if (vendorId.isNotEmpty) {
        final completedUrl =
            '${ApiConfig.baseUrl}vendor/getbookingdata/$vendorId/$vehicleType/completed';
        final value = box.get(completedUrl);
        List<dynamic> bookings = [];
        if (value != null) {
          try {
            final decoded = jsonDecode(value as String);
            if (decoded is Map && decoded['bookings'] is List) {
              bookings = List<dynamic>.from(decoded['bookings']);
            }
          } catch (_) {}
        }

        // Remove it if it somehow already exists in the completed cache to avoid duplicates
        bookings.removeWhere(
          (b) =>
              b['_id'] == bookingId ||
              b['id'] == bookingId ||
              b['offlineId'] == bookingId,
        );

        bookings.insert(0, targetBooking);
        await box.put(completedUrl, jsonEncode({'bookings': bookings}));
      }
    }
  }

  static void applyPendingExitsToMaps(List<Map<String, dynamic>> maps) {
    final actions = getPendingActions();
    final exitPayloads = <String, Map<String, dynamic>>{};
    for (var a in actions) {
      if (a['type'] == 'EXIT_BOOKING') {
        final payload = a['payload'] as Map<String, dynamic>? ?? {};
        final bookingId = payload['bookingId']?.toString() ?? '';
        if (bookingId.isNotEmpty) {
          exitPayloads[bookingId] = payload;
        }
      }
    }

    if (exitPayloads.isEmpty) return;

    for (var m in maps) {
      final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
      if (id.isNotEmpty && exitPayloads.containsKey(id)) {
        final payload = exitPayloads[id]!;
        m['status'] = 'COMPLETED';
        final now = DateTime.now();
        m['exitvehicledate'] =
            payload['exitvehicledate'] ??
            "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
        m['exitvehicletime'] =
            payload['exitvehicletime'] ??
            "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

        if (payload['amount'] != null) {
          m['amount'] = payload['amount'].toString();
          m['totalamout'] = payload['amount'].toString();
        }
        if (payload['totalamout'] != null) {
          m['totalamout'] = payload['totalamout'].toString();
        }
        if (payload['paymentMode'] != null) {
          m['paymentMode'] = payload['paymentMode'];
          m['paymentmode'] = payload['paymentMode'];
        }
        m['isOfflineExit'] = true;
      }
    }
  }

  /// Retrieves all cached bookings from dashboard endpoints to use as fallback for search.
  static List<Map<String, dynamic>> getAllCachedDashboardBookings(
    String vendorId,
  ) {
    final box = Hive.box(apiCacheBoxName);
    List<Map<String, dynamic>> allBookings = [];

    for (var key in box.keys) {
      if (key.toString().contains('vendor/getbookingdata/$vendorId/')) {
        final existing = box.get(key);
        if (existing != null) {
          try {
            final decoded = jsonDecode(existing as String);
            if (decoded is Map && decoded['bookings'] is List) {
              for (var b in decoded['bookings']) {
                if (b is Map<String, dynamic>) {
                  allBookings.add(b);
                } else if (b is Map) {
                  allBookings.add(Map<String, dynamic>.from(b));
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    // Remove duplicates based on _id
    final uniqueBookings = <String, Map<String, dynamic>>{};
    for (var b in allBookings) {
      final id = b['_id']?.toString() ?? b['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        uniqueBookings[id] = b;
      }
    }
    return uniqueBookings.values.toList();
  }

  /// Scans through all local caches and replaces the temporary offline ID with the real online ID.
  /// Preserves the old offline ID by moving it to an `offlineId` field.
  static Future<void> replaceOfflineIdInCache(
    String offlineId,
    String realId,
  ) async {
    // Save permanent mapping so receipts printed online still use the offline ID
    await saveOfflineIdMapping(realId, offlineId);

    final box = Hive.box(apiCacheBoxName);
    for (var key in box.keys) {
      if (key.toString().contains('vendor/getbookingdata/')) {
        final existing = box.get(key);
        if (existing != null) {
          try {
            final decoded = jsonDecode(existing as String);
            bool modified = false;
            if (decoded is Map && decoded['bookings'] is List) {
              for (var b in decoded['bookings']) {
                if (b is Map) {
                  if (b['_id'] == offlineId ||
                      b['id'] == offlineId ||
                      b['offlineId'] == offlineId) {
                    b['_id'] = realId; // Replaced with actual API ID
                    b['id'] = realId; // Replaced with actual API ID
                    b['offlineId'] =
                        offlineId; // Original offline ID is kept here
                    b['isOffline'] = false;
                    modified = true;
                  }
                }
              }
            }
            if (modified) {
              await box.put(key, jsonEncode(decoded));
            }
          } catch (_) {}
        }
      }
    }
  }

  /// Replaces an offline ID with a real ID inside the pending sync queue.
  /// This is critical if a booking was created offline and subsequently updated/exited offline.
  static Future<void> replaceOfflineIdInPending(
    String offlineId,
    String realId,
  ) async {
    final box = Hive.box(pendingSyncBoxName);
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        try {
          final decoded = jsonDecode(value as String) as Map<String, dynamic>;
          bool modified = false;
          final payload = decoded['payload'];
          if (payload is Map) {
            if (payload['bookingId'] == offlineId) {
              payload['bookingId'] = realId;
              modified = true;
            }
            if (payload['_id'] == offlineId) {
              payload['_id'] = realId;
              modified = true;
            }
          }
          if (modified) {
            await box.put(key, jsonEncode(decoded));
          }
        } catch (_) {}
      }
    }
  }

  /// Searches the cache for a booking, matching either the real online `_id` or the `offlineId`.
  static Map<String, dynamic>? findBookingInCache(String bookingId) {
    final box = Hive.box(apiCacheBoxName);
    for (var key in box.keys) {
      if (key.toString().contains('vendor/getbookingdata/')) {
        final existing = box.get(key);
        if (existing != null) {
          try {
            final decoded = jsonDecode(existing as String);
            if (decoded is Map && decoded['bookings'] is List) {
              for (var b in decoded['bookings']) {
                if (b is Map) {
                  final id = b['_id']?.toString() ?? b['id']?.toString() ?? '';
                  final offId = b['offlineId']?.toString() ?? '';
                  // Matches either the online ID or the offline ID from the printed receipt
                  if (id == bookingId || offId == bookingId) {
                    return Map<String, dynamic>.from(b);
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Resolves an offline PMW_ ID to the actual server `_id` before asking the backend to process it.
  static String resolveRealIdFromOfflineId(String bookingId) {
    final cached = findBookingInCache(bookingId);
    if (cached != null) {
      final id = cached['_id']?.toString() ?? cached['id']?.toString() ?? '';
      if (id.isNotEmpty && id != bookingId) {
        return id;
      }
    }
    return bookingId;
  }
}
