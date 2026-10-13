import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'models.dart';

enum SessionState { starting, loggedOut, loggedIn }

/// Who is logged in, plus the form data loaded from the website. The login
/// token lives only in the device's secure storage (Keystore / Keychain).
class AppSession extends ChangeNotifier {
  AppSession() {
    api.onUnauthorized = _dropLogin;
  }

  static const String _tokenKey = 'staff_token';

  final ApiClient api = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SessionState state = SessionState.starting;
  AppConfig? config;

  /// Set when the saved login could not be checked because the website was unreachable.
  String? startupError;

  /// Called once at launch: reuse a saved login if it is still valid.
  Future<void> start() async {
    startupError = null;
    state = SessionState.starting;
    notifyListeners();

    String? saved;
    try {
      saved = await _storage.read(key: _tokenKey);
    } catch (_) {
      saved = null; // unreadable storage (e.g. restored backup) — ask to log in again
    }
    if (saved == null || saved.isEmpty) {
      state = SessionState.loggedOut;
      notifyListeners();
      return;
    }

    api.token = saved;
    try {
      await refreshConfig();
      state = SessionState.loggedIn;
    } on ApiException catch (e) {
      if (e.unauthorized) {
        state = SessionState.loggedOut;
      } else {
        startupError = e.message; // keep the login, let the user retry
      }
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final res = await api.post('login', {'username': username, 'password': password, 'device_name': _deviceName});
    final token = res['token'];
    if (token is! String || token.isEmpty) throw ApiException('Login failed. Please try again.');

    api.token = token;
    await refreshConfig();
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // still logged in for this run; they will be asked again next launch
    }
    state = SessionState.loggedIn;
    notifyListeners();
  }

  /// Reload batches, prices and holidays from the website.
  Future<void> refreshConfig() async {
    config = AppConfig.fromJson(await api.get('config'));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('logout');
    } on ApiException {
      // offline — the token is still removed from this device below
    }
    await _clear();
  }

  void _dropLogin() {
    if (state == SessionState.loggedOut) return;
    _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    config = null;
    startupError = null;
    state = SessionState.loggedOut;
    notifyListeners();
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // nothing else to do
    }
  }

  String get _deviceName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iPhone app';
      case TargetPlatform.android:
        return 'Android app';
      default:
        return 'Mobile app';
    }
  }
}

/// The one session shared by every screen.
final AppSession session = AppSession();
