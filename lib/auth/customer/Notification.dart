import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:mywheels/config/authconfig.dart' show ApiConfig;
import 'package:mywheels/config/colorcode.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../pageloader.dart';

class NotificationScreen extends StatefulWidget {
  final String userid;
  const NotificationScreen({super.key, required this.userid});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isLoading = true;
  bool notificationsEnabled = false;
  bool permissionRequested = false;

  @override
  void initState() {
    super.initState();
    _initNotificationStatus();
  }

  Future<void> _initNotificationStatus() async {
    await _checkNotificationStatus();
    await _loadNotifications();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await Permission.notification.status;
    debugPrint('Notification status: $status');
    setState(() {
      notificationsEnabled = status.isGranted;
      permissionRequested = status.isPermanentlyDenied ||
          status.isGranted ||
          status.isDenied;
    });
  }

  Future<void> _loadNotifications() async {
    try {
      await fetchNotifications(widget.userid);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleNotificationPermission() async {
    setState(() => permissionRequested = true);

    final status = await Permission.notification.request();
    debugPrint('Permission request result: $status');

    if (status.isGranted) {
      setState(() => notificationsEnabled = true);
    } else if (status.isPermanentlyDenied) {
      if (mounted) _showPermissionDeniedDialog();
    }

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      setState(() => permissionRequested = true);
    }

    if (mounted) await _loadNotifications();
  }

  void _showPermissionDeniedDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications Disabled',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable notifications in your device settings to receive updates.',
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
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
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
                    'Open Settings',
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
    );
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
    );

    if (confirmed == true) {
      await _clearAllNotifications();
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/clearusernotifications/${widget.userid}');
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications cleared successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _loadNotifications();
        }
      } else {
        throw Exception('Failed to clear notifications: ${response.statusCode} - ${response.body}');
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

  Future<void> deleteNotification(String notificationId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}vendor/notification/$notificationId');
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification deleted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    try {
      final url = '${ApiConfig.baseUrl}vendor/getusernotification/$userId';
      print('Requesting URL: $url');

      final response = await http.get(Uri.parse(url));

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Parsed JSON Data: $jsonData');

        if (jsonData['success'] == true) {
          final notifications = jsonData['notifications'] as List;
          print('Notifications List Length: ${notifications.length}');

          return notifications
              .map((item) => NotificationModel.fromJson(item))
              .toList();
        } else {
          print('Request failed: success flag is false');
        }
      } else {
        print('Failed to load notifications: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingGif();
    }

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        // backgroundColor: ColorUtils.primarycolor(),
        title: Text('Notifications',
            style: GoogleFonts.poppins(color: Colors.black)),
        actions: [
          IconButton(
            onPressed: _showClearAllConfirmation,
            icon: const Icon(Icons.delete_forever, color: Colors.black),
            tooltip: 'Clear All Notifications',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!notificationsEnabled && !permissionRequested)
              _buildPermissionBanner(isIOS),
            Expanded(
              child: FutureBuilder<List<NotificationModel>>(
                future: fetchNotifications(widget.userid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Image.asset('assets/gifload.gif'),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return _buildErrorState();
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }
        
                  final notifications = snapshot.data!;
                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(notifications[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(bool isIOS) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border(
          bottom: BorderSide(color: Colors.amber[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isIOS ? CupertinoIcons.bell_slash : Icons.notifications_off,
            color: Colors.amber[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Notifications',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get important updates about your bookings',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isIOS)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _handleNotificationPermission,
              child: Text(
                'Enable',
                style: GoogleFonts.poppins(
                  color: ColorUtils.primarycolor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primarycolor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
              ),
              onPressed: _handleNotificationPermission,
              child: Text(
                'ENABLE',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final isSlotCancelled = notification.title.contains("Cancelled");
    final color = isSlotCancelled ? Colors.red : ColorUtils.primarycolor();

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
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
        );
      },
      onDismissed: (_) async {
        await deleteNotification(notification.id);
        await _loadNotifications();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Card(color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.2), width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // onTap: () => _navigateToDetails(notification),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.circle,
                        color: color,
                        size: 8,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notification.ndtime,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notification.message,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (notification.vehicleNumber.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${notification.vehicleType} • ${notification.vehicleNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primarycolor(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(
          Icons.notifications_none,
          size: 80,
          color: ColorUtils.primarycolor(),
        ),
        // const SizedBox(height: 20),
        Text(
          'No Notifications Yet',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        // const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
              notificationsEnabled
                  ? 'You\'ll see important updates here'
            :""
          ),
        ),
          ],
        ),
      ),
    );
  }


}

class NotificationModel {
  final String id;
  final String vendorId;
  final String userId;
  final String bookingId;
  final String title;
  final String message;
  final String vehicleType;
  final String vehicleNumber;
  final DateTime createdAt;
  final bool read;
  final String bookingDate;
  final String bookingtype;
  final String sts;
  final String vendorname;
  final String otp;
  final String schedule;
  final String parkingDate;
  final String bookingdate;
  final String status;
  final String parkingTime;
  final String ndtime;

  NotificationModel({
    required this.id,
    required this.vendorId,
    required this.userId,
    required this.bookingId,
    required this.title,
    required this.message,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.createdAt,
    required this.read,
    required this.bookingDate,
    required this.bookingtype,
    required this.sts,
    required this.vendorname,
    required this.otp,
    required this.schedule,
    required this.parkingDate,
    required this.bookingdate,
    required this.status,
    required this.parkingTime,
    required this.ndtime,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? '',
      vendorId: json['vendorId'] ?? '',
      userId: json['userId'] ?? '',
      bookingId: json['bookingId'] ?? '',
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      read: json['read'] ?? false,
      bookingDate: json['bookingDate'] ?? '',
      bookingtype: json['bookingtype'] ?? '',
      sts: json['sts'] ?? '',
      vendorname: json['vendorname'] ?? '',
      otp: json['otp']?.toString() ?? '',
      schedule: json['schedule'] ?? '',
      parkingDate: json['parkingDate'] ?? '',
      bookingdate: json['bookingdate'] ?? '',
      status: json['status'] ?? '',
      parkingTime: json['parkingTime'] ?? '',
      ndtime:json['notificationdtime'] ?? '',
    );
  }
}