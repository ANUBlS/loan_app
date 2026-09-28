import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

/// Shown on every app start, and again when the app returns
/// from background after 30 s ([isRelock] = true).
class LockScreen extends StatefulWidget {
  final bool isRelock;
  const LockScreen({super.key, this.isRelock = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = AuthService();
  String _name = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _auth.userName().then((n) {
      if (mounted) setState(() => _name = n);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result =
        await _auth.authenticate(L10n.instance.t('auth.reason_unlock'));
    if (!mounted) return;

    if (result.success) {
      if (widget.isRelock) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
      return;
    }

    setState(() {
      _busy = false;
      _error = result.message;
    });
  }

  Future<void> _resetAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('lock.reset_title')),
        content: Text(ctx.tr('lock.reset_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('lock.reset_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _auth.reset();
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
    final hasError = _error != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  greeting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('lock.hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 48),
                Material(
                  color: hasError ? AppColors.overdue : AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy ? null : _unlock,
                    child: const SizedBox(
                      width: 112,
                      height: 112,
                      child: Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (hasError)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.overdue),
                  )
                else
                  Text(
                    context.tr(_busy ? 'lock.checking' : 'lock.retry'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                const Spacer(),
                if (!widget.isRelock)
                  TextButton(
                    onPressed: _busy ? null : _resetAccount,
                    child: Text(context.tr('lock.not_you')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
