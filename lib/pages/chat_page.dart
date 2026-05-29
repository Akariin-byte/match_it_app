import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/chat.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.authSession,
  });

  final String conversationId;
  final String peerName;
  final AuthSession authSession;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final List<ChatMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _bindWs();
  }

  @override
  void dispose() {
    chatService.onMessage = null;
    chatService.onAck = null;
    chatService.onError = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _bindWs() {
    chatService.connect(widget.authSession);
    chatService.onMessage = (msg) {
      if (msg.conversationId != widget.conversationId) return;
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.clientId == msg.clientId)) {
          _messages.add(msg);
        }
      });
      _scrollToBottom();
      _markRead(msg.seq);
    };
    chatService.onAck = (clientId, msg) {
      if (msg.conversationId != widget.conversationId) return;
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.clientId == clientId);
        if (i >= 0) {
          _messages[i] = msg.copyWith(status: MessageStatus.sent);
        }
      });
    };
    chatService.onError = (error, {clientId}) {
      if (!mounted || clientId == null) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.clientId == clientId);
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(status: MessageStatus.failed);
        }
      });
    };
  }

  Future<void> _loadHistory() async {
    try {
      final list = await chatService.listMessages(
        session: widget.authSession,
        conversationId: widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      if (_messages.isNotEmpty) {
        _markRead(_messages.last.seq);
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markRead(int seq) {
    chatService.markRead(
      session: widget.authSession,
      conversationId: widget.conversationId,
      seq: seq,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
      id: '',
      conversationId: widget.conversationId,
      senderId: widget.authSession.userId,
      clientId: clientId,
      seq: 0,
      body: text,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    setState(() {
      _messages.add(optimistic);
    });
    _controller.clear();
    _scrollToBottom();
    chatService.sendMessage(
      conversationId: widget.conversationId,
      body: text,
      clientId: clientId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(widget.peerName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF002FA7)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final mine = msg.senderId == widget.authSession.userId;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? const Color(0xFF002FA7) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            msg.body,
                            style: TextStyle(
                              color: mine ? Colors.white : Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: '发消息…',
                          filled: true,
                          fillColor: const Color(0xFFF2F2F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF002FA7),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
