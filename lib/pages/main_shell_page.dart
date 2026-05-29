import 'package:flutter/material.dart';

import 'package:match_it_app/main.dart';
import 'package:match_it_app/services/auth_service.dart';
import 'package:match_it_app/services/post_service.dart';
import 'package:match_it_app/services/push_service.dart';
import 'package:match_it_app/widgets/bottom_publish_bar.dart';
import 'package:match_it_app/widgets/login_bottom_sheet.dart';
import 'package:match_it_app/pages/messages_page.dart';
import 'package:match_it_app/pages/chat_list_page.dart';
import 'package:match_it_app/pages/profile_page.dart';

/// 主框架：首页 | 消息 | 私信 | 我
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.user,
    this.authSession,
  });

  final UserProfile user;
  final AuthSession? authSession;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _tabIndex = 0;
  late UserProfile _userProfile;
  AuthSession? _authSession;
  bool _isLoggedIn = false;
  int _applicationBadgeCount = 0;
  int _chatBadgeCount = 0;

  bool get _showsRegisteredUI =>
      _isLoggedIn && _authSession != null && !_authSession!.isGuest;

  @override
  void initState() {
    super.initState();
    _userProfile = widget.user;
    _authSession = widget.authSession;
    _isLoggedIn =
        widget.authSession != null && !widget.authSession!.isGuest;
    _refreshApplicationBadge();
    _refreshChatBadge();
    PushService.registerIfLoggedIn(_authSession);
  }

  Future<void> _refreshApplicationBadge() async {
    final session = _authSession;
    if (!_showsRegisteredUI || session == null) {
      if (mounted) setState(() => _applicationBadgeCount = 0);
      return;
    }
    try {
      final result =
          await postService.listReceivedApplications(session: session);
      if (!mounted) return;
      setState(() => _applicationBadgeCount = result.pendingCount);
      _feedKey.currentState?.reloadFeed();
    } catch (_) {
      if (mounted) setState(() => _applicationBadgeCount = 0);
    }
  }

  Future<void> _refreshChatBadge() async {
    await _chatKey.currentState?.reload();
    if (!mounted) return;
    setState(() => _chatBadgeCount = _chatKey.currentState?.totalUnread ?? 0);
  }

  Future<void> _showLoginBottomSheet() async {
    await LoginBottomSheet.show(
      context,
      initialSession: _authSession,
      onLoginSuccess: (session) {
        setState(() {
          _authSession = session;
          _isLoggedIn = true;
          _userProfile = _userProfile.copyWith(
            name: session.displayName,
            userId: session.userId,
          );
        });
        _feedKey.currentState?.updateUserProfile(_userProfile);
        _refreshApplicationBadge();
        _refreshChatBadge();
        _profileKey.currentState?.reloadPublished();
        PushService.registerIfLoggedIn(session);
      },
    );
  }

  Future<void> _openPublish() async {
    if (!_showsRegisteredUI) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('登录后发布'),
          content: const Text('发布搭子帖需要绑定手机号。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (goLogin == true && mounted) await _showLoginBottomSheet();
      return;
    }

    final feedState = _feedKey.currentState;
    if (feedState != null) {
      await feedState.openPublishPage();
      _profileKey.currentState?.reloadPublished();
    }
  }

  final GlobalKey<MainFeedPageState> _feedKey = GlobalKey();
  final GlobalKey<State<MessagesPage>> _messagesKey = GlobalKey();
  final GlobalKey<ChatListPageState> _chatKey = GlobalKey();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey();

  int get _bottomSelectedIndex => _tabIndex.clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          MainFeedPage(
            key: _feedKey,
            user: _userProfile,
            authSession: _authSession,
            isLoggedIn: _isLoggedIn,
            onUserProfileChanged: (p) => setState(() => _userProfile = p),
            onAuthChanged: (session, loggedIn) {
              setState(() {
                _authSession = session;
                _isLoggedIn = loggedIn;
                if (session != null) {
                  _userProfile = _userProfile.copyWith(
                    name: session.displayName,
                    userId: session.userId,
                  );
                }
              });
              _refreshApplicationBadge();
              _refreshChatBadge();
            },
            onRequestLogin: _showLoginBottomSheet,
            onApplicationChanged: _refreshApplicationBadge,
          ),
          MessagesPage(
            key: _messagesKey,
            authSession: _authSession,
            isLoggedIn: _isLoggedIn,
            onLogin: _showLoginBottomSheet,
            onApplicationsChanged: () {
              _refreshApplicationBadge();
              _refreshChatBadge();
            },
          ),
          ChatListPage(
            key: _chatKey,
            authSession: _authSession,
            isLoggedIn: _isLoggedIn,
            onLogin: _showLoginBottomSheet,
          ),
          ProfilePage(
            key: _profileKey,
            user: _userProfile,
            authSession: _authSession,
            isLoggedIn: _isLoggedIn,
            onLogin: _showLoginBottomSheet,
            onLogout: () async {
              await (_feedKey.currentState?.logout() ?? Future.value());
              _refreshApplicationBadge();
              _refreshChatBadge();
            },
            onPersonalizationSaved: (p) {
              setState(() => _userProfile = p);
              _feedKey.currentState?.updateUserProfile(p);
            },
            onRequestPublish: _openPublish,
          ),
        ],
      ),
      bottomNavigationBar: BottomPublishBar(
        selectedIndex: _bottomSelectedIndex,
        messageBadgeCount: _applicationBadgeCount,
        chatBadgeCount: _chatBadgeCount,
        onHome: () {
          setState(() => _tabIndex = 0);
          _feedKey.currentState?.reloadFeed();
        },
        onMessages: () {
          setState(() => _tabIndex = 1);
          _refreshApplicationBadge();
        },
        onChat: () {
          setState(() => _tabIndex = 2);
          _refreshChatBadge();
        },
        onProfile: () {
          setState(() => _tabIndex = 3);
          _profileKey.currentState?.reloadPublished();
        },
        onPublish: _openPublish,
      ),
    );
  }
}
