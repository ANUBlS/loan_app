import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Six dots + round number keys, like a banking app.
/// [onCompleted] returns an error text (pad shakes and clears) or null.
class PinPad extends StatefulWidget {
  final int length;
  final Future<String?> Function(String pin) onCompleted;
  final VoidCallback? onBiometric;

  const PinPad({
    super.key,
    this.length = AuthService.pinLength,
    required this.onCompleted,
    this.onBiometric,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  static const _keySize = 74.0;
  static const _keyColor = Color(0xFFE9ECF1);

  String _pin = '';
  String? _error;
  bool _checking = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tap(String digit) async {
    if (_checking || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length < widget.length) return;

    setState(() => _checking = true);
    final error = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (error != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    setState(() {
      _error = error;
      _pin = '';
      _checking = false;
    });
  }

  void _backspace() {
    if (_pin.isEmpty || _checking) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              sin(_shake.value * pi * 5) * 12 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length
                          ? AppColors.primary
                          : (_error != null
                              ? AppColors.overdue
                              : const Color(0xFF9CA3AF)),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _error ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.overdue,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final d in row) _digitKey(d)],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            widget.onBiometric != null
                ? _iconKey(Icons.fingerprint, widget.onBiometric!)
                : const SizedBox(width: _keySize, height: _keySize),
            _digitKey('0'),
            _iconKey(Icons.backspace_outlined, _backspace),
          ],
        ),
      ],
    );
  }

  Widget _digitKey(String d) {
    return SizedBox(
      width: _keySize,
      height: _keySize,
      child: Material(
        color: _keyColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _tap(d),
          child: Center(
            child: Text(
              d,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: _keySize,
      height: _keySize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 30, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Text for a failed passcode check.
String pinErrorText(PinCheck r) {
  final l = L10n.instance;
  if (r.lockedFor != null) {
    return l.plural('pin.locked', (r.lockedFor!.inMilliseconds / 1000).ceil());
  }
  return l.plural('pin.wrong', r.attemptsLeft);
}

/// Bottom sheet asking for the passcode. Returns true when it is correct.
Future<bool> showPinSheet(BuildContext context, {String? titleKey}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.tr(titleKey ?? 'pin.enter_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            PinPad(
              onCompleted: (pin) async {
                final r = await AuthService().verifyPin(pin);
                if (r.ok) {
                  if (ctx.mounted) Navigator.pop(ctx, true);
                  return null;
                }
                return pinErrorText(r);
              },
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
