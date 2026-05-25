import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';

/// 使用 flutter_secure_storage 持久化 JWT 与用户身份
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _openidKey = 'openid';
  static const _isGuestKey = 'is_guest';
  static const _phoneKey = 'phone';

  static const _usernameKey = 'username';

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _openidKey, value: session.openid);
    await _storage.write(key: _isGuestKey, value: session.isGuest.toString());
    await _storage.write(key: _usernameKey, value: session.username);
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
    if (session.phone != null) {
      await _storage.write(key: _phoneKey, value: session.phone);
    } else {
      await _storage.delete(key: _phoneKey);
    }
  }

  Future<AuthSession?> loadSession() async {
    final token = await _storage.read(key: _tokenKey);
    final userId = await _storage.read(key: _userIdKey);
    if (token == null || userId == null) return null;

    return AuthSession(
      token: token,
      refreshToken: await _storage.read(key: _refreshTokenKey),
      userId: userId,
      openid: await _storage.read(key: _openidKey) ?? '',
      isGuest: (await _storage.read(key: _isGuestKey)) != 'false',
      username: await _storage.read(key: _usernameKey) ?? '游客',
      phone: await _storage.read(key: _phoneKey),
    );
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

final tokenStorage = TokenStorage();
