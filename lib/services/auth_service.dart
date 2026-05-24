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
    this.phone,
  });

  /// Bearer Token，请求需鉴权接口时放入 Authorization 头
  String token;
  final String userId;
  final String openid;
  /// true=游客，false=已绑定手机
  bool isGuest;
  String? phone;

  factory AuthSession.fromGuestJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      userId: user['id'].toString(),
      openid: user['openid'] as String? ?? '',
      isGuest: user['isGuest'] as bool? ?? true,
      phone: user['phone'] as String?,
    );
  }

  factory AuthSession.fromBindJson(Map<String, dynamic> json) {
    final session = AuthSession.fromGuestJson(json);
    session.isGuest = false;
    session.phone = session.phone;
    return session;
  }

  /// 绑定手机成功后更新本地 Token 与状态
  void applyBindResponse(Map<String, dynamic> json) {
    token = json['token'] as String;
    final user = json['user'] as Map<String, dynamic>;
    isGuest = user['isGuest'] as bool? ?? false;
    phone = user['phone'] as String?;
  }
}

/// 鉴权 API 客户端（guest-login / bind-phone / me）
class AuthService {
  const AuthService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  /// 游客登录：同一 device_id 对应同一后端用户
  Future<AuthSession> guestLogin({String? username}) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/guest-login');
    final body = <String, dynamic>{
      'device_id': DeviceId.get(),
    };
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
      throw AuthException(_errorMessage(resp));
    }
    return AuthSession.fromGuestJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  /// 绑定手机号：需游客 Token，成功后 isGuest=false
  Future<AuthSession> bindPhone({
    required AuthSession session,
    required String phone,
    String? username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/bind-phone');
    final payload = <String, dynamic>{'phone': phone};
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
      throw AuthException(_errorMessage(resp));
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    session.applyBindResponse(data);
    return session;
  }

  /// 获取当前 Token 对应身份（需登录）
  Future<Map<String, dynamic>> me(AuthSession session) async {
    final uri = Uri.parse('$baseUrl/api/v1/me');
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException(_errorMessage(resp));
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['error']?.toString() ?? 'HTTP ${resp.statusCode}';
    } catch (_) {
      return 'HTTP ${resp.statusCode}';
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 全局单例，登录页直接调用
const authService = AuthService();
