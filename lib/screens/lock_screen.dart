import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Passcode keypad. Fingerprint / Face ID starts automatically if enabled.
/// Shown on every app start, and again after 30 s in background ([isRelock]).
class LockScreen extends StatefulWidget {
  final bool isRelock;
  const LockScreen({super.key, this.isRelock = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = AuthService();
  String _name = '';
  bool _biometric = false;
  bool _bioRunning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _auth.userName();
    final bio = await _auth.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _name = name;
      _biometric = bio;
    });
    if (bio) _useBiometric();
  }

  Future<void> _useBiometric() async {
    if (_bioRunning) return;
    _bioRunning = true;
    final r = await _auth.authenticate(L10n.instance.t('auth.reason_unlock'));
    _bioRunning = false;
    if (!mounted) return;
    if (r.success) _unlocked();
    // On cancel / failure the user simply enters the passcode.
  }

  Future<String?> _onPin(String pin) async {
    final r = await _auth.verifyPin(pin);
    if (r.ok) {
      _unlocked();
      return null;
    }
    return pinErrorText(r);
  }

  void _unlocked() {
    if (!mounted) return;
    if (widget.isRelock) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _forgot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('pin.forgot_title')),
        content: Text(ctx.tr('pin.forgot_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('pin.forgot_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _name.trim().split(' ').first;
    final greeting = firstName.isEmpty
        ? context.tr('lock.greeting')
        : context.tr('lock.greeting_name', {'name': firstName});

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('lock.hint'),
                style: const TextStyle(color: AppColors.muted),
              ),
              const Spacer(),
              PinPad(
                onCompleted: _onPin,
                onBiometric: _biometric ? _useBiometric : null,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _forgot,
                child: Text(context.tr('pin.forgot')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
