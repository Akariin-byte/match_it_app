import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat_page.dart';

/// 私信会话列表
class ChatListPage extends StatefulWidget {
  const ChatListPage({
    super.key,
    required this.authSession,
    required this.isLoggedIn,
    required this.onLogin,
  });

  final AuthSession? authSession;
  final bool isLoggedIn;
  final VoidCallback onLogin;

  @override
  State<ChatListPage> createState() => ChatListPageState();
}

class ChatListPageState extends State<ChatListPage> {
  List<ConversationItem> _items = const [];
  bool _loading = true;
  String? _error;

  bool get _isGuest =>
      !widget.isLoggedIn || widget.authSession?.isGuest != false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(ChatListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession?.token != widget.authSession?.token) {
      reload();
    }
  }

  Future<void> reload() async {
    final session = widget.authSession;
    if (_isGuest || session == null) {
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      chatService.connect(session);
      final items = await chatService.listConversations(session: session);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败';
      });
    }
  }

  int get totalUnread => _items.fold(0, (s, i) => s + i.unreadCount);

  Future<void> _openChat(ConversationItem item) async {
    final session = widget.authSession;
    if (session == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          conversationId: item.id,
          peerName: item.otherUser.username,
          authSession: session,
        ),
      ),
    );
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('私信'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isGuest
          ? _GuestPrompt(onLogin: widget.onLogin)
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF002FA7)),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: reload,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无私信\n申请通过后会自动创建会话',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45, height: 1.5),
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF002FA7),
                          onRefresh: reload,
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final preview = item.lastMessage?.body ?? '开始聊天吧';
                              return ListTile(
                                onTap: () => _openChat(item),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE6F0FF),
                                  child: Text(
                                    item.otherUser.username.isNotEmpty
                                        ? item.otherUser.username.substring(0, 1)
                                        : '用',
                                    style: const TextStyle(
                                      color: Color(0xFF002FA7),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item.otherUser.username,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: item.unreadCount > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF3B30),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${item.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          const Text('登录后使用私信'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF002FA7),
            ),
            child: const Text('登录 / 注册'),
          ),
        ],
      ),
    );
  }
}
