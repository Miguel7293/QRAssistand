import 'package:geolocator/geolocator.dart';

/// Wraps GPS access: permission handling + reading the current position.
class LocationService {
  /// Returns the device's current position, requesting permission if needed.
  /// Throws a human-readable message on any failure so the UI can show it.
  static Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'El GPS está apagado. Actívalo para registrar asistencia.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'Permiso de ubicación denegado.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación bloqueado. Habilítalo en Ajustes.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
