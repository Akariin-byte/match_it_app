class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientId,
    required this.seq,
    required this.body,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String clientId;
  final int seq;
  final String body;
  final DateTime createdAt;
  final MessageStatus status;

  ChatMessage copyWith({
    String? id,
    int? seq,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      clientId: clientId,
      seq: seq ?? this.seq,
      body: body,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

enum MessageStatus { sending, sent, failed }

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.type,
    required this.otherUser,
    this.postId,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final peer = json['otherUser'];
    final last = json['lastMessage'];
    return ConversationItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'dm',
      postId: json['postId'] as String?,
      otherUser: peer is Map<String, dynamic>
          ? ConversationPeer.fromJson(peer)
          : const ConversationPeer(userId: '', username: '用户'),
      lastMessage: last is Map<String, dynamic>
          ? ChatMessage.fromJson(last)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String type;
  final String? postId;
  final ConversationPeer otherUser;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
}

class ConversationPeer {
  const ConversationPeer({
    required this.userId,
    required this.username,
  });

  factory ConversationPeer.fromJson(Map<String, dynamic> json) {
    return ConversationPeer(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '用户',
    );
  }

  final String userId;
  final String username;
}
