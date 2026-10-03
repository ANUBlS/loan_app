import 'package:flutter/material.dart';

import '../widgets/pin_pad.dart';
import 'auth_service.dart';

/// Confirms a payment or application:
/// biometrics if the user turned them on, otherwise (or if cancelled) passcode.
Future<bool> confirmIdentity(BuildContext context, String reason) async {
  final auth = AuthService();
  if (await auth.biometricEnabled()) {
    final r = await auth.authenticate(reason);
    if (r.success) return true;
  }
  if (!context.mounted) return false;
  return showPinSheet(context);
}
