import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/foundation.dart';
// import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../config/colorcode.dart';

class VendorPrivacy extends StatefulWidget {
  const VendorPrivacy({super.key});

  @override
  State<VendorPrivacy> createState() => _VendorPrivacyState();
}

class _VendorPrivacyState extends State<VendorPrivacy> {
  late final WebViewController _controller;
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true); // Track loading state

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
    WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _isLoading.value = true; // Show loading indicator
          },
          onPageFinished: (String url) {
            _isLoading.value = false; // Hide loading indicator
          },
        ),
      )
      ..loadRequest(Uri.parse('https://parkmywheelsprivacy.vercel.app/privacy-terms'));

    if (kIsWeb || !Platform.isMacOS) {
      controller.setBackgroundColor(const Color(0x80000000));
    }

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.primarycolor(),
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Privacy & Policy',
          style: GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller), // WebView
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) {
              return
                   const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }
}
class dataprivacy extends StatefulWidget {
  const dataprivacy({super.key});

  @override
  State<dataprivacy> createState() => _dataprivacyState();
}

class _dataprivacyState extends State<dataprivacy> {
  late final WebViewController _controller;
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true); // Track loading state

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
    WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _isLoading.value = true; // Show loading indicator
          },
          onPageFinished: (String url) {
            _isLoading.value = false; // Hide loading indicator
          },
        ),
      )
      ..loadRequest(Uri.parse('https://parkmywheelsprivacy.vercel.app/data-privacy'));

    if (kIsWeb || !Platform.isMacOS) {
      controller.setBackgroundColor(const Color(0x80000000));
    }

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.primarycolor(),
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: ColorUtils.secondarycolor(),
        title: Text(
          'Privacy & Policy',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller), // WebView
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) {
              return isLoading
                  ? Center(
                child: Image.asset(
                  'assets/gifload.gif', // Replace with your loading image
                  width: 450,

                ),
              )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }
}

