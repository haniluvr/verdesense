import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SirenProvider with ChangeNotifier {
  String? _activeSirenTitle;
  IconData? _activeSirenIcon;
  Color? _activeSirenColor;

  String? get activeSirenTitle => _activeSirenTitle;
  IconData? get activeSirenIcon => _activeSirenIcon;
  Color? get activeSirenColor => _activeSirenColor;

  bool get isSirenActive => _activeSirenTitle != null;

  bool _isBottomNavVisible = false;
  bool get isBottomNavVisible => _isBottomNavVisible;

  /// Cached list of device MAC keys (populated by the dashboard)
  List<String> _deviceKeys = [];

  void setDeviceKeys(List<String> keys) {
    _deviceKeys = keys;
  }

  void setBottomNavVisibility(bool isVisible) {
    if (_isBottomNavVisible != isVisible) {
      _isBottomNavVisible = isVisible;
      notifyListeners();
    }
  }

  void activateSiren(String title, IconData icon, Color color) {
    _activeSirenTitle = title;
    _activeSirenIcon = icon;
    _activeSirenColor = color;
    notifyListeners();

    // Reverting to the simpler variable names as requested:
    // EVACUATION SIREN -> siren_alert_active: true
    // SAFETY ALERT     -> siren_clear_active: true
    if (title == "EVACUATION SIREN") {
      _writeToAllDevices({
        'siren_alert_active': true,
        'siren_clear_active': false,
      });
    } else if (title == "SAFETY ALERT") {
      _writeToAllDevices({
        'siren_alert_active': false,
        'siren_clear_active': true,
      });
    }
  }

  /// Activate siren from a REMOTE source (ESP32 auto-trigger via Firebase).
  /// This updates the local UI state WITHOUT writing back to Firebase,
  /// avoiding a circular write loop.
  void activateSirenFromRemote(String title, IconData icon, Color color) {
    // Skip if this exact siren is already active locally
    if (_activeSirenTitle == title) return;
    _activeSirenTitle = title;
    _activeSirenIcon = icon;
    _activeSirenColor = color;
    notifyListeners();
  }

  /// Deactivate siren from a REMOTE source (ESP32 auto-deactivation via Firebase).
  /// Only clears local UI state, does NOT write to Firebase.
  void deactivateSirenFromRemote() {
    if (_activeSirenTitle == null) return;
    _activeSirenTitle = null;
    _activeSirenIcon = null;
    _activeSirenColor = null;
    notifyListeners();
  }

  void terminateSiren() {
    _activeSirenTitle = null;
    _activeSirenIcon = null;
    _activeSirenColor = null;
    notifyListeners();

    // Reset both to false to deactivate
    _writeToAllDevices({
      'siren_alert_active': false,
      'siren_clear_active': false,
    });
  }

  /// Writes the given fields to every known device under sensor_data/{MAC}/.
  Future<void> _writeToAllDevices(Map<String, dynamic> fields) async {
    if (_deviceKeys.isEmpty) return;

    final sensorsRef = FirebaseDatabase.instance.ref().child('sensor_data');

    for (final mac in _deviceKeys) {
      try {
        await sensorsRef.child(mac).update(fields);
      } catch (_) {}
    }
  }
}
