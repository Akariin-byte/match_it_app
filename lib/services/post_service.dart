import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PostService {
  const PostService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  /// 发布搭子帖（需正式用户 JWT）
  Future<Map<String, dynamic>> createPost({
    required AuthSession session,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/posts');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.token}',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw AuthException.fromResponse(resp);
  }
}

const postService = PostService();
