import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionChecker {
  // Global navigator key for showing dialogs from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Check for app updates and handle the update flow
  static Future<void> checkForUpdate(BuildContext? context, {bool forceUpdate = false, bool flexible = false}) async {
    debugPrint('🔍 [AppUpdate] Starting update check...');
    try {
      // Check if installed from Play Store
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint('📦 [AppUpdate] Package: ${packageInfo.packageName}, Version: ${packageInfo.version}, Build: ${packageInfo.buildNumber}');

      if (packageInfo.packageName != 'com.park.mywheels') {
        debugPrint('⚠️ [AppUpdate] App not installed from Play Store (${packageInfo.packageName}), skipping update check');
        return;
      }

      // Note: In-app updates only work on release builds installed from Play Store
      if (kDebugMode) {
        debugPrint('⚠️ [AppUpdate] Running in DEBUG mode - In-app updates require RELEASE build from Play Store');
        debugPrint('⚠️ [AppUpdate] In-app updates will not work in debug mode. Build a release APK and install from Play Store.');
      }

      debugPrint('🔍 [AppUpdate] Calling InAppUpdate.checkForUpdate()...');
      // Get update info
      final updateInfo = await InAppUpdate.checkForUpdate();
      debugPrint('📊 [AppUpdate] Update availability: ${updateInfo.updateAvailability}');
      debugPrint('📊 [AppUpdate] Immediate update allowed: ${updateInfo.immediateUpdateAllowed}');
      debugPrint('📊 [AppUpdate] Flexible update allowed: ${updateInfo.flexibleUpdateAllowed}');
      debugPrint('📊 [AppUpdate] Available version code: ${updateInfo.availableVersionCode}');
      debugPrint('📊 [AppUpdate] Client version staleness days: ${updateInfo.clientVersionStalenessDays}');
      debugPrint('📊 [AppUpdate] Install status: ${updateInfo.installStatus}');
      debugPrint('📊 [AppUpdate] Install update status: ${updateInfo.updatePriority}');

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('✅ [AppUpdate] Update is available!');
        if (forceUpdate || (updateInfo.immediateUpdateAllowed && !flexible)) {
          debugPrint('🚀 [AppUpdate] Starting immediate update...');
          try {
            await InAppUpdate.performImmediateUpdate();
            debugPrint('✅ [AppUpdate] Immediate update started - app will restart');
          } catch (e) {
            debugPrint('❌ [AppUpdate] Immediate update failed: $e');
            // If immediate update fails, try flexible update instead
            if (updateInfo.flexibleUpdateAllowed) {
              debugPrint('🔄 [AppUpdate] Falling back to flexible update...');
              _tryFlexibleUpdate(context);
            } else {
              _showUpdateErrorDialog(context);
            }
          }
        } else if (updateInfo.flexibleUpdateAllowed) {
          _tryFlexibleUpdate(context);
        } else {
          debugPrint('⚠️ [AppUpdate] Update available but neither immediate nor flexible update is allowed');
          // Still show a dialog to inform user to update from Play Store
          _showUpdateAvailableDialog(context);
        }
      } else if (updateInfo.updateAvailability == UpdateAvailability.updateNotAvailable) {
        debugPrint('✅ [AppUpdate] App is up to date - no update available');
      } else if (updateInfo.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        debugPrint('🔄 [AppUpdate] Developer-triggered update in progress');
      } else {
        debugPrint('⚠️ [AppUpdate] Unknown update availability status: ${updateInfo.updateAvailability}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AppUpdate] Error checking for updates: $e');
      debugPrint('📚 [AppUpdate] Stack trace: $stackTrace');
      // Don't show error dialog for the "app not owned" error (common in debug mode)
      if (e.toString().contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('ℹ️ [AppUpdate] App not owned error (normal in debug/dev builds)');
      } else {
        debugPrint('⚠️ [AppUpdate] Showing error dialog to user');
        _showUpdateErrorDialog(context);
      }
    }
    debugPrint('🏁 [AppUpdate] Update check completed');
  }

  /// Try to start flexible update
  static void _tryFlexibleUpdate(BuildContext? context) {
    debugPrint('🚀 [AppUpdate] Starting flexible update...');
    try {
      InAppUpdate.startFlexibleUpdate().then((result) {
        debugPrint('📊 [AppUpdate] Flexible update result: $result');
        if (result == AppUpdateResult.success) {
          debugPrint('✅ [AppUpdate] Flexible update started successfully');
          // Wait a bit for the update to download, then show dialog
          Future.delayed(const Duration(seconds: 2), () {
            _showUpdateDialog(context);
          });
        } else {
          debugPrint('❌ [AppUpdate] Flexible update failed with result: $result');
          _showUpdateErrorDialog(context);
        }
      }).catchError((e) {
        debugPrint('❌ [AppUpdate] Error starting flexible update: $e');
        _showUpdateErrorDialog(context);
      });
    } catch (e) {
      debugPrint('❌ [AppUpdate] Exception starting flexible update: $e');
      _showUpdateErrorDialog(context);
    }
  }

  /// Show dialog when update is available but in-app update not allowed
  static void _showUpdateAvailableDialog(BuildContext? context) {
    debugPrint('💬 [AppUpdate] Attempting to show update available dialog...');
    final dialogContext = context ?? navigatorKey.currentContext;
    if (dialogContext == null) {
      debugPrint('❌ [AppUpdate] Navigator context not available for update available dialog');
      // Retry after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _showUpdateAvailableDialog(context);
      });
      return;
    }
    debugPrint('✅ [AppUpdate] Showing update available dialog to user');

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of the app is available on the Google Play Store. Please update to continue using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Update Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Could launch Play Store here if needed
            },
            child: const Text('Open Play Store'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to prompt user to complete the flexible update
  static void _showUpdateDialog(BuildContext? context) {
    debugPrint('💬 [AppUpdate] Attempting to show update dialog...');
    final dialogContext = context ?? navigatorKey.currentContext;
    if (dialogContext == null) {
      debugPrint('❌ [AppUpdate] Navigator context not available for update dialog - retrying...');
      // Retry after a delay if context isn't ready
      Future.delayed(const Duration(seconds: 1), () {
        _showUpdateDialog(context);
      });
      return;
    }
    debugPrint('✅ [AppUpdate] Showing update dialog to user');

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of the app is ready to install. Would you like to update now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              InAppUpdate.completeFlexibleUpdate().catchError((e) {
                debugPrint('Error completing update: $e');
              });
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog when update check or process fails
  static void _showUpdateErrorDialog(BuildContext? context) {
    debugPrint('💬 [AppUpdate] Attempting to show error dialog...');
    final dialogContext = context ?? navigatorKey.currentContext;
    if (dialogContext == null) {
      debugPrint('❌ [AppUpdate] Navigator context not available for error dialog');
      return;
    }
    debugPrint('✅ [AppUpdate] Showing error dialog to user');

    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Update Error'),
        content: const Text(
          'Could not check for updates. Please update the app from the Google Play Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Test method to show update UI (for development only)
  static void testUpdateUI() {
    if (kDebugMode && navigatorKey.currentContext != null) {
      _showUpdateDialog(null);
    }
  }
}