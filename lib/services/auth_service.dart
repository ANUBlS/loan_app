import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

/// Result of a passcode check.
class PinCheck {
  final bool ok;
  final int attemptsLeft;
  final Duration? lockedFor;

  const PinCheck.ok()
      : ok = true,
        attemptsLeft = 0,
        lockedFor = null;
  const PinCheck.wrong(this.attemptsLeft)
      : ok = false,
        lockedFor = null;
  const PinCheck.locked(Duration this.lockedFor)
      : ok = false,
        attemptsLeft = 0;
}

class AuthService {
  static const pinLength = 6;
  static const maxAttempts = 5;
  static const lockDuration = Duration(seconds: 30);

  static const _kRegistered = 'registered';
  static const _kName = 'user_name';
  static const _kPhone = 'user_phone';
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kBiometric = 'biometric_enabled';
  static const _kFails = 'pin_fails';
  static const _kLockUntil = 'pin_lock_until';

  final LocalAuthentication _localAuth = LocalAuthentication();

  L10n get _l => L10n.instance;

  // ---------------------------------------------------------------- user

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

  /// Removes the user, passcode and biometric choice.
  /// Device settings such as the language are kept.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kName,
      _kPhone,
      _kRegistered,
      _kPinHash,
      _kPinSalt,
      _kBiometric,
      _kFails,
      _kLockUntil,
    ]) {
      await prefs.remove(k);
    }
  }

  // ------------------------------------------------------------ passcode

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPinHash) != null;
  }

  /// Stores only a salted, stretched SHA-256 hash, never the passcode.
  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinSalt, salt);
    await prefs.setString(_kPinHash, _hash(pin, salt));
    await prefs.remove(_kFails);
    await prefs.remove(_kLockUntil);
  }

  Future<PinCheck> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final lockUntil = prefs.getInt(_kLockUntil) ?? 0;
    if (lockUntil > now) {
      return PinCheck.locked(Duration(milliseconds: lockUntil - now));
    }

    final salt = prefs.getString(_kPinSalt);
    final hash = prefs.getString(_kPinHash);
    if (salt != null && hash != null && _hash(pin, salt) == hash) {
      await prefs.remove(_kFails);
      await prefs.remove(_kLockUntil);
      return const PinCheck.ok();
    }

    final fails = (prefs.getInt(_kFails) ?? 0) + 1;
    if (fails >= maxAttempts) {
      await prefs.setInt(_kFails, 0);
      await prefs.setInt(_kLockUntil, now + lockDuration.inMilliseconds);
      return const PinCheck.locked(lockDuration);
    }
    await prefs.setInt(_kFails, fails);
    return PinCheck.wrong(maxAttempts - fails);
  }

  /// 111111, 123456, 654321... are not allowed.
  static bool isWeakPin(String pin) {
    if (pin.split('').toSet().length == 1) return true;
    final d = pin.codeUnits;
    final asc = List.generate(d.length - 1, (i) => d[i + 1] - d[i] == 1)
        .every((x) => x);
    final desc = List.generate(d.length - 1, (i) => d[i] - d[i + 1] == 1)
        .every((x) => x);
    return asc || desc;
  }

  String _hash(String pin, String salt) {
    final saltBytes = utf8.encode(salt);
    var digest = sha256.convert(utf8.encode('$salt:$pin'));
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert([...digest.bytes, ...saltBytes]);
    }
    return digest.toString();
  }

  // ---------------------------------------------------------- biometrics

  Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometric) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometric, value);
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

  /// Biometrics only - the app's own passcode is the fallback.
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
