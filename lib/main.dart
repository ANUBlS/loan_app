import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n/l10n.dart';
import 'screens/lock_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await L10n.instance.load();
  runApp(const LoanApp());
}

class LoanApp extends StatelessWidget {
  const LoanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.instance;
    return ListenableBuilder(
      listenable: l10n,
      builder: (context, _) {
        // Material widgets (dialogs, tooltips) follow the app language
        // when Flutter supports it, otherwise English.
        final materialLocale =
            GlobalMaterialLocalizations.delegate.isSupported(l10n.locale)
                ? l10n.locale
                : const Locale('en');

        return MaterialApp(
          onGenerateTitle: (_) => l10n.t('app.title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: materialLocale,
          supportedLocales: {materialLocale, const Locale('en')}.toList(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) =>
              L10nScope(child: child ?? const SizedBox.shrink()),
          home: const StartupGate(),
        );
      },
    );
  }
}

/// First launch -> Register. Afterwards -> biometric Lock screen.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<bool> _registered = AuthService().isRegistered();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _registered,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const LockScreen() : const RegisterScreen();
      },
    );
  }
}
