import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';

/// Shown once after the passcode is created, only on phones with biometrics.
class BiometricOfferScreen extends StatefulWidget {
  const BiometricOfferScreen({super.key});

  @override
  State<BiometricOfferScreen> createState() => _BiometricOfferScreenState();
}

class _BiometricOfferScreenState extends State<BiometricOfferScreen> {
  final _auth = AuthService();
  bool _busy = false;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final r = await _auth.authenticate(L10n.instance.t('auth.reason_register'));
    if (!mounted) return;
    if (!r.success) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message ?? L10n.instance.t('common.error_generic'))),
      );
      return;
    }
    await _auth.setBiometricEnabled(true);
    if (mounted) _goHome();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 68,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.tr('bio.offer_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('bio.offer_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _enable,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(context.tr('bio.enable')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _goHome,
                  child: Text(context.tr('bio.not_now')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
