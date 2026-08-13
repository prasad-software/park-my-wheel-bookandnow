import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'dart:convert';
import '../../config/colorcode.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'No Title',
      message: json['message'] ?? 'No Message',
      createdAt: json['notificationdtime'] ?? json['createdAt'] ?? DateTime.now().toString(),
    );
  }
}

Future<void> clearAllNotifications(String vendorId) async {
  final url = Uri.parse('${ApiConfig.baseUrl}vendor/notifications/vendor/$vendorId');
  final response = await http.delete(
    url,
    headers: {'Content-Type': 'application/json'},
  ).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('Failed to clear notifications: ${response.statusCode}');
  }
}

Future<void> deleteNotification(String notificationId) async {
  final url = Uri.parse('${ApiConfig.baseUrl}vendor/notification/$notificationId');
  try {
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        // Add 'Authorization': 'Bearer YOUR_TOKEN' if required
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return; // Success
    } else {
      throw Exception('Failed to delete notification: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    throw Exception('Failed to delete notification: $e');
  }
}
Future<List<NotificationModel>> fetchNotifications(String vendorId) async {
  final url = Uri.parse('${ApiConfig.baseUrl}vendor/fetchnotification/$vendorId');

  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(response.body);
      if (decodedBody['notifications'] is List) {
        return (decodedBody['notifications'] as List)
            .map((e) => NotificationModel.fromJson(e))
            .toList();
      }
      return [];
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to fetch notifications: ${e.toString()}');
  }
}

class VendorNotificationScreen extends StatefulWidget {
  final String vendorid;
  const VendorNotificationScreen({super.key, required this.vendorid});

  @override
  State<VendorNotificationScreen> createState() => _VendorNotificationScreenState();
}

class _VendorNotificationScreenState extends State<VendorNotificationScreen> {
  late Future<List<NotificationModel>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notificationsFuture = fetchNotifications(widget.vendorid);
    });
  }

  Future<void> _showClearAllConfirmation() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clear All Notifications',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to clear all notifications? This action cannot be undone.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size(120, 35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[800],
                      elevation: 2,
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size(120, 35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      backgroundColor: ColorUtils.primarycolor(),
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _clearAllNotifications();
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await clearAllNotifications(widget.vendorid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear notifications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteNotification(String notificationId) async {
    try {
      await deleteNotification(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted Successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showClearAllConfirmation,
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            tooltip: "Clear All",
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadNotifications();
            await _notificationsFuture;
          },
          child: FutureBuilder<List<NotificationModel>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Image.asset('assets/gifload.gif'));
              }
        
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load notifications',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: Text('Retry', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                );
              }
        
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
        
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isCancelled = notification.title.toLowerCase().contains("cancelled");
        
                  return Dismissible(
                    key: Key(notification.id),
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showModalBottomSheet<bool>(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        backgroundColor: Colors.white,
                        builder: (context) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete Notification',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Are you sure you want to delete this notification?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      style: ElevatedButton.styleFrom(
                                        fixedSize: const Size(120, 35),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                          side: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        backgroundColor: Colors.grey[200],
                                        foregroundColor: Colors.grey[800],
                                        elevation: 2,
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        fixedSize: const Size(120, 35),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        backgroundColor: ColorUtils.primarycolor(),
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                      ),
                                      child: Text(
                                        'Delete',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    onDismissed: (_) => _handleDeleteNotification(notification.id),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isCancelled
                              ? Colors.red.withOpacity(0.3)
                              : ColorUtils.primarycolor().withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isCancelled ? Colors.red : Colors.black,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCancelled
                                        ? Colors.red.withOpacity(0.1)
                                        : ColorUtils.primarycolor().withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(notification.createdAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isCancelled ? Colors.red : ColorUtils.primarycolor(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCancelled
                                        ? Colors.red.withOpacity(0.1)
                                        : ColorUtils.primarycolor().withOpacity(0.1),
                                  ),
                                  child: Icon(
                                    isCancelled ? Icons.cancel_outlined : Icons.notifications_active_outlined,
                                    color: isCancelled ? Colors.red : ColorUtils.primarycolor(),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    notification.message,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}