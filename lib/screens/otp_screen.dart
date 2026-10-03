import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../i18n/l10n.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'biometric_offer_screen.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

/// SMS code check -> create passcode -> (optional) enable biometrics.
class OtpScreen extends StatefulWidget {
  final String name;
  final OtpRequest request;

  const OtpScreen({super.key, required this.name, required this.request});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _auth = AuthService();
  final _codeCtrl = TextEditingController();
  late OtpRequest _request = widget.request;
  Timer? _timer;
  int _resendIn = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer(_request.resendIn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Counts down the "send again" button. Callers rebuild afterwards.
  void _startTimer(int seconds) {
    _timer?.cancel();
    _resendIn = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _auth.requestCode(_request.phone);
      if (!mounted) return;
      _request = r;
      _codeCtrl.clear();
      _startTimer(r.resendIn);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.instance.t('otp.sent'))),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 4 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (name, phone) = await _auth.verifyCode(
        phone: _request.phone,
        code: code,
        fullName: widget.name,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _createPin(name, phone);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    }
  }

  /// The server session exists now; the passcode protects it on this phone.
  void _createPin(String name, String phone) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          canGoBack: false,
          onDone: (pin) async {
            await _auth.setPin(pin);
            await _auth.register(name: name, phone: phone);
            final hasBiometrics = (await _auth.checkAvailability()).success;
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => hasBiometrics
                    ? const BiometricOfferScreen()
                    : const HomeScreen(),
              ),
              (_) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debugCode = _request.debugCode;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              context.tr('otp.title'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('otp.subtitle', {'phone': _request.phone}),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 10,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: context.tr('otp.code'),
                counterText: '',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == 6) _verify();
              },
            ),
            if (debugCode != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('otp.test_code', {'code': debugCode}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.tr('otp.verify')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || _resendIn > 0 ? null : _resend,
              child: Text(
                _resendIn > 0
                    ? context.tr('otp.resend_in', {'n': _resendIn})
                    : context.tr('otp.resend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
