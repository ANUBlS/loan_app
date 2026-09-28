import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads all texts from assets/i18n/translations.json.
/// The chosen language is saved on the device and restored on next launch.
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n instance = L10n._();

  static const _asset = 'assets/i18n/translations.json';
  static const _prefKey = 'language';

  String _defaultCode = 'en';
  String _code = 'en';
  Map<String, String> _languages = const {'en': 'English'};
  Map<String, dynamic> _strings = const {};

  /// Current language code, e.g. "az".
  String get code => _code;

  /// code -> display name, in the order written in the JSON file.
  Map<String, String> get languages => _languages;

  Locale get locale => Locale(_code);

  String get currentLanguageName => _languages[_code] ?? _code;

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(_asset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _languages = (json['languages'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      _defaultCode = (json['default'] as String?) ?? _languages.keys.first;
      _strings = (json['strings'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('L10n: could not load $_asset: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final device = ui.PlatformDispatcher.instance.locale.languageCode;

    // Saved choice first, then phone language, then the file's default.
    _code = saved != null && _languages.containsKey(saved)
        ? saved
        : _languages.containsKey(device)
            ? device
            : _defaultCode;
  }

  Future<void> setLanguage(String code) async {
    if (!_languages.containsKey(code) || code == _code) return;
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  /// Simple text. Placeholders like {name} are replaced from [params].
  String t(String key, [Map<String, Object?> params = const {}]) {
    final value = _lookup(key);
    if (value is String) return _fill(value, params);
    if (value is Map) {
      return _fill((value['other'] ?? value.values.first).toString(), params);
    }
    return key; // missing key: show the key so it is easy to spot
  }

  /// Text with a count. {n} is replaced with [n].
  /// Supports one / few / many / other forms per language.
  String plural(String key, num n, [Map<String, Object?> params = const {}]) {
    final all = <String, Object?>{'n': n, ...params};
    final value = _lookup(key);
    if (value is String) return _fill(value, all);
    if (value is Map) {
      final form = _pluralForm(n.toInt().abs());
      final text = value[form] ?? value['other'] ?? value.values.first;
      return _fill(text.toString(), all);
    }
    return key;
  }

  bool _has(dynamic v) =>
      v != null && !(v is String && v.trim().isEmpty) && !(v is Map && v.isEmpty);

  dynamic _lookup(String key) {
    final entry = _strings[key];
    if (entry is! Map) return null;
    for (final c in [_code, _defaultCode, 'en']) {
      final v = entry[c];
      if (_has(v)) return v;
    }
    return null;
  }

  String _pluralForm(int i) {
    switch (_code) {
      case 'ru':
      case 'uk':
      case 'be':
        if (i % 10 == 1 && i % 100 != 11) return 'one';
        if (i % 10 >= 2 && i % 10 <= 4 && (i % 100 < 12 || i % 100 > 14)) {
          return 'few';
        }
        return 'many';
      default:
        return i == 1 ? 'one' : 'other';
    }
  }

  String _fill(String text, Map<String, Object?> params) {
    var out = text;
    params.forEach((k, v) => out = out.replaceAll('{$k}', '${v ?? ''}'));
    return out;
  }
}

/// Rebuilds every widget that uses context.tr(...) when the language changes.
class L10nScope extends InheritedNotifier<L10n> {
  L10nScope({super.key, required super.child})
      : super(notifier: L10n.instance);
}

extension L10nContext on BuildContext {
  L10n get l10n {
    dependOnInheritedWidgetOfExactType<L10nScope>();
    return L10n.instance;
  }

  String tr(String key, [Map<String, Object?> params = const {}]) =>
      l10n.t(key, params);

  String trn(String key, num n, [Map<String, Object?> params = const {}]) =>
      l10n.plural(key, n, params);
}
