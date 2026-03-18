import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppUpdateService {
  static const String playStoreBaseUrl = 'https://play.google.com/store/apps/details?id=';
  static const String appStoreBaseUrl = 'https://apps.apple.com/in/app/your-app-id';
  
  // Add your app's package name
  static const String packageName = 'com.xesstechlink.instamarq';
  
  // Your API endpoint to check for updates
  static const String updateCheckUrl = 'https://nodeface.agniplay.com/api/update/check-update';

  static Future<Map<String, dynamic>?> checkForUpdate({required BuildContext context}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      
      // Get platform identifier
      String platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

      final url = '$updateCheckUrl?packageName=$packageName&version=$currentVersion&buildNumber=$buildNumber&platform=$platform';
      debugPrint('========================================');
      debugPrint('APP UPDATE CHECK API CALL');
      debugPrint('========================================');
      debugPrint('URL: $url');

      // Call your API to check for updates
      final response = await http.get(Uri.parse(url));

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.body}');
      debugPrint('========================================');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final String newVersion = data['newVersion'] ?? '';
          final bool isNewer = _isVersionLower(currentVersion, newVersion);
          
          return {
            'updateAvailable': isNewer,
            'isForceUpdate': data['isForceUpdate'] ?? false,
            'isUnsupported': data['isUnsupported'] ?? false,
            'currentVersion': data['currentVersion'] ?? currentVersion,
            'newVersion': data['newVersion'] ?? '',
            'currentBuildNumber': data['currentBuildNumber'] ?? buildNumber,
            'latestBuildNumber': data['latestBuildNumber'] ?? '',
            'releaseNotes': data['releaseNotes'] ?? 'Bug fixes and performance improvements',
            'downloadUrl': data['downloadUrl'] ?? _getStoreUrl(),
            'apkUrl': data['apkUrl'] ?? '',
            'appSize': data['appSize'] ?? '',
            'lastUpdated': data['lastUpdated'] ?? '',
            'platform': data['platform'] ?? platform,
            'minSupportedVersion': data['minSupportedVersion'] ?? '',
            'forceUpdateVersion': data['forceUpdateVersion'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  static String _getStoreUrl() {
    // Return Play Store URL for Android, App Store URL for iOS
    return '$playStoreBaseUrl$packageName';
  }

  /// Compares two version strings (e.g., "1.0.8" and "1.0.9").
  /// Returns true if [current] is lower than [latest].
  static bool _isVersionLower(String current, String latest) {
    if (latest.isEmpty) return false;
    
    try {
      final List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        final int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  static Future<void> launchAppStore() async {
    final url = _getStoreUrl();
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> showUpdateDialog({
    required BuildContext context,
    required bool isForceUpdate,
    required String newVersion,
    required String releaseNotes,
    required String appStoreUrl,
    String? appSize,
    String? currentVersion,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (BuildContext context) {
        return PopScope(
          canPop: !isForceUpdate,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  isForceUpdate ? Icons.system_update_alt : Icons.system_update,
                  color: isForceUpdate ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(isForceUpdate ? 'Required Update' : 'Update Available'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentVersion != null)
                  Text('Current version: $currentVersion', 
                       style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('New version: $newVersion', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                if (appSize != null) ...[
                  const SizedBox(height: 4),
                  Text('Size: $appSize', 
                       style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 16),
                // const Text('What\'s new:',
                //            style: TextStyle(fontWeight: FontWeight.bold)),
                // const SizedBox(height: 8),
                // Text(releaseNotes),
              ],
            ),
            actions: [
              if (!isForceUpdate)
              
              ElevatedButton(
                onPressed: () {
                  launchUrlString(appStoreUrl, mode: LaunchMode.externalApplication);
                  if (!isForceUpdate) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isForceUpdate ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(isForceUpdate ? 'Update Now' : 'Update'),
              ),
            ],
          ),
        );
      },
    );
  }
}
