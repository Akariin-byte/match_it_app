import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_id.dart';

/// 后端 API 根地址（Web 本地联调默认 8080）
/// 可通过：flutter run --dart-define=API_BASE_URL=http://...
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// 登录会话：保存 JWT 与用户身份，在页面间传递
class AuthSession {
  AuthSession({
    required this.token,
    required this.userId,
    required this.openid,
    required this.isGuest,
    this.username = '游客',
    this.phone,
    this.refreshToken,
  });

  String token;
  String userId;
  final String openid;
  bool isGuest;
  String username;
  String? phone;
  String? refreshToken;

  /// 首页/Feed 展示名：正式用户以服务端昵称为准
  String get displayName {
    if (username.trim().isNotEmpty && username != '游客') {
      return username.trim();
    }
    final p = phone?.trim();
    if (!isGuest && p != null && p.length >= 4) {
      return '用户${p.substring(p.length - 4)}';
    }
    return '游客';
  }

  factory AuthSession.fromAuthJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String?,
      userId: user['id'].toString(),
      openid: user['openid'] as String? ?? '',
      isGuest: user['isGuest'] as bool? ?? true,
      username: user['username'] as String? ?? '游客',
      phone: user['phone'] as String?,
    );
  }

  factory AuthSession.fromGuestJson(Map<String, dynamic> json) =>
      AuthSession.fromAuthJson(json);

  void applyAuthResponse(Map<String, dynamic> json) {
    token = json['token'] as String;
    refreshToken = json['refreshToken'] as String?;
    final user = json['user'] as Map<String, dynamic>;
    userId = user['id'].toString();
    isGuest = user['isGuest'] as bool? ?? false;
    username = user['username'] as String? ?? username;
    phone = user['phone'] as String?;
  }
}

class PhoneStatus {
  const PhoneStatus({required this.registered, this.username});

  final bool registered;
  final String? username;

  factory PhoneStatus.fromJson(Map<String, dynamic> json) {
    return PhoneStatus(
      registered: json['registered'] as bool? ?? false,
      username: json['username'] as String?,
    );
  }
}

/// 鉴权 API 客户端
class AuthService {
  const AuthService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  Future<AuthSession> guestLogin({String? username}) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/guest-login');
    final body = <String, dynamic>{'device_id': DeviceId.get()};
    final name = username?.trim();
    if (name != null && name.isNotEmpty) {
      body['username'] = name;
    }
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    return AuthSession.fromAuthJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<PhoneStatus> checkPhoneStatus(String phone) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/phone-status');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone.trim()}),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    return PhoneStatus.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  /// 游客绑定手机（需游客 Token）
  Future<AuthSession> bindPhone({
    required AuthSession session,
    required String phone,
    required String verificationCode,
    String? username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/bind-phone');
    final payload = <String, dynamic>{
      'phone': phone,
      'verification_code': verificationCode,
    };
    final name = username?.trim();
    if (name != null && name.isNotEmpty) {
      payload['username'] = name;
    }
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    session.applyAuthResponse(data);
    return session;
  }

  /// 欢迎页新手机号注册；若已注册则自动改走 login
  Future<AuthSession> registerWithPhone({
    required String phone,
    required String verificationCode,
    String? username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register');
    final payload = <String, dynamic>{
      'phone': phone,
      'verification_code': verificationCode,
      'device_id': DeviceId.get(),
    };
    final name = username?.trim();
    if (name != null && name.isNotEmpty) {
      payload['username'] = name;
    }
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return AuthSession.fromAuthJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    final err = AuthException.fromResponse(resp);
    if (err.action == 'login' ||
        err.message.contains('已注册') ||
        err.message.contains('registered')) {
      return loginWithPhone(
        phone: phone,
        verificationCode: verificationCode,
      );
    }
    throw err;
  }

  /// 游客升级绑定；已注册手机号会自动走 login
  Future<AuthSession> loginOrBindPhone({
    AuthSession? session,
    required String phone,
    required String verificationCode,
    String? username,
  }) async {
    session ??= await guestLogin();
    try {
      await bindPhone(
        session: session,
        phone: phone,
        verificationCode: verificationCode,
        username: username,
      );
      return session;
    } on AuthException catch (e) {
      if (e.action == 'login' ||
          e.message.contains('registered') ||
          e.message.contains('already')) {
        return loginWithPhone(
          phone: phone,
          verificationCode: verificationCode,
        );
      }
      rethrow;
    }
  }

  Future<AuthSession> loginWithPhone({
    required String phone,
    required String verificationCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone,
            'verification_code': verificationCode,
            'device_id': DeviceId.get(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    return AuthSession.fromAuthJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<void> sendCode({
    required String phone,
    required String scene,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/send-code');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'scene': scene}),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  Future<void> logout(AuthSession session) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/logout');
    final payload = <String, dynamic>{};
    final refresh = session.refreshToken?.trim();
    if (refresh != null && refresh.isNotEmpty) {
      payload['refresh_token'] = refresh;
    }
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  Future<Map<String, dynamic>> me(AuthSession session) async {
    final uri = Uri.parse('$baseUrl/api/v1/me');
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

class AuthException implements Exception {
  AuthException(this.message, {this.action});

  final String message;
  final String? action;

  factory AuthException.fromResponse(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final error = body['error']?.toString();
      final msg = body['message']?.toString();
      return AuthException(
        msg ?? error ?? 'HTTP ${resp.statusCode}',
        action: body['action']?.toString(),
      );
    } catch (_) {
      return AuthException('HTTP ${resp.statusCode}');
    }
  }

  @override
  String toString() => message;
}

const authService = AuthService();
