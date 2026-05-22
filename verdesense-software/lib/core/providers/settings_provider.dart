import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  double _temperatureThreshold = 38.0;
  double _smokeThreshold = 300.0;
  double _flameThreshold = 200.0;

  double get temperatureThreshold => _temperatureThreshold;
  double get smokeThreshold => _smokeThreshold;
  double get flameThreshold => _flameThreshold;

  void setTemperatureThreshold(double value) {
    if (_temperatureThreshold != value) {
      _temperatureThreshold = value;
      notifyListeners();
    }
  }

  void setSmokeThreshold(double value) {
    if (_smokeThreshold != value) {
      _smokeThreshold = value;
      notifyListeners();
    }
  }

  void setFlameThreshold(double value) {
    if (_flameThreshold != value) {
      _flameThreshold = value;
      notifyListeners();
    }
  }
}
