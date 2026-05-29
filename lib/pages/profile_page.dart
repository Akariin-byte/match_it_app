import 'package:flutter/material.dart';

import 'package:match_it_app/main.dart';
import '../models/match_post.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import 'personalization_page.dart';

/// 小红书式「我」主页
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.authSession,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
    required this.onPersonalizationSaved,
    this.onRequestPublish,
  });

  final UserProfile user;
  final AuthSession? authSession;
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final void Function(UserProfile profile) onPersonalizationSaved;
  final VoidCallback? onRequestPublish;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  int _tabIndex = 0;
  final GlobalKey<_PublishedPostsSectionState> _publishedKey =
      GlobalKey<_PublishedPostsSectionState>();

  static const Color _brand = Color(0xFF002FA7);
  static const Color _bg = Color(0xFFF2F2F7);

  bool get _isGuest =>
      !widget.isLoggedIn || widget.authSession?.isGuest != false;

  void reloadPublished() {
    _publishedKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final name = user.name.trim().isEmpty ? '游客' : user.name.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '游';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _brand,
          onRefresh: () async {
            if (_tabIndex == 0 && !_isGuest) {
              await _publishedKey.currentState?.reload();
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => _showSettingsMenu(context),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _brand.withValues(alpha: 0.12),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isGuest
                                  ? '登录后完善资料，发布与申请组局'
                                  : 'ID ${user.userId.length > 8 ? user.userId.substring(0, 8) : user.userId}…',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                            ),
                            if (widget.authSession?.phone != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.authSession!.phone!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _StatItem(count: '0', label: '关注'),
                      _StatItem(count: '0', label: '粉丝'),
                      _StatItem(count: '0', label: '获赞'),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    user.faceTraits.isEmpty
                        ? '还没有个性标签，去定制你的 # 兴趣吧'
                        : user.faceTraits.map((t) => '#$t').join('  '),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isGuest
                              ? widget.onLogin
                              : () => _openPersonalization(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(_isGuest ? '登录 / 注册' : '编辑资料'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _openPersonalization(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text('个性化'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isGuest)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: const Text(
                        '当前为游客，仅可浏览。发布、申请加入、私聊需先登录。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    children: [
                      _ProfileTabBar(
                        index: _tabIndex,
                        onChanged: (i) {
                          setState(() => _tabIndex = i);
                          if (i == 0) reloadPublished();
                        },
                      ),
                      if (_tabIndex == 0)
                        _PublishedPostsSection(
                          key: _publishedKey,
                          isGuest: _isGuest,
                          authSession: widget.authSession,
                          onLogin: widget.onLogin,
                          onRequestPublish: widget.onRequestPublish,
                        )
                      else
                        _ComingSoonTab(tabIndex: _tabIndex),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: _brand),
                title: const Text('设置'),
                onTap: () => Navigator.pop(ctx),
              ),
              if (!_isGuest)
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
                  title: Text(
                    '退出登录',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onLogout();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPersonalization(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PersonalizationPage(
          initialIntensityScore: widget.user.intensityScore,
          initialPreferredSceneId: widget.user.area,
          initialHashtags: widget.user.faceTraits,
          onSave: (score, sceneId, hashtags) {
            final labels = ['新手', '普通', '进阶', '硬核', '大神'];
            final labelIdx = [0, 25, 50, 75, 100].indexOf(score);
            widget.onPersonalizationSaved(
              widget.user.copyWith(
                area: sceneId,
                intensityScore: score,
                intensityLabel: labelIdx >= 0 ? labels[labelIdx] : '普通',
                isHardcore: sceneId == 'BoardGames' && score >= 75,
                faceTraits: hashtags,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PublishedPostsSection extends StatefulWidget {
  const _PublishedPostsSection({
    super.key,
    required this.isGuest,
    required this.authSession,
    required this.onLogin,
    this.onRequestPublish,
  });

  final bool isGuest;
  final AuthSession? authSession;
  final VoidCallback onLogin;
  final VoidCallback? onRequestPublish;

  @override
  State<_PublishedPostsSection> createState() => _PublishedPostsSectionState();
}

class _PublishedPostsSectionState extends State<_PublishedPostsSection> {
  List<MatchPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(_PublishedPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest && !widget.isGuest) {
      reload();
    }
  }

  Future<void> reload() async {
    if (widget.isGuest) {
      if (mounted) {
        setState(() {
          _loading = false;
          _posts = const [];
          _error = null;
        });
      }
      return;
    }

    final session = widget.authSession;
    if (session == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _posts = const [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final posts = await postService.listMyPublishedPosts(session: session);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _posts = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，请稍后重试';
        _posts = const [];
      });
    }
  }

  Future<void> _openPost(MatchPost post) async {
    final session = widget.authSession;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          post: post,
          hasApplied: post.hasApplied,
          isGuest: widget.isGuest,
          authSession: session,
          onApply: () {},
          onRequestLogin: () async => widget.onLogin(),
        ),
      ),
    );
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return _PublishedEmptyState(
        title: '登录后查看发布',
        subtitle: '绑定手机号后可发布组局并在此管理',
        buttonLabel: '登录 / 注册',
        onAction: widget.onLogin,
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF002FA7))),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: reload, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return _PublishedEmptyState(
        title: '还没有发布组局',
        subtitle: '发布第一条，让同好找到你',
        buttonLabel: '去发布',
        onAction: widget.onRequestPublish ?? () {},
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: _ProfileMasonryGrid(
        posts: _posts,
        onTapPost: _openPost,
      ),
    );
  }
}

class _ProfileMasonryGrid extends StatelessWidget {
  const _ProfileMasonryGrid({
    required this.posts,
    required this.onTapPost,
  });

  final List<MatchPost> posts;
  final void Function(MatchPost post) onTapPost;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    var leftWeight = 0;
    var rightWeight = 0;

    for (final post in posts) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ProfilePostCard(post: post, onTap: () => onTapPost(post)),
      );
      final weight = post.title.length + (post.description.length ~/ 40);
      if (leftWeight <= rightWeight) {
        left.add(card);
        leftWeight += weight;
      } else {
        right.add(card);
        rightWeight += weight;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 10),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.onTap,
  });

  final MatchPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFull = post.isFull;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: const Color(0xFFECECF7),
                  child: const Icon(Icons.image, color: Colors.black26, size: 32),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFull
                          ? '${post.currentMembers}/${post.peopleLimit} 满'
                          : '${post.currentMembers}/${post.peopleLimit}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFull
                          ? Colors.grey.shade200
                          : const Color(0xFFE6F0FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFull ? '已满员' : '组队中',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isFull
                            ? const Color(0xFF424242)
                            : const Color(0xFF002FA7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedEmptyState extends StatelessWidget {
  const _PublishedEmptyState({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Icon(
            Icons.grid_view_rounded,
            size: 44,
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(buttonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF002FA7),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.tabIndex});

  final int tabIndex;

  static const _labels = ['收藏', '赞过'];

  @override
  Widget build(BuildContext context) {
    final label = _labels[tabIndex.clamp(1, 2) - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 40,
            color: Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            '$label 即将上线',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '敬请期待',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = ['发布', '收藏', '赞过'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: index == i ? FontWeight.w800 : FontWeight.w500,
                        color: index == i
                            ? Colors.black87
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: index == i ? 24 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF002FA7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label});

  final String count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
