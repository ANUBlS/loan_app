import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/profile_menu.dart';

/// Profile and settings: language, biometrics, sign out.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = AuthService();
    final name = await auth.userName();
    final phone = await auth.userPhone();
    if (!mounted) return;
    setState(() {
      _name = name;
      _phone = phone;
    });
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
                ListTile(
                  leading:
                      const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: Text(context.tr('more.biometric')),
                  trailing: Text(
                    context.tr('more.biometric_on'),
                    style: const TextStyle(
                      color: AppColors.paid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text(context.tr('more.version')),
                  trailing: const Text(
                    '1.2.0',
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
