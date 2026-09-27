import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final bool success;
  final String? message;

  const AuthResult.ok()
      : success = true,
        message = null;

  const AuthResult.fail(this.message) : success = false;
}

class AuthService {
  static const _kRegistered = 'registered';
  static const _kName = 'user_name';
  static const _kPhone = 'user_phone';

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRegistered) ?? false;
  }

  Future<String> userName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName) ?? '';
  }

  Future<void> register({required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kPhone, phone);
    await prefs.setBool(_kRegistered, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Checks that the device has a sensor AND at least one enrolled finger/face.
  Future<AuthResult> checkAvailability() async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return const AuthResult.fail(
            'This device does not support biometric login.');
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (!canCheck || enrolled.isEmpty) {
        return const AuthResult.fail(
            'No fingerprint or face is enrolled. Add one in your device settings, then try again.');
      }
      return const AuthResult.ok();
    } on PlatformException catch (e) {
      return AuthResult.fail(_describe(e));
    }
  }

  /// Biometrics only - no PIN fallback.
  Future<AuthResult> authenticate(String reason) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok
          ? const AuthResult.ok()
          : const AuthResult.fail('Biometric check was cancelled.');
    } on PlatformException catch (e) {
      return AuthResult.fail(_describe(e));
    }
  }

  String _describe(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return 'No fingerprint or face is enrolled. Add one in your device settings.';
      case auth_error.notAvailable:
        return 'Biometric login is not available on this device.';
      case auth_error.passcodeNotSet:
        return 'Set a screen lock (PIN, pattern or password) on this device first.';
      case auth_error.lockedOut:
        return 'Too many attempts. Wait 30 seconds and try again.';
      case auth_error.permanentlyLockedOut:
        return 'Biometrics are locked. Unlock your device with its PIN, then try again.';
      default:
        return e.message ?? 'Biometric check failed (${e.code}).';
    }
  }
}
