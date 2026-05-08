import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'database_service.dart';

class LocationService {
  static Timer? _trackingTimer;
  static String? _trackingTeamId;

  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static void startTracking(String teamId) {
    if (_trackingTeamId == teamId && _trackingTimer != null) return;
    stopTracking();
    _trackingTeamId = teamId;

    _uploadLocation(teamId);
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _uploadLocation(teamId);
    });
  }

  static Future<void> _uploadLocation(String teamId) async {
    final pos = await getCurrentPosition();
    if (pos != null) {
      await DatabaseService.updateTeamLocation(teamId, pos.latitude, pos.longitude);
    }
  }

  static void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _trackingTeamId = null;
  }

  static double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // km
  }
}
