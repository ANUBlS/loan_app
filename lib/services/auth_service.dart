import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/l10n.dart';

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

  L10n get _l => L10n.instance;

  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRegistered) ?? false;
  }

  Future<String> userName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName) ?? '';
  }

  Future<String> userPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPhone) ?? '';
  }

  Future<void> register({required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kPhone, phone);
    await prefs.setBool(_kRegistered, true);
  }

  /// Removes the user but keeps device settings such as the language.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kName);
    await prefs.remove(_kPhone);
    await prefs.remove(_kRegistered);
  }

  /// Checks that the device has a sensor AND at least one enrolled finger/face.
  Future<AuthResult> checkAvailability() async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return AuthResult.fail(_l.t('auth.err_unsupported'));
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (!canCheck || enrolled.isEmpty) {
        return AuthResult.fail(_l.t('auth.err_not_enrolled'));
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
          : AuthResult.fail(_l.t('auth.err_cancelled'));
    } on PlatformException catch (e) {
      return AuthResult.fail(_describe(e));
    }
  }

  String _describe(PlatformException e) {
    switch (e.code) {
      case auth_error.notEnrolled:
        return _l.t('auth.err_not_enrolled');
      case auth_error.notAvailable:
        return _l.t('auth.err_not_available');
      case auth_error.passcodeNotSet:
        return _l.t('auth.err_passcode');
      case auth_error.lockedOut:
        return _l.t('auth.err_locked');
      case auth_error.permanentlyLockedOut:
        return _l.t('auth.err_perm_locked');
      default:
        return _l.t('auth.err_generic', {'code': e.code});
    }
  }
}
