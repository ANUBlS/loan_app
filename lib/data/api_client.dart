import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../i18n/l10n.dart';

/// Error from the Loan API, or a network problem (status 0).
///
/// The API always answers errors as
/// {"error": {"code": "otp_invalid", "message": "...", "details": {...}}}.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  const ApiException(
    this.status,
    this.code,
    this.message, [
    this.details = const {},
  ]);

  bool get isNetwork => status == 0;
  bool get isSessionExpired => code == 'session_expired';

  /// Text for the user: "error.<code>" from translations.json when it exists,
  /// otherwise the server's English message.
  String get userMessage {
    final l = L10n.instance;
    final key = 'error.$code';
    final text = l.t(key, details);
    if (text != key) return text;
    if (message.isNotEmpty && status != 0) return message;
    return l.t('common.error_generic');
  }

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

class _Response {
  final int status;
  final Uint8List bytes;
  const _Response(this.status, this.bytes);

  bool get ok => status >= 200 && status < 300;
  String get text => utf8.decode(bytes, allowMalformed: true);
}

/// HTTP client for the Loan API (dart:io, no extra packages).
///
/// Keeps the short-lived access token in memory and the refresh token in
/// shared_preferences. When the access token expires it is renewed once
/// with POST /api/v1/auth/refresh and the request is repeated.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _kBaseUrl = 'api_base_url';
  static const _kRefresh = 'api_refresh_token';
  static const _timeout = Duration(seconds: 20);

  static String get deviceName => 'Loan App (${Platform.operatingSystem})';

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  final Random _random = Random.secure();

  String _baseUrl = kDefaultApiBaseUrl;
  String? _accessToken;
  DateTime? _accessValidUntil;
  Future<bool>? _refreshing;

  String get baseUrl => _baseUrl;

  /// Reads the saved server address. Call once before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kBaseUrl) ?? kDefaultApiBaseUrl;
  }

  static String normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    return u;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = normalizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, _baseUrl);
  }

  /// GET /health on [url] (or the saved server). Returns the API version.
  Future<String> ping([String? url]) async {
    final base = normalizeUrl(url ?? _baseUrl);
    final res = await _raw('GET', '/health', base: base);
    if (!res.ok) throw _error(res);
    final body = jsonDecode(res.text);
    return body is Map ? '${body['version'] ?? ''}' : '';
  }

  /// Random key for the Idempotency-Key header.
  String newKey() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }

  // ------------------------------------------------------------- session

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh) != null;
  }

  /// Stores the tokens from /auth/otp/verify or /auth/refresh.
  Future<void> saveSession(Map<String, dynamic> tokens) async {
    _accessToken = tokens['accessToken'] as String;
    final expiresIn = (tokens['expiresIn'] as num?)?.toInt() ?? 900;
    _accessValidUntil =
        DateTime.now().add(Duration(seconds: max(expiresIn - 30, 30)));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRefresh, tokens['refreshToken'] as String);
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _accessValidUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRefresh);
  }

  /// Signs this device out on the server (best effort), then forgets tokens.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_kRefresh);
    if (refresh != null) {
      try {
        await _raw('POST', '/api/v1/auth/logout',
            body: {'refreshToken': refresh});
      } catch (_) {
        // Offline: the token simply expires on the server.
      }
    }
    await clearSession();
  }

  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_kRefresh);
    if (refresh == null) return false;
    final res = await _raw('POST', '/api/v1/auth/refresh', body: {
      'refreshToken': refresh,
      'deviceName': deviceName,
    });
    if (res.ok) {
      await saveSession(jsonDecode(res.text) as Map<String, dynamic>);
      return true;
    }
    if (res.status == 401) {
      // Revoked or expired: the user has to sign in again.
      await clearSession();
      return false;
    }
    throw _error(res);
  }

  Future<void> _ensureAccessToken() async {
    final validUntil = _accessValidUntil;
    if (_accessToken != null &&
        validUntil != null &&
        DateTime.now().isBefore(validUntil)) {
      return;
    }
    if (!await _refresh()) throw _sessionExpired();
  }

  ApiException _sessionExpired() =>
      const ApiException(401, 'session_expired', 'Sign in again');

  // ------------------------------------------------------------ requests

  /// Request without a token (sign-in endpoints).
  Future<dynamic> postPublic(
    String path,
    Object? body, {
    Map<String, String>? query,
  }) async {
    return _decode(await _raw('POST', path, body: body, query: query));
  }

  Future<dynamic> getPublic(String path) async {
    return _decode(await _raw('GET', path));
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _decode(await _authed('GET', path, query: query));
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    return _decode(await _authed('POST', path, body: body, headers: headers));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _decode(await _authed('PATCH', path, body: body));
  }

  /// Binary download (PDF documents).
  Future<Uint8List> download(String path) async {
    final res = await _authed('GET', path);
    if (!res.ok) throw _error(res);
    return res.bytes;
  }

  Future<_Response> _authed(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    await _ensureAccessToken();
    var res = await _raw(method, path,
        body: body, query: query, headers: headers, token: _accessToken);
    if (res.status == 401) {
      // Token expired early or was revoked: renew once and repeat.
      _accessToken = null;
      _accessValidUntil = null;
      if (!await _refresh()) throw _sessionExpired();
      res = await _raw(method, path,
          body: body, query: query, headers: headers, token: _accessToken);
    }
    return res;
  }

  Future<_Response> _raw(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    String? token,
    String? base,
  }) async {
    final parsed = Uri.tryParse('${base ?? _baseUrl}$path');
    if (parsed == null ||
        !(parsed.scheme == 'http' || parsed.scheme == 'https') ||
        parsed.host.isEmpty) {
      throw const ApiException(0, 'bad_url', 'Invalid server address');
    }
    final uri = (query == null || query.isEmpty)
        ? parsed
        : parsed.replace(queryParameters: query);

    try {
      final req = await _http.openUrl(method, uri).timeout(_timeout);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.acceptLanguageHeader, L10n.instance.code);
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      headers?.forEach((k, v) => req.headers.set(k, v));
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        req.headers.contentType = ContentType.json;
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final resp = await req.close().timeout(_timeout);
      final data = await resp
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
          .timeout(_timeout);
      return _Response(resp.statusCode, Uint8List.fromList(data));
    } on TimeoutException {
      throw const ApiException(0, 'timeout', 'Server did not answer');
    } on SocketException catch (e) {
      throw ApiException(0, 'no_connection', e.message);
    } on HandshakeException catch (e) {
      throw ApiException(0, 'no_connection', e.message);
    } on HttpException catch (e) {
      throw ApiException(0, 'no_connection', e.message);
    }
  }

  dynamic _decode(_Response res) {
    if (!res.ok) throw _error(res);
    final text = res.text;
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ApiException(res.status, 'bad_response', 'Not JSON');
    }
  }

  ApiException _error(_Response res) {
    final text = res.text;
    try {
      final body = jsonDecode(text);
      if (body is Map && body['error'] is Map) {
        final e = body['error'] as Map;
        final details = e['details'];
        return ApiException(
          res.status,
          '${e['code'] ?? 'error'}',
          '${e['message'] ?? ''}',
          details is Map
              ? Map<String, dynamic>.from(details)
              : const <String, dynamic>{},
        );
      }
    } on FormatException {
      // Not our JSON (proxy page etc.)
    }
    return ApiException(
      res.status,
      'http_${res.status}',
      text.length > 200 ? text.substring(0, 200) : text,
    );
  }
}
