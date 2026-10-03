import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../screens/register_screen.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Round avatar with the user's initials. Put it in AppBar.leading.
/// Tap -> sheet with Language and Sign out.
class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({super.key});

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  final _auth = AuthService();
  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _auth.userName();
    final phone = await _auth.userPhone();
    if (!mounted) return;
    setState(() {
      _name = name;
      _phone = phone;
    });
  }

  String get _initials => initialsOf(_name);

  Future<void> _openSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(initials: _initials, radius: 32, fontSize: 22),
              const SizedBox(height: 10),
              Text(
                _name.isEmpty ? '—' : _name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (_phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(_phone, style: const TextStyle(color: AppColors.muted)),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.line),
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: Text(ctx.tr('profile.language')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctx.l10n.currentLanguageName,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
                onTap: () => Navigator.pop(ctx, 'language'),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.overdue),
                title: Text(
                  ctx.tr('profile.sign_out'),
                  style: const TextStyle(color: AppColors.overdue),
                ),
                onTap: () => Navigator.pop(ctx, 'sign_out'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'language') {
      await showLanguagePicker(context);
    } else if (action == 'sign_out') {
      await confirmSignOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openSheet,
        child: _Avatar(initials: _initials, radius: 18, fontSize: 14),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final double radius;
  final double fontSize;

  const _Avatar({
    required this.initials,
    required this.radius,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// "Teymur Aliyev" -> "TA"
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Bottom sheet with every language from translations.json.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final l10n = ctx.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                ctx.tr('profile.choose_language'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            for (final entry in l10n.languages.entries)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(entry.value),
                subtitle: Text(entry.key.toUpperCase()),
                trailing: entry.key == l10n.code
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  l10n.setLanguage(entry.key);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('profile.sign_out_title')),
      content: Text(ctx.tr('profile.sign_out_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('profile.sign_out')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await AuthService().signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RegisterScreen()),
    (_) => false,
  );
}
