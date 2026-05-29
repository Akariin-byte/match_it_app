import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat.dart';
import 'auth_service.dart';

typedef ChatMessageHandler = void Function(ChatMessage message);
typedef ChatAckHandler = void Function(String clientId, ChatMessage message);

class ChatService {
  ChatService({this.baseUrl = kApiBaseUrl});

  final String baseUrl;
  final _uuid = const Uuid();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  AuthSession? _session;
  ChatMessageHandler? onMessage;
  ChatAckHandler? onAck;
  void Function(String error, {String? clientId})? onError;

  bool get isConnected => _channel != null;

  Future<List<ConversationItem>> listConversations({
    required AuthSession session,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/conversations');
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ConversationItem.fromJson)
        .toList();
  }

  Future<List<ChatMessage>> listMessages({
    required AuthSession session,
    required String conversationId,
    int beforeSeq = 0,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (beforeSeq > 0) query['before_seq'] = '$beforeSeq';
    final uri = Uri.parse('$baseUrl/api/v1/conversations/$conversationId/messages')
        .replace(queryParameters: query);
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<String> createOrGetDM({
    required AuthSession session,
    required String peerUserId,
    String? postId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/conversations/dm');
    final payload = <String, dynamic>{
      'peerUserId': peerUserId,
      if (postId != null && postId.isNotEmpty) 'postId': postId,
    };
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    return data?['conversationId'] as String? ??
        body['conversationId'] as String? ??
        '';
  }

  Future<void> markRead({
    required AuthSession session,
    required String conversationId,
    required int seq,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/conversations/$conversationId/read');
    await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'seq': seq}),
    );
  }

  Future<void> registerDeviceToken({
    required AuthSession session,
    required String platform,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/device-tokens');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'platform': platform, 'token': token}),
    );
    if (resp.statusCode != 200) {
      throw AuthException.fromResponse(resp);
    }
  }

  void connect(AuthSession session) {
    if (session.isGuest) return;
    if (_session?.token == session.token && _channel != null) return;
    disconnect();
    _session = session;
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/api/v1/ws?token=${session.token}');
    _channel = WebSocketChannel.connect(uri);
    _wsSub = _channel!.stream.listen(
      _handleWsData,
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void disconnect() {
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
  }

  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    disconnect();
    _reconnectTimer?.cancel();
    final session = _session;
    if (session == null || session.isGuest) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () => connect(session));
  }

  void _handleWsData(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      if (type == 'message') {
        final msgJson = map['message'];
        if (msgJson is Map<String, dynamic>) {
          onMessage?.call(ChatMessage.fromJson(msgJson));
        }
      } else if (type == 'ack') {
        final clientId = map['clientId'] as String? ?? '';
        final msgJson = map['message'];
        if (msgJson is Map<String, dynamic>) {
          onAck?.call(clientId, ChatMessage.fromJson(msgJson));
        }
      } else if (type == 'error') {
        onError?.call(
          map['error'] as String? ?? 'send failed',
          clientId: map['clientId'] as String?,
        );
      }
    } catch (_) {}
  }

  String sendMessage({
    required String conversationId,
    required String body,
    String? clientId,
  }) {
    final id = clientId ?? _uuid.v4();
    final payload = jsonEncode({
      'type': 'send',
      'conversationId': conversationId,
      'clientId': id,
      'body': body.trim(),
    });
    _channel?.sink.add(payload);
    return id;
  }
}

const chatService = ChatService();
