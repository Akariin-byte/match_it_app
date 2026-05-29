import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_post.dart';
import '../models/post_application.dart';
import '../models/post_member.dart';
import 'auth_service.dart';

class PostService {
  const PostService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;

  /// 我发布的组局（正式用户；游客请求返回 403）
  Future<List<MatchPost>> listMyPublishedPosts({
    required AuthSession session,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/me/posts');
    final resp = await http
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(MatchPost.fromApiJson)
        .toList();
  }

  /// Feed 列表（需 Token，游客/正式用户均可浏览）
  Future<List<MatchPost>> listPosts({
    required AuthSession session,
    String? area,
    String? tab,
  }) async {
    final query = <String, String>{};
    if (area != null && area.isNotEmpty) {
      query['area'] = area;
    }
    if (tab != null && tab.isNotEmpty) {
      query['tab'] = tab;
    }
    final uri = Uri.parse('$baseUrl/api/v1/posts').replace(queryParameters: query);
    final resp = await http
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(MatchPost.fromApiJson)
        .toList();
  }

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

  /// 单帖详情（公开，无需 Token）
  Future<MatchPost?> fetchPost(String postId) async {
    final uri = Uri.parse('$baseUrl/api/v1/posts/$postId');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return MatchPost.fromApiJson(data);
    }
    if (body.containsKey('id')) {
      return MatchPost.fromApiJson(body);
    }
    return null;
  }

  /// 已加入成员（主理人 + 已通过申请）
  Future<List<PostMember>> fetchPostMembers(String postId) async {
    final uri = Uri.parse('$baseUrl/api/v1/posts/$postId/members');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PostMember.fromJson)
        .toList();
  }

  /// 申请加入组局（需正式用户 Token）
  Future<bool> applyToPost({
    required AuthSession session,
    required String postId,
    required String wechatContact,
    String? message,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/posts/$postId/apply');
    final body = <String, dynamic>{
      'wechatContact': wechatContact.trim(),
    };
    final msg = message?.trim();
    if (msg != null && msg.isNotEmpty) {
      body['message'] = msg;
    }
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
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      return decoded['hasApplied'] as bool? ?? true;
    }
    throw AuthException.fromResponse(resp);
  }

  /// 主理人收到的组局申请（消息 · 申请 Tab）
  Future<ReceivedApplicationsResult> listReceivedApplications({
    required AuthSession session,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/me/received-applications');
    final resp = await http
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    final items = data is List
        ? data
            .whereType<Map<String, dynamic>>()
            .map(ReceivedApplicationItem.fromJson)
            .toList()
        : <ReceivedApplicationItem>[];
    final pending = (body['pendingCount'] as num?)?.toInt() ?? 0;
    return ReceivedApplicationsResult(items: items, pendingCount: pending);
  }

  Future<void> approveApplication({
    required AuthSession session,
    required String applicationId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/v1/applications/$applicationId/approve');
    final resp = await http
        .post(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  Future<void> rejectApplication({
    required AuthSession session,
    required String applicationId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/v1/applications/$applicationId/reject');
    final resp = await http
        .post(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  Future<void> cancelApplication({
    required AuthSession session,
    required String applicationId,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/v1/applications/$applicationId/cancel');
    final resp = await http
        .post(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  /// 我的组局申请列表（我发出的，保留）
  Future<List<PostApplicationItem>> listMyApplications({
    required AuthSession session,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/me/applications');
    final resp = await http
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PostApplicationItem.fromJson)
        .toList();
  }

  /// 查询当前用户是否已申请该帖（正式用户）
  Future<bool> fetchHasApplied({
    required AuthSession session,
    required String postId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/posts/$postId/application');
    final resp = await http
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${session.token}'},
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      return false;
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data['hasApplied'] as bool? ?? false;
    }
    return decoded['hasApplied'] as bool? ?? false;
  }
}

const postService = PostService();
