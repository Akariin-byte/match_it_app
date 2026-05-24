import 'dart:convert';

import 'package:http/http.dart' as http;

/// 后端 API 根地址（Web 本地联调默认 8080）
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class AuthSession {
  AuthSession({
    required this.token,
    required this.userId,
    required this.openid,
    required this.isGuest,
    this.phone,
  });

  String token;
  final String userId;
  final String openid;
  bool isGuest;
  String? phone;

  factory AuthSession.fromGuestJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      userId: user['id'] as String,
      openid: user['openid'] as String,
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

  void applyBindResponse(Map<String, dynamic> json) {
    token = json['token'] as String;
    final user = json['user'] as Map<String, dynamic>;
    isGuest = user['isGuest'] as bool? ?? false;
    phone = user['phone'] as String?;
  }
}

class AuthService {
  const AuthService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  Future<AuthSession> guestLogin() async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/guest');
    final resp = await http.post(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException(_errorMessage(resp));
    }
    return AuthSession.fromGuestJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<AuthSession> bindPhone({
    required AuthSession session,
    required String phone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/bind-phone');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode({'phone': phone}),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw AuthException(_errorMessage(resp));
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    session.applyBindResponse(body);
    return session;
  }

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

const authService = AuthService();
