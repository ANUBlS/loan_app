import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/pin_pad.dart';
import '../widgets/profile_menu.dart';
import 'pin_setup_screen.dart';

/// Profile and settings: language, biometrics, passcode, sign out.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _auth = AuthService();
  String _name = '';
  String _phone = '';
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _auth.userName();
    final phone = await _auth.userPhone();
    final bio = await _auth.biometricEnabled();
    if (!mounted) return;
    setState(() {
      _name = name;
      _phone = phone;
      _biometric = bio;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleBiometric(bool on) async {
    final l = L10n.instance;
    if (on) {
      final available = await _auth.checkAvailability();
      if (!available.success) {
        _snack(available.message ?? l.t('auth.err_not_available'));
        return;
      }
      final r = await _auth.authenticate(l.t('auth.reason_register'));
      if (!r.success) {
        _snack(r.message ?? l.t('common.error_generic'));
        return;
      }
    }
    await _auth.setBiometricEnabled(on);
    if (mounted) setState(() => _biometric = on);
  }

  Future<void> _changePin() async {
    final ok = await showPinSheet(context, titleKey: 'pin.current_title');
    if (!ok || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          onDone: (pin) async {
            await _auth.setPin(pin);
            if (!mounted) return;
            Navigator.of(context).pop();
            _snack(L10n.instance.t('pin.changed'));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('more.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initialsOf(_name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.isEmpty ? '—' : _name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (_phone.isNotEmpty)
                        Text(
                          _phone,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WhiteCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: AppColors.primary),
                  title: Text(context.tr('profile.language')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.currentLanguageName,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  onTap: () => showLanguagePicker(context),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary:
                      const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: Text(context.tr('more.biometric')),
                  value: _biometric,
                  onChanged: _toggleBiometric,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.pin_outlined,
                      color: AppColors.primary),
                  title: Text(context.tr('more.change_pin')),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _changePin,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text(context.tr('more.version')),
                  trailing: const Text(
                    '1.3.0',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WhiteCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.overdue),
              title: Text(
                context.tr('profile.sign_out'),
                style: const TextStyle(color: AppColors.overdue),
              ),
              onTap: () => confirmSignOut(context),
            ),
          ),
        ],
      ),
    );
  }
}
