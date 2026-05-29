import 'package:flutter/material.dart';

import 'package:match_it_app/constants/scene_categories.dart';
import 'package:match_it_app/models/post_application.dart';
import 'package:match_it_app/services/auth_service.dart';
import 'package:match_it_app/services/post_service.dart';

/// 消息中心：申请 / 评论 / 关注
class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    required this.authSession,
    required this.isLoggedIn,
    required this.onLogin,
    this.onApplicationsChanged,
  });

  final AuthSession? authSession;
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback? onApplicationsChanged;

  static const Color _brand = Color(0xFF002FA7);
  static const Color _bg = Color(0xFFF2F2F7);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<ReceivedApplicationItem> _applications = const [];
  int _pendingCount = 0;
  bool _loading = false;
  String? _error;
  String? _actingApplicationId;

  bool get _isGuest =>
      !widget.isLoggedIn || widget.authSession?.isGuest != false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession?.token != widget.authSession?.token ||
        oldWidget.isLoggedIn != widget.isLoggedIn) {
      _loadApplications();
    }
  }

  Future<void> _loadApplications() async {
    final session = widget.authSession;
    if (session == null) {
      setState(() {
        _applications = const [];
        _pendingCount = 0;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await postService.listReceivedApplications(session: session);
      if (!mounted) return;
      setState(() {
        _applications = result.items;
        _pendingCount = result.pendingCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyLoadError(e);
      });
    }
  }

  Future<void> _approve(ReceivedApplicationItem item) async {
    final session = widget.authSession;
    if (session == null || !item.isPending) return;
    setState(() => _actingApplicationId = item.id);
    try {
      await postService.approveApplication(
        session: session,
        applicationId: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已通过 ${item.applicantDisplayName} 的申请')),
      );
      await _loadApplications();
      widget.onApplicationsChanged?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _actingApplicationId = null);
    }
  }

  Future<void> _cancel(ReceivedApplicationItem item) async {
    final session = widget.authSession;
    if (session == null || item.status != 'approved') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消资格'),
        content: Text(
          '确认取消 ${item.applicantDisplayName} 的加入资格？\n（如未收到转账可取消）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _actingApplicationId = item.id);
    try {
      await postService.cancelApplication(
        session: session,
        applicationId: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消 ${item.applicantDisplayName} 的资格')),
      );
      await _loadApplications();
      widget.onApplicationsChanged?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _actingApplicationId = null);
    }
  }

  Future<void> _reject(ReceivedApplicationItem item) async {
    final session = widget.authSession;
    if (session == null || !item.isPending) return;
    setState(() => _actingApplicationId = item.id);
    try {
      await postService.rejectApplication(
        session: session,
        applicationId: item.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已拒绝 ${item.applicantDisplayName} 的申请')),
      );
      await _loadApplications();
      widget.onApplicationsChanged?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _actingApplicationId = null);
    }
  }

  String _friendlyLoadError(Object e) {
    final text = e.toString();
    if (text.contains('404')) {
      return '申请接口 404：旧 API 仍在运行。请执行：\n'
          'powershell -File backend\\start-backend-local.ps1 -Restart';
    }
    if (text.contains('applications table missing')) {
      return '数据库缺少申请表，请执行 schema/006_post_applications.sql';
    }
    return '加载失败：$text';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessagesPage._bg,
      appBar: AppBar(
        title: const Text('消息'),
        backgroundColor: MessagesPage._bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: MessagesPage._brand,
          unselectedLabelColor: Colors.black45,
          indicatorColor: MessagesPage._brand,
          indicatorWeight: 2.5,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('申请'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    _Badge(count: _pendingCount),
                  ],
                ],
              ),
            ),
            const Tab(text: '评论'),
            const Tab(text: '关注'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsTab(),
          _buildComingSoonTab(
            icon: Icons.chat_bubble_outline_rounded,
            title: '评论通知',
            hint: '帖子评论、回复将展示在这里',
          ),
          _buildComingSoonTab(
            icon: Icons.favorite_border_rounded,
            title: '关注动态',
            hint: '你关注的用户动态将展示在这里',
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    if (_isGuest) {
      return _buildGuestPrompt();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadApplications,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_applications.isEmpty) {
      return _buildComingSoonTab(
        icon: Icons.mail_outline_rounded,
        title: '暂无收到的申请',
        hint: '有人申请加入你发布的组局时，会出现在这里',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _applications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _applications[index];
          return _ReceivedApplicationTile(
            item: item,
            busy: _actingApplicationId == item.id,
            onApprove: () => _approve(item),
            onReject: () => _reject(item),
            onCancel: () => _cancel(item),
          );
        },
      ),
    );
  }

  Widget _buildGuestPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            const Text(
              '登录后查看申请与互动消息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '游客仅可浏览 Feed',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: MessagesPage._brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonTab({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.black.withValues(alpha: 0.12)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(minWidth: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReceivedApplicationTile extends StatelessWidget {
  const _ReceivedApplicationTile({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final ReceivedApplicationItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final areaLabel = SceneCategories.labelFor(item.postArea);
    final name = item.applicantDisplayName;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '用';
    final phone = item.applicantPhoneMasked?.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE6F0FF),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF002FA7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.wechatContact.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '微信：${item.wechatContact.trim()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF002FA7),
                          ),
                        ),
                      ],
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '申请加入 · ${item.postTitle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.black.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        areaLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!item.isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.status == 'approved'
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.status == 'approved'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
              ],
            ),
            if (item.status == 'approved') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: busy ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFE57373)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text('取消资格（未付款）'),
                ),
              ),
            ],
            if (item.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text('拒绝'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: busy ? null : onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF002FA7),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '确认通过',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
