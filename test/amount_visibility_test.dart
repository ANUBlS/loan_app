import 'package:flutter_test/flutter_test.dart';
import 'package:loan_app/services/amount_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hide amounts is off by default', () async {
    SharedPreferences.setMockInitialValues({});
    await AmountVisibility.instance.load();
    expect(AmountVisibility.instance.hidden, isFalse);
  });

  test('hide amounts is saved and restored on next start', () async {
    SharedPreferences.setMockInitialValues({});
    final v = AmountVisibility.instance;
    await v.load();
    await v.toggle();
    expect(v.hidden, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hide_amounts'), isTrue);

    // Simulate an app restart: values on disk, fresh load.
    SharedPreferences.setMockInitialValues({'hide_amounts': true});
    await v.load();
    expect(v.hidden, isTrue);

    await v.toggle();
    expect(v.hidden, isFalse);
    expect((await SharedPreferences.getInstance()).getBool('hide_amounts'), isFalse);
  });
}
