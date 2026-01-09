import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static Future<Map<String, double>?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('Location obtained: Lat=${position.latitude}, Lon=${position.longitude}');
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    try {
      // Try to open app settings using geolocator
      await Geolocator.openAppSettings();
    } catch (e) {
      print('Error opening app settings with geolocator: $e');
      // Fallback: try to open settings using url_launcher
      try {
        final Uri settingsUri = Uri.parse('app-settings:');
        if (await canLaunchUrl(settingsUri)) {
          await launchUrl(settingsUri);
        }
      } catch (e) {
        print('Could not open app settings: $e');
      }
    }
  }
}
