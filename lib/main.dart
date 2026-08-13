import 'dart:async'; // Import this for Completer
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart' show AssetSource, AudioPlayer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/customer/Notification.dart';
import 'auth/customer/customerdash.dart';
import 'auth/customer/parking/parking.dart';
import 'auth/customer/splashregister/register.dart';
import 'auth/vendor/vendordash.dart';
import 'auth/vendor/vendornotificationpage.dart';
import 'config/app_version_checker.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? _pendingNotificationPayload;

// 🔔 Navigation helper - navigate to notification page based on user type
Future<void> navigateToNotificationPage() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('id');
  final vendorId = prefs.getString('vendorId');
  final context = navigatorKey.currentContext;
  if (context == null) return;
  if (userId != null && userId.isNotEmpty) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NotificationScreen(userid: userId)));
  } else if (vendorId != null && vendorId.isNotEmpty) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VendorNotificationScreen(vendorid: vendorId)));
  }
}

// 🔔 Handle notification tap - supports booking_slot and default notification page
Future<void> _handleNotificationTap(String? payload) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('id');
  final vendorId = prefs.getString('vendorId');
  final context = navigatorKey.currentContext;
  if (context == null) return;

  if (payload != null && payload.isNotEmpty) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>?;
      final type = data?['type'] as String?;
      if (type == 'booking_slot' && userId != null && userId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ParkingPage(userId: userId)));
        return;
      }
    } catch (_) {}
  }

  await navigateToNotificationPage();
}

// 🔔 Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Timer(Duration(seconds: 2), () {
  //   SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  // });
  // await SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.portraitUp,
  //   DeviceOrientation.portraitDown
  // ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Transparent status bar
    statusBarIconBrightness: Brightness.dark, // Dark icons for light backgrounds
    systemNavigationBarColor: Colors.transparent, // Transparent navigation bar
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: initSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      _handleNotificationTap(response.payload);
    },
  );

  // Create Android notification channel (no custom sound so default is always used if bell is missing)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Derive title/body from notification payload or data-only payload
    final String title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final String body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    if (title.isEmpty && body.isEmpty) return;

    final payload = jsonEncode(message.data);
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    final NotificationDetails detailsWithBell = NotificationDetails(
      android: Platform.isAndroid
          ? AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              sound: RawResourceAndroidNotificationSound('bell'),
            )
          : null,
      iOS: Platform.isIOS
          ? const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            )
          : null,
    );

    final NotificationDetails detailsDefaultSound = NotificationDetails(
      android: Platform.isAndroid
          ? const AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
            )
          : null,
      iOS: Platform.isIOS
          ? const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            )
          : null,
    );

    Future<void> showWithFallback() async {
      try {
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          detailsWithBell,
          payload: payload.isNotEmpty ? payload : null,
        );
      } catch (_) {
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          detailsDefaultSound,
          payload: payload.isNotEmpty ? payload : null,
        );
      }
    }
    showWithFallback();
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final payload = jsonEncode(message.data);
    _handleNotificationTap(payload);
  });

  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _pendingNotificationPayload = jsonEncode(initialMessage.data);
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    // badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return GetMaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final Completer<void> _audioCompleter = Completer<void>();
  late AnimationController _animationController;
  late List<Animation<double>> _letterAnimations;

  final String _text = "Smart Parking Made Easy";

  @override
  void initState() {
    super.initState();
    _playLogoSound();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _letterAnimations = List.generate(
      _text.length,
          (index) => Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index / _text.length, // Staggered effect
            1.0,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check for app updates (will show dialog if update needed)
      if (mounted) {
        AppVersionChecker.checkForUpdate(context, forceUpdate: false);
      }
      await _navigateToNextScreen();
    });
  }

  Future<void> _playLogoSound() async {
    try {
      await AudioManager().playAudio('logo.mp3');
      Future.delayed(const Duration(seconds: 3), () {
        if (!_audioCompleter.isCompleted) {
          _audioCompleter.complete();
        }
      });
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> _navigateToNextScreen() async {
    try {
      await _audioCompleter.future;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Widget initialScreen = await getInitialScreen(prefs);
      final pendingPayload = _pendingNotificationPayload;
      _pendingNotificationPayload = null;

      if (mounted) {
        Get.off(() => FadeInScreen(
          initialScreen: initialScreen,
          pendingNotificationPayload: pendingPayload,
        ));
      }
    } catch (e) {
      debugPrint("Error navigating to next screen: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 90.0,right: 90),
              child: Image.asset('assets/gifload.gif'),
            ),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return RichText(
                  text: TextSpan(
                    children: List.generate(
                      _text.length,
                          (index) => WidgetSpan(
                        child: Transform.translate(
                          offset: Offset(_letterAnimations[index].value * 50, 0), // Moves from right
                          child: Opacity(
                            opacity: 1.0 - _letterAnimations[index].value, // Fades in
                            child: Text(
                              _text[index],
                              style: GoogleFonts.poppins(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  final AudioPlayer _audioPlayer = AudioPlayer();

  factory AudioManager() => _instance;

  AudioManager._internal();

  Future<void> playAudio(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  void stopAudio() {
    _audioPlayer.stop();
  }
}

class FadeInScreen extends StatefulWidget {
  final Widget initialScreen;
  final String? pendingNotificationPayload;

  const FadeInScreen({
    super.key,
    required this.initialScreen,
    this.pendingNotificationPayload,
  });

  @override
  _FadeInScreenState createState() => _FadeInScreenState();
}

class _FadeInScreenState extends State<FadeInScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();

    if (widget.pendingNotificationPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _handleNotificationTap(widget.pendingNotificationPayload);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: widget.initialScreen,
    );
  }
}

Future<Widget> getInitialScreen(SharedPreferences prefs) async {
  int? loginStatus = prefs.getInt('login_status');
  if (loginStatus == 1) {
    String? userId = prefs.getString('id');
    String? vendorId = prefs.getString('vendorId');

    if (userId != null && userId.isNotEmpty) {
      return customdashScreen(userId: userId);
    } else if (vendorId != null && vendorId.isNotEmpty) {
      return vendordashScreen(vendorid: vendorId);
    }
  }
  return const splashlogin();
}