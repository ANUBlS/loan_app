import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Hide amounts" (eye icon on the home screen), saved on the device.
///
/// Loaded once in main() before runApp, so the first frame already shows
/// the saved state; every change is written to SharedPreferences.
class AmountVisibility extends ChangeNotifier {
  AmountVisibility._();
  static final AmountVisibility instance = AmountVisibility._();

  static const _key = 'hide_amounts';

  bool _hidden = false;
  bool get hidden => _hidden;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hidden = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> setHidden(bool value) async {
    if (value == _hidden) return;
    _hidden = value;
    notifyListeners(); // update the screen first, then save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  Future<void> toggle() => setHidden(!_hidden);
}
