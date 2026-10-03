import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

/// Create a passcode: enter it, then repeat it.
class PinSetupScreen extends StatefulWidget {
  final Future<void> Function(String pin) onDone;
  final bool canGoBack;

  const PinSetupScreen({
    super.key,
    required this.onDone,
    this.canGoBack = true,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;

  Future<String?> _onPin(String pin) async {
    final l = L10n.instance;
    if (_first == null) {
      if (AuthService.isWeakPin(pin)) return l.t('pin.too_simple');
      setState(() => _first = pin);
      return null;
    }
    if (pin != _first) {
      setState(() => _first = null);
      return l.t('pin.mismatch');
    }
    await widget.onDone(pin);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final repeat = _first != null;
    return PopScope(
      canPop: widget.canGoBack,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.canGoBack,
          leading: repeat
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _first = null),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                context.tr(repeat ? 'pin.repeat_title' : 'pin.create_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  context.tr('pin.create_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ),
              const Spacer(),
              PinPad(onCompleted: _onPin),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
