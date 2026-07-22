import 'package:device_info_plus/device_info_plus.dart';

/// Resolves a stable-per-install identifier for the device.
///
/// On Android this uses the ANDROID_ID, which is unique per app-signing-key +
/// device + user. Good enough for the MVP anti-impersonation constraint: the
/// same physical phone cannot mark attendance for two different students in the
/// same session.
class DeviceService {
  static String? _cached;

  static Future<String> deviceId() async {
    if (_cached != null) return _cached!;
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    _cached = android.id; // ANDROID_ID
    return _cached!;
  }
}
