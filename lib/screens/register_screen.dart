import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/profile_menu.dart';
import '../widgets/server_dialog.dart';
import 'otp_screen.dart';

/// Name + phone -> SMS code -> create passcode -> (optional) biometrics.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+994 ');
  final _auth = AuthService();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() => _sending = true);
    try {
      final request = await _auth.requestCode(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(name: name, request: request),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          action: e.isNetwork
              ? SnackBarAction(
                  label: L10n.instance.t('server.title'),
                  onPressed: () => showServerDialog(context),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: context.tr('server.title'),
                      onPressed: () => showServerDialog(context),
                      icon: const Icon(Icons.dns_outlined),
                    ),
                    TextButton.icon(
                      onPressed: () => showLanguagePicker(context),
                      icon: const Icon(Icons.language),
                      label: Text(context.l10n.currentLanguageName),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  context.tr('register.title'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('register.subtitle'),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('register.name'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? L10n.instance.t('register.name_error')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('register.phone'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 12
                        ? L10n.instance.t('register.phone_error')
                        : null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _sending ? null : _continue,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(context.tr(
                      _sending ? 'register.sending' : 'register.continue')),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr('register.privacy'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
