import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/vector_match_service.dart';

void main() {
  _initVectorIndex();
  runApp(const MatchItApp());
}

/// 启动时将 mock 帖子向量写入内存索引（生产环境由 DB + pgvector 承担）
void _initVectorIndex() {
  vectorMatchService.indexPosts(
    mockPosts.map((p) => (id: p.id, traits: p.hostFaceTraits)),
  );
}

/// 全局向量匹配服务（客户端 mock；生产环境改为 HTTP → PostgreSQL + Redis）
final vectorMatchService = VectorMatchService();

class UserProfile {
  const UserProfile({
    required this.name,
    required this.area,
    required this.isHardcore,
    required this.intensityScore,
    required this.intensityLabel,
    required this.faceTraits,
    required this.userId,
    this.blockedPostIds = const {},
    this.readPostIds = const {},
  });

  final String name;
  final String area;
  final bool isHardcore;
  final int intensityScore;
  final String intensityLabel;
  /// 用户捏脸特征标签（mock）
  final List<String> faceTraits;
  /// 用户唯一 id（Redis 缓存 key、pgvector 查询用）
  final String userId;
  /// 用户已屏蔽的帖子 id
  final Set<String> blockedPostIds;
  /// 用户已读帖子 id（预留，推荐流可据此降权或隐藏）
  final Set<String> readPostIds;
}

class MatchItApp extends StatelessWidget {
  const MatchItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MATCHit',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF002FA7),
          brightness: Brightness.light,
          surface: Colors.white,
          primary: const Color(0xFF002FA7),
          onPrimary: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ),
      home: const MatchItLoginPage(),
    );
  }
}

class MatchItLoginPage extends StatefulWidget {
  const MatchItLoginPage({super.key});

  @override
  State<MatchItLoginPage> createState() => _MatchItLoginPageState();
}

class _MatchItLoginPageState extends State<MatchItLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _accountFocusNode = FocusNode();
  late final AnimationController _pulseController;
  String? _selectedArea;
  bool _isLoading = false;

  Future<void> _enterAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final session = await authService.guestLogin();
      if (!mounted) return;
      final name = _nameController.text.trim();
      await _openAreaSelection(
        name.isEmpty ? '游客' : name,
        session,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showAuthError('游客登录失败', e.message);
    } catch (e) {
      if (!mounted) return;
      _showAuthError('无法连接后端', '请确认 API 已启动：http://localhost:8080');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _bindPhoneAndContinue() async {
    final phone = _accountController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('请输入手机号'),
          content: const Text('绑定需要有效的 11 位中国大陆手机号。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final session = await authService.guestLogin();
      await authService.bindPhone(session: session, phone: phone);
      if (!mounted) return;
      final name = _nameController.text.trim();
      await _openAreaSelection(
        name.isEmpty ? '用户${phone.substring(phone.length - 4)}' : name,
        session,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showAuthError('绑定失败', e.message);
    } catch (e) {
      if (!mounted) return;
      _showAuthError('无法连接后端', '请确认 API 已启动：http://localhost:8080');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAreaSelection(String name, AuthSession session) async {
    final selectedArea = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AreaSelectionPage(
          name: name,
          authSession: session,
        ),
      ),
    );

    if (selectedArea != null && mounted) {
      setState(() => _selectedArea = selectedArea);
    }
  }

  void _showAuthError(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToAreaSelection() async {
    final name = _nameController.text.trim();
    final account = _accountController.text.trim();

    if (name.isEmpty || account.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('请补全信息'),
            content: const Text('名字和手机号/邮箱都需要填写才能继续。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
      return;
    }

    final selectedArea = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AreaSelectionPage(name: name),
      ),
    );

    if (selectedArea != null && mounted) {
      setState(() => _selectedArea = selectedArea);
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _accountFocusNode.addListener(_handleFocusChange);
    _nameFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _nameFocusNode.dispose();
    _accountFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isFieldFocused =>
      _accountFocusNode.hasFocus || _nameFocusNode.hasFocus;

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blue = const Color(0xFF002FA7);
    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to MATCHit',
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),
              if (_selectedArea != null) ...[
                Text(
                  'Last selected area: ${_selectedArea!.toUpperCase()}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: blue,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Quickly sign in to discover your next match with a clean, iOS-style experience.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      label: 'Name',
                      hint: 'Your name',
                      blue: blue,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _accountController,
                      focusNode: _accountFocusNode,
                      label: 'Phone number or email',
                      hint: 'Enter phone number or email',
                      blue: blue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Continue with',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        SocialLoginButton(
                          label: 'Continue with Phone',
                          icon: Icons.phone_android,
                          backgroundColor: const Color(0xFFF5F5F7),
                          onTap: _isLoading ? () {} : _bindPhoneAndContinue,
                        ),
                        const SizedBox(height: 12),
                        SocialLoginButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple,
                          backgroundColor: const Color(0xFFF5F5F7),
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        SocialLoginButton(
                          label: 'Continue with Google',
                          icon: Icons.mail_outline,
                          backgroundColor: const Color(0xFFF5F5F7),
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _enterAsGuest,
                      child: const Text(
                        '先逛逛，暂不登录',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF002FA7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ScaleTapButton(
                      onTap: _isLoading ? () {} : _goToAreaSelection,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: blue,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('正在连接服务器…'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required Color blue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final borderOpacity = focusNode.hasFocus
                ? 0.2 + _pulseController.value * 0.4
                : 0.0;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: blue.withValues(alpha: borderOpacity),
                  width: focusNode.hasFocus ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: child,
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTapButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: Colors.black87),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScaleTapButton extends StatefulWidget {
  const ScaleTapButton({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  State<ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<ScaleTapButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.96);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 根据分类与强度档位 mock 用户捏脸特征
List<String> mockUserFaceTraits(String area, int intensityScore) {
  final base = switch (area) {
    'BoardGames' => ['策略思维', '桌游爱好者', '逻辑型'],
    'Food' => ['美食探索', '社交型', '慢节奏'],
    'Sport' => ['运动达人', '活力型', '竞争意识'],
    _ => ['开放', '随和'],
  };
  final style = switch (intensityScore) {
    0 || 25 => '休闲派',
    50 => '平衡型',
    75 => '认真派',
    100 => '硬核派',
    _ => '平衡型',
  };
  return [...base, style];
}

/// 捏脸特征匹配分（0–100），基于标签 Jaccard 相似度
int computeFaceMatchScore(List<String> userTraits, List<String> hostTraits) {
  if (userTraits.isEmpty || hostTraits.isEmpty) return 0;
  final userSet = userTraits.toSet();
  final hostSet = hostTraits.toSet();
  final intersection = userSet.intersection(hostSet).length;
  final union = userSet.union(hostSet).length;
  return ((intersection / union) * 100).round();
}

class MatchPost {
  const MatchPost({
    required this.id,
    required this.title,
    required this.description,
    required this.currentMembers,
    required this.maxMembers,
    required this.area,
    required this.tab,
    required this.hardcoreScore,
    required this.hostFaceTraits,
    required this.interactionCount,
    required this.lastActiveTime,
    required this.matchScore,
    required this.hostNickname,
    required this.hostCreditScore,
    required this.eventDateTime,
    required this.eventLocation,
    this.isPinned = false,
    this.pinPriority = 0,
  });

  final String id;
  final String title;
  final String description;
  final int currentMembers;
  final int maxMembers;
  final String area;
  final String tab;
  final int hardcoreScore;
  /// 发帖人捏脸特征（mock，用于实时计算 matchScore）
  final List<String> hostFaceTraits;
  /// 互动数（点赞 + 评论 + 申请等）
  final int interactionCount;
  /// 最后活跃 / 发布时间，用于新鲜度衰减
  final DateTime lastActiveTime;
  /// 捏脸匹配分值 0–100（mock 缓存值；推荐流内会按当前用户重新计算）
  final double matchScore;
  /// 发布者昵称
  final String hostNickname;
  /// 发布者信用分 0–100
  final int hostCreditScore;
  /// 活动日期时间
  final DateTime eventDateTime;
  /// 活动地点
  final String eventLocation;
  /// 官方 / 管理员置顶
  final bool isPinned;
  /// 置顶优先级，越大越靠前
  final int pinPriority;

  bool get isFull => currentMembers >= maxMembers;
}

final List<MatchPost> mockPosts = [
  MatchPost(
    id: 'board_official_1',
    title: '【官方】MATCHit 桌游嘉年华 · 本周末',
    description: '平台官方活动，多桌游同场，报名即送周边。',
    currentMembers: 12,
    maxMembers: 30,
    area: 'BoardGames',
    tab: '推荐',
    hardcoreScore: 55,
    hostFaceTraits: ['策略思维', '桌游爱好者', '社交型', '平衡型'],
    interactionCount: 890,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 1)),
    matchScore: 78,
    hostNickname: 'MATCHit 官方',
    hostCreditScore: 99,
    eventDateTime: DateTime.now().add(const Duration(days: 2, hours: 14)),
    eventLocation: '上海市徐汇区 MATCHit 体验中心',
    isPinned: true,
    pinPriority: 100,
  ),
  MatchPost(
    id: 'board_1',
    title: '周六下午寻找《阿瓦隆》大神局',
    description: '想约一组 5 人局，必须是硬核老手。',
    currentMembers: 3,
    maxMembers: 5,
    area: 'BoardGames',
    tab: '推荐',
    hardcoreScore: 95,
    hostFaceTraits: ['策略思维', '硬核派', '逻辑型', '竞争意识'],
    interactionCount: 420,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 6)),
    matchScore: 40,
    hostNickname: '阿瓦隆老司机',
    hostCreditScore: 92,
    eventDateTime: DateTime.now().add(const Duration(days: 1, hours: 15)),
    eventLocation: '上海市长宁区桌游吧 · 愚园路店',
  ),
  MatchPost(
    id: 'board_2',
    title: '周五晚桌游《卡坦》进阶局',
    description: '熟悉规则，氛围轻松。',
    currentMembers: 2,
    maxMembers: 4,
    area: 'BoardGames',
    tab: '桌游',
    hardcoreScore: 55,
    hostFaceTraits: ['策略思维', '桌游爱好者', '平衡型', '团队配合'],
    interactionCount: 256,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 12)),
    matchScore: 60,
    hostNickname: '卡坦岛民',
    hostCreditScore: 86,
    eventDateTime: DateTime.now().add(const Duration(days: 3, hours: 19)),
    eventLocation: '上海市静安区社区活动中心 3F',
  ),
  MatchPost(
    id: 'board_3',
    title: '周五晚桌游《卡坦》新手局',
    description: '新朋友优先，氛围轻松，地点靠近地铁站。',
    currentMembers: 2,
    maxMembers: 4,
    area: 'BoardGames',
    tab: '桌游',
    hardcoreScore: 20,
    hostFaceTraits: ['桌游爱好者', '休闲派', '社交型', '慢节奏'],
    interactionCount: 98,
    lastActiveTime: DateTime.now().subtract(const Duration(days: 3)),
    matchScore: 20,
    hostNickname: '慢热桌游君',
    hostCreditScore: 78,
    eventDateTime: DateTime.now().add(const Duration(days: 4, hours: 20)),
    eventLocation: '上海市普陀区金沙江路地铁站附近',
  ),
  MatchPost(
    id: 'food_1',
    title: '周末附近美食探店拼餐',
    description: '想找 4 人拼餐，吃遍市区新开餐厅。',
    currentMembers: 3,
    maxMembers: 4,
    area: 'Food',
    tab: '附近',
    hardcoreScore: 30,
    hostFaceTraits: ['美食探索', '社交型', '慢节奏', '拍照打卡'],
    interactionCount: 180,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 20)),
    matchScore: 35,
    hostNickname: '吃货小分队',
    hostCreditScore: 84,
    eventDateTime: DateTime.now().add(const Duration(days: 2, hours: 12)),
    eventLocation: '上海市黄浦区新天地商圈',
  ),
  MatchPost(
    id: 'sport_1',
    title: '周日早晨街头篮球 3v3',
    description: '附近友邻一起玩，装备齐全，轻松娱乐。欢迎热爱运动的你加入。',
    currentMembers: 5,
    maxMembers: 5,
    area: 'Sport',
    tab: '附近',
    hardcoreScore: 40,
    hostFaceTraits: ['运动达人', '活力型', '竞争意识', '早起党'],
    interactionCount: 310,
    lastActiveTime: DateTime.now().subtract(const Duration(days: 1)),
    matchScore: 25,
    hostNickname: '球场老炮',
    hostCreditScore: 88,
    eventDateTime: DateTime.now().add(const Duration(days: 5, hours: 8)),
    eventLocation: '上海市浦东新区张江社区篮球场',
  ),
];

/// 推荐流单帖 Sort Score 分解明细（用于排序与调试日志）
class _RecommendSortBreakdown {
  const _RecommendSortBreakdown({
    required this.postId,
    required this.title,
    required this.interactionBase,
    required this.activityBase,
    required this.matchBase,
    required this.interactionContribution,
    required this.activityContribution,
    required this.matchContribution,
    required this.sortScore,
    required this.usedDefaultActivity,
    required this.usedDefaultMatch,
    required this.isPinned,
  });

  final String postId;
  final String title;
  final double interactionBase;
  final double activityBase;
  final double matchBase;
  final double interactionContribution;
  final double activityContribution;
  final double matchContribution;
  final double sortScore;
  final bool usedDefaultActivity;
  final bool usedDefaultMatch;
  final bool isPinned;
}

class MainFeedPage extends StatefulWidget {
  const MainFeedPage({
    super.key,
    required this.user,
    this.authSession,
  });

  final UserProfile user;
  final AuthSession? authSession;

  @override
  State<MainFeedPage> createState() => _MainFeedPageState();
}

class _MainFeedPageState extends State<MainFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchText = '';
  Map<String, double>? _vectorMatchScoreCache;
  AuthSession? _authSession;
  bool _isBinding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _authSession = widget.authSession;
  }

  Future<void> _showBindPhoneDialog() async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('绑定手机号'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '13800138000',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('绑定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (phone == null || phone.isEmpty || _authSession == null) return;
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的 11 位手机号')),
      );
      return;
    }

    setState(() => _isBinding = true);
    try {
      await authService.bindPhone(session: _authSession!, phone: phone);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定成功：$phone')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败：$e')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法连接后端，请确认 API 已启动')),
      );
    } finally {
      if (mounted) setState(() => _isBinding = false);
    }
  }

  Widget _buildAuthStatusBanner() {
    final session = _authSession;
    if (session == null) return const SizedBox.shrink();

    if (session.isGuest) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: Color(0xFFE65100), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '游客模式',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  Text(
                    'ID: ${session.userId.substring(0, 8)}…',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _isBinding ? null : _showBindPhoneDialog,
              child: Text(_isBinding ? '绑定中…' : '绑定手机'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '已绑定手机号 ${session.phone ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 向量检索 + Redis 缓存，一次请求只算一遍 matchScore
  Map<String, double> get _vectorMatchScores {
    if (_vectorMatchScoreCache != null) return _vectorMatchScoreCache!;
    final postById = {for (final p in mockPosts) p.id: p};
    final query = VectorMatchQuery(
      userId: widget.user.userId,
      userTraits: widget.user.faceTraits,
      area: widget.user.area.trim(),
      scoreTier: widget.user.intensityScore,
      tab: _currentTabLabel,
      blockedPostIds: widget.user.blockedPostIds,
      readPostIds: widget.user.readPostIds,
      searchText: _searchText,
    );
    final results = vectorMatchService.findSimilar(
      query: query,
      postExists: postById.containsKey,
      passesFilters: (id) {
        final post = postById[id];
        if (post == null) return false;
        if (post.area.trim() != query.area) return false;
        if (_shouldExcludeFromRecommendFeed(post)) return false;
        return _matchesSearch(post);
      },
    );
    _vectorMatchScoreCache = {for (final r in results) r.postId: r.matchScore};
    return _vectorMatchScoreCache!;
  }

  void _invalidateVectorCache() {
    _vectorMatchScoreCache = null;
  }

  /// 「匹配」Tab：pgvector 等价逻辑 + Redis 缓存，无 for 循环 Jaccard
  List<MatchPost> _getMatchTabPostsViaVector() {
    final postById = {for (final p in mockPosts) p.id: p};
    final scores = _vectorMatchScores;

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  [_getMatchTabPostsViaVector] 向量检索 + 缓存               ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('  pgvector 参数预览: ${vectorMatchService.buildPgVectorParam(widget.user.faceTraits)}');

    final posts = scores.entries
        .map((e) => postById[e.key])
        .whereType<MatchPost>()
        .toList();

    for (final entry in scores.entries.take(5)) {
      print('  · ${entry.key} → matchScore=${entry.value.toStringAsFixed(1)}');
    }
    print('══════════════════════════════════════════════════════════');

    return posts;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static bool _matchesScoreTier(int postScore, int userScore) {
    switch (userScore) {
      case 0:
        return postScore < 25;
      case 25:
        return postScore >= 25 && postScore < 50;
      case 50:
        return postScore >= 50 && postScore < 75;
      case 75:
        return postScore >= 75 && postScore < 90;
      case 100:
        return postScore >= 90;
      default:
        return false;
    }
  }

  int _faceMatchScore(MatchPost post) =>
      computeFaceMatchScore(widget.user.faceTraits, post.hostFaceTraits);

  // ── 推荐流混合排序系数 ──────────────────────────────────────────
  static const double _kInteractionWeight = 0.4;
  static const double _kActivityWeight = 0.3;
  static const double _kMatchScoreWeight = 0.3;
  /// 新鲜度半衰期：每经过该小时数，活跃权重衰减一半
  static const double _kActivityHalfLifeHours = 48;
  /// 字段缺失时的兜底默认值（0–100）
  static const double _kDefaultMatchScore = 50;
  static const double _kDefaultActivityScore = 30;

  int get _maxInteractionCount => mockPosts
      .map((p) => p.interactionCount)
      .fold(1, (max, count) => count > max ? count : max);

  bool _matchesSearch(MatchPost post) =>
      _searchText.isEmpty ||
      post.title.contains(_searchText) ||
      post.description.contains(_searchText);

  /// 互动基础分 0–100；interactionCount 无效时按 0 处理
  double _resolveInteractionBase(MatchPost post) {
    final count = post.interactionCount < 0 ? 0 : post.interactionCount;
    return _normalizeInteractionCount(count);
  }

  double _normalizeInteractionCount(int interactionCount) =>
      (interactionCount / _maxInteractionCount * 100).clamp(0.0, 100.0);

  /// 活跃基础分 0–100：由 lastActiveTime 衰减；无法计算时用默认值
  (double score, bool usedDefault) _resolveActivityBase(MatchPost post) {
    final time = post.lastActiveTime;
    if (time.year < 2000 ||
        time.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      return (_kDefaultActivityScore, true);
    }
    final elapsed = DateTime.now().difference(time);
    if (elapsed.isNegative) {
      return (_kDefaultActivityScore, true);
    }
    final elapsedHours = elapsed.inMinutes / 60.0;
    final decay = math.pow(0.5, elapsedHours / _kActivityHalfLifeHours);
    return ((decay * 100).clamp(0.0, 100.0).toDouble(), false);
  }

  /// 匹配基础分：优先取向量检索缓存（替代逐帖 Jaccard 循环）
  (double score, bool usedDefault) _resolveMatchBase(MatchPost post) {
    final cached = _vectorMatchScores[post.id];
    if (cached != null) return (cached, false);
    if (post.matchScore.isFinite && post.matchScore > 0) {
      return (post.matchScore.clamp(0.0, 100.0), false);
    }
    return (_kDefaultMatchScore, true);
  }

  /// 按当前用户实时计算捏脸 matchScore（0–100）— 仅 fallback
  double _liveMatchScore(MatchPost post) =>
      _vectorMatchScores[post.id] ?? _faceMatchScore(post).toDouble();

  /// 单帖 Sort Score 明细（含各分项权重贡献）
  _RecommendSortBreakdown _buildSortBreakdown(MatchPost post) {
    final interactionBase = _resolveInteractionBase(post);
    final (activityBase, activityDefault) = _resolveActivityBase(post);
    final (matchBase, matchDefault) = _resolveMatchBase(post);

    final interactionContribution = interactionBase * _kInteractionWeight;
    final activityContribution = activityBase * _kActivityWeight;
    final matchContribution = matchBase * _kMatchScoreWeight;
    final sortScore =
        interactionContribution + activityContribution + matchContribution;

    return _RecommendSortBreakdown(
      postId: post.id,
      title: post.title,
      interactionBase: interactionBase,
      activityBase: activityBase,
      matchBase: matchBase,
      interactionContribution: interactionContribution,
      activityContribution: activityContribution,
      matchContribution: matchContribution,
      sortScore: sortScore,
      usedDefaultActivity: activityDefault,
      usedDefaultMatch: matchDefault,
      isPinned: post.isPinned,
    );
  }

  double _computeSortScore(MatchPost post) => _buildSortBreakdown(post).sortScore;

  void _logSortBreakdown(_RecommendSortBreakdown b) {
    print('  ┌─ [${b.postId}] ${b.title}${b.isPinned ? " [置顶]" : ""}');
    print('  │  互动基础分 : ${b.interactionBase.toStringAsFixed(2)}'
        ' → 贡献 ${b.interactionContribution.toStringAsFixed(2)} (×$_kInteractionWeight)');
    print('  │  活跃基础分 : ${b.activityBase.toStringAsFixed(2)}'
        '${b.usedDefaultActivity ? " [默认]" : ""}'
        ' → 贡献 ${b.activityContribution.toStringAsFixed(2)} (×$_kActivityWeight)');
    print('  │  匹配基础分 : ${b.matchBase.toStringAsFixed(2)}'
        '${b.usedDefaultMatch ? " [默认]" : ""}'
        ' → 贡献 ${b.matchContribution.toStringAsFixed(2)} (×$_kMatchScoreWeight)');
    print('  └─ Sort Score = ${b.sortScore.toStringAsFixed(2)}');
  }

  /// [预留接口] 屏蔽 / 已读过滤
  ///
  /// 后续接入服务端时，只需扩展 blockedPostIds / readPostIds 数据源。
  /// 若产品希望「已读仍展示但降权」，可在此返回 false 并改为 Sort Score 扣分。
  bool _shouldExcludeFromRecommendFeed(MatchPost post) {
    if (widget.user.blockedPostIds.contains(post.id)) return true;
    if (widget.user.readPostIds.contains(post.id)) return true;
    return false;
  }

  int _compareByMixedSort(MatchPost a, MatchPost b) {
    // 置顶帖始终优先
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    if (a.isPinned && b.isPinned) {
      final pinCmp = b.pinPriority.compareTo(a.pinPriority);
      if (pinCmp != 0) return pinCmp;
    }
    return _computeSortScore(b).compareTo(_computeSortScore(a));
  }

  /// 推荐 Tab：混合加权排序
  ///
  /// Sort Score = 互动贡献(×0.4) + 活跃贡献(×0.3) + 匹配贡献(×0.3)
  List<MatchPost> get _getRecommendedPosts {
    final targetArea = widget.user.area.trim();
    final userScore = widget.user.intensityScore;
    final seenIds = <String>{};
    final candidates = <MatchPost>[];

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  [_getRecommendedPosts] 推荐流 · 混合排序                   ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('  目标分类 : "$targetArea"');
    print('  用户分值 : $userScore');
    print('  屏蔽列表 : ${widget.user.blockedPostIds.isEmpty ? "(无)" : widget.user.blockedPostIds.join(", ")}');
    print('  已读列表 : ${widget.user.readPostIds.isEmpty ? "(无)" : widget.user.readPostIds.join(", ")}');
    print('  公式     : Sort Score = 互动×$_kInteractionWeight'
        ' + 活跃×$_kActivityWeight + 匹配×$_kMatchScoreWeight');
    print('  缺省值   : matchScore→$_kDefaultMatchScore, 活跃→$_kDefaultActivityScore');
    print('──────────────────────────────────────────────────────────');

    for (final post in mockPosts) {
      if (post.area.trim() != targetArea) continue;
      if (_shouldExcludeFromRecommendFeed(post)) {
        print('  ✗ [${post.id}] ${post.title} — 屏蔽/已读过滤');
        continue;
      }
      if (!_matchesScoreTier(post.hardcoreScore, userScore)) continue;
      if (!_matchesSearch(post)) continue;
      if (seenIds.contains(post.id)) continue;
      seenIds.add(post.id);
      candidates.add(post);
    }

    // ── 验证：排序前顺序 ──
    final titlesBeforeSort = candidates.map((p) => p.title).toList();
    print('');
    print('  [验证] 排序前 (${titlesBeforeSort.length} 条):');
    for (var i = 0; i < titlesBeforeSort.length; i++) {
      print('    ${i + 1}. ${titlesBeforeSort[i]}');
    }

    // ── 排序（置顶优先 → Sort Score 降序）──
    candidates.sort(_compareByMixedSort);

    final titlesAfterSort = candidates.map((p) => p.title).toList();
    final orderChanged = titlesBeforeSort.join('|') != titlesAfterSort.join('|');

    print('');
    print('  [验证] 排序后 (${titlesAfterSort.length} 条):');
    for (var i = 0; i < titlesAfterSort.length; i++) {
      print('    ${i + 1}. ${titlesAfterSort[i]}');
    }
    print('  [验证] 顺序是否变化: ${orderChanged ? "是 ✓" : "否（原本已有序）"}');
    print('  [验证] 是否降序排列: ${_isSortedDescending(candidates) ? "是 ✓" : "否 ✗"}');

    // ── 逐帖打印 Sort Score 与各分项贡献 ──
    print('');
    print('  [明细] 各帖得分分解:');
    for (final post in candidates) {
      _logSortBreakdown(_buildSortBreakdown(post));
    }
    print('══════════════════════════════════════════════════════════');

    return List<MatchPost>.from(candidates);
  }

  /// 验证非置顶区段是否按 Sort Score 降序（置顶区允许单独规则）
  bool _isSortedDescending(List<MatchPost> posts) {
    for (var i = 0; i < posts.length - 1; i++) {
      final a = posts[i];
      final b = posts[i + 1];
      if (a.isPinned && !b.isPinned) continue;
      if (!a.isPinned && b.isPinned) continue;
      if (_computeSortScore(a) < _computeSortScore(b)) return false;
    }
    return true;
  }

  List<MatchPost> get _filteredPosts {
    final tabLabel = _currentTabLabel;
    final targetArea = widget.user.area.trim();
    final userScore = widget.user.intensityScore;
    final isMatchTab = tabLabel == '匹配';

    if (tabLabel == '推荐') {
      return _getRecommendedPosts;
    }

    if (isMatchTab) {
      return _getMatchTabPostsViaVector();
    }

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  [main.dart _filteredPosts] 开始过滤                      ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('  目标分类 : "$targetArea"');
    print('  用户分值 : $userScore');
    print('  用户捏脸 : ${widget.user.faceTraits}');
    print('  当前 Tab : "$tabLabel"');
    print('  搜索词   : "${_searchText.isEmpty ? "(空)" : _searchText}"');
    print('  数据源   : mockPosts 共 ${mockPosts.length} 条');
    print('──────────────────────────────────────────────────────────');

    final results = <MatchPost>[];
    var round = 0;

    for (final post in mockPosts) {
      if (_shouldExcludeFromRecommendFeed(post)) continue;

      round++;
      final faceScore = _faceMatchScore(post);
      print('');
      print('【第 $round 轮】${post.title}');
      print('  帖子分类 area : "${post.area}"');
      print('  帖子 Tab      : "${post.tab}"');
      print('  帖子分值      : ${post.hardcoreScore}');
      print('  发帖人捏脸    : ${post.hostFaceTraits}');
      print('  捏脸匹配分    : $faceScore');

      final areaMatch = post.area.trim() == targetArea;
      print('  [分类] "${post.area}" == "$targetArea" → ${areaMatch ? "✓" : "✗"}');
      if (!areaMatch) {
        print('  ▶ 剔除 — 分类不符');
        continue;
      }

      if (!isMatchTab) {
        final scoreMatch = _matchesScoreTier(post.hardcoreScore, userScore);
        print('  [分值] ${post.hardcoreScore} vs 用户档位 $userScore → ${scoreMatch ? "✓" : "✗"}');
        if (!scoreMatch) {
          print('  ▶ 剔除 — 分值不在用户档位区间');
          continue;
        }

        final matchesTab = post.tab == tabLabel;
        print('  [Tab] tab="$tabLabel", post.tab="${post.tab}" → ${matchesTab ? "✓" : "✗"}');
        if (!matchesTab) {
          print('  ▶ 剔除 — Tab 不匹配');
          continue;
        }
      }

      if (!_matchesSearch(post)) {
        print('  [搜索] → ✗');
        print('  ▶ 剔除 — 搜索词不匹配');
        continue;
      }

      print('  ▶ 保留');
      results.add(post);
    }

    print('');
    print('  过滤完成: ${results.length}/${mockPosts.length} 条');
    if (isMatchTab) {
      results.sort(
        (a, b) => (_vectorMatchScores[b.id] ?? 0)
            .compareTo(_vectorMatchScores[a.id] ?? 0),
      );
      print('  [匹配 Tab] 向量 matchScore 降序');
      for (final p in results) {
        print('    · ${p.title} → ${_vectorMatchScores[p.id]?.toStringAsFixed(1)}');
      }
    } else {
      results.sort((a, b) => b.hardcoreScore.compareTo(a.hardcoreScore));
    }
    print('══════════════════════════════════════════════════════════');

    return results;
  }

  /// 仅在「同分类」内放宽条件，绝不跨分类展示
  List<MatchPost> get _fallbackPosts {
    final targetArea = widget.user.area.trim();
    final tabLabel = _currentTabLabel;
    final isMatchTab = tabLabel == '匹配';

    if (tabLabel == '推荐') {
      final seenIds = <String>{};
      final list = <MatchPost>[];

      for (final post in mockPosts) {
        if (post.area.trim() != targetArea) continue;
        if (_shouldExcludeFromRecommendFeed(post)) continue;
        if (!_matchesSearch(post)) continue;
        if (seenIds.contains(post.id)) continue;
        seenIds.add(post.id);
        list.add(post);
      }
      list.sort(_compareByMixedSort);
      return list;
    }

    if (isMatchTab) {
      return _getMatchTabPostsViaVector();
    }

    final list = mockPosts.where((post) {
      if (_shouldExcludeFromRecommendFeed(post)) return false;
      if (post.area.trim() != targetArea) return false;
      if (post.tab != tabLabel) return false;
      return _matchesSearch(post);
    }).toList()
      ..sort((a, b) => b.hardcoreScore.compareTo(a.hardcoreScore));
    return list;
  }

  Widget _buildPostCard(BuildContext context, MatchPost post, {int? faceMatchScore}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailPage(post: post),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFECECF7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image,
                  size: 40,
                  color: Colors.black26,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: post.isFull
                              ? Colors.grey.shade200
                              : const Color(0xFFE6F0FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          post.isFull ? '已满员' : '组队中',
                          style: TextStyle(
                            color: post.isFull
                                ? Colors.black54
                                : const Color(0xFF002FA7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (faceMatchScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '匹配 $faceMatchScore%',
                            style: const TextStyle(
                              color: Color(0xFF002FA7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (post.isPinned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF002FA7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '置顶',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _currentTabLabel {
    switch (_tabController.index) {
      case 1:
        return '匹配';
      case 2:
        return '附近';
      case 3:
        return '桌游';
      default:
        return '推荐';
    }
  }

  bool get _isMatchTab => _currentTabLabel == '匹配';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text('MATCHit 首页'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildAuthStatusBanner(),
              Text(
                '嘿，${widget.user.name}，今天想在哪方面找搭子？',
                style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 12),
              if (widget.user.isHardcore && widget.user.area == 'BoardGames')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002FA7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '正在为你寻找：硬核竞技玩家',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (widget.user.isHardcore && widget.user.area == 'BoardGames')
                const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: cardShadow,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: Colors.black54),
                    hintText: 'Search for matches, topics or locations',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                      _invalidateVectorCache();
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: cardShadow,
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  indicator: BoxDecoration(
                    color: const Color(0xFF002FA7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  tabs: const [
                    Tab(text: '推荐'),
                    Tab(text: '匹配'),
                    Tab(text: '附近'),
                    Tab(text: '桌游'),
                  ],
                  onTap: (_) {
                    setState(() {
                      _invalidateVectorCache();
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final posts = _filteredPosts;
                    if (posts.isEmpty) {
                      final fallback = _fallbackPosts;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Text(
                              '当前档位下暂无完全契合的搭子，为你放宽分值条件推荐同分类内容：',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: GridView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: fallback.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemBuilder: (context, index) {
                                final post = fallback[index];
                                return _buildPostCard(
                                  context,
                                  post,
                                  faceMatchScore:
                                      _isMatchTab
                                          ? _vectorMatchScores[post.id]?.round()
                                          : null,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: posts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return _buildPostCard(
                          context,
                          post,
                          faceMatchScore:
                              _isMatchTab
                                  ? _vectorMatchScores[post.id]?.round()
                                  : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostDetailPage extends StatelessWidget {
  const PostDetailPage({super.key, required this.post});

  final MatchPost post;

  static const Color _primary = Color(0xFF002FA7);
  static const Color _background = Color(0xFFF2F2F7);

  String _formatEventDate(DateTime dt) =>
      '${dt.year}年${dt.month}月${dt.day}日';

  String _formatEventTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showApplyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('申请已发送'),
        content: const Text('申请已发送，等待主理人确认。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _onPrivateChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将与 ${post.hostNickname} 开始私聊'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = post.currentMembers / post.maxMembers;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('活动详情'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 发布者用户卡片 ──
                  _buildPublisherCard(),
                  const SizedBox(height: 16),

                  // ── 封面图 ──
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECECF7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.image, size: 48, color: Colors.black26),
                  ),
                  const SizedBox(height: 20),

                  // ── 标题 & 描述 ──
                  Text(
                    post.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 活动日期 / 时间 / 地点 ──
                  _buildEventInfoCard(),
                  const SizedBox(height: 16),

                  // ── 组队进度 & 头像墙 ──
                  _buildTeamSection(progress),
                ],
              ),
            ),
          ),

          // ── 底部交互区 ──
          _buildActionBar(context),
        ],
      ),
    );
  }

  Widget _buildPublisherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _primary.withValues(alpha: 0.12),
            child: Text(
              post.hostNickname.isNotEmpty ? post.hostNickname[0] : '?',
              style: const TextStyle(
                color: _primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.hostNickname,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '信用 ${post.hostCreditScore}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: post.hostFaceTraits
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F0FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: '活动日期',
            value: _formatEventDate(post.eventDateTime),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.access_time,
            label: '活动时间',
            value: _formatEventTime(post.eventDateTime),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: '活动地点',
            value: post.eventLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection(double progress) {
    const avatarSize = 40.0;
    const overlap = 12.0;
    const avatarColors = [
      Color(0xFFE6F0FF),
      Color(0xFFE8F5E9),
      Color(0xFFFFF3E0),
      Color(0xFFF3E5F5),
      Color(0xFFE0F7FA),
      Color(0xFFFBE9E7),
      Color(0xFFEDE7F6),
      Color(0xFFECEFF1),
    ];
    final displayCount = post.currentMembers.clamp(0, 8);
    final avatarWallWidth = displayCount > 0
        ? avatarSize + (displayCount - 1) * (avatarSize - overlap)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '组队情况',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${post.currentMembers}/${post.maxMembers} 人',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: post.isFull ? Colors.black54 : _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: _primary,
              backgroundColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.isFull ? '已满员，可看看其他活动' : '还有 ${post.maxMembers - post.currentMembers} 个名额',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (displayCount > 0) ...[
            const SizedBox(height: 18),
            const Text(
              '已加入',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: avatarSize,
              width: avatarWallWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < displayCount; i++)
                    Positioned(
                      left: i * (avatarSize - overlap),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: avatarSize / 2 - 2,
                          backgroundColor: avatarColors[i % avatarColors.length],
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (post.currentMembers > 8)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '等 ${post.currentMembers} 人已加入',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _onPrivateChat(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('私聊'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: post.isFull ? null : () => _showApplyDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: post.isFull ? Colors.grey.shade400 : _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                post.isFull ? '已满员' : '申请加入',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AreaOption {
  const AreaOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class AreaSelectionPage extends StatefulWidget {
  const AreaSelectionPage({
    super.key,
    required this.name,
    this.authSession,
  });

  final String name;
  final AuthSession? authSession;

  @override
  State<AreaSelectionPage> createState() => _AreaSelectionPageState();
}

class _AreaSelectionPageState extends State<AreaSelectionPage> {
  static const List<AreaOption> _areaOptions = [
    AreaOption(label: 'BoardGames', icon: Icons.sports_esports),
    AreaOption(label: 'Food', icon: Icons.fastfood),
    AreaOption(label: 'Sport', icon: Icons.sports_basketball),
  ];

  String _selectedArea = 'BoardGames';
  int _intensityLevel = 2;

  static const List<String> _intensityLabels = [
    '新手',
    '普通',
    '进阶',
    '硬核',
    '大神',
  ];

  static const List<int> _intensityScores = [0, 25, 50, 75, 100];

  int get _intensityScore => _intensityScores[_intensityLevel];

  bool get _isHardcore => _selectedArea == 'BoardGames' && _intensityScore >= 75;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScaleTapButton(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: cardShadow,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Area Selection',
                    style: theme.textTheme.headlineLarge,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                '嘿，${widget.name}，今天想在哪方面找搭子？',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ..._areaOptions.map((option) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAreaOption(option),
                        )),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('休闲娱乐'),
                        Text('硬核竞技'),
                      ],
                    ),
                    Slider(
                      value: _intensityLevel.toDouble(),
                      min: 0,
                      max: 4,
                      divisions: 4,
                      activeColor: const Color(0xFF002FA7),
                      inactiveColor: Colors.black12,
                      label: _intensityLabels[_intensityLevel],
                      onChanged: (value) {
                        setState(() {
                          _intensityLevel = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _intensityLabels
                          .map(
                            (label) => Expanded(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '当前：${_intensityLabels[_intensityLevel]} · $_intensityScore分',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _isHardcore ? FontWeight.w800 : FontWeight.w600,
                          color: _intensityScore >= 75 ? Colors.red.shade700 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ScaleTapButton(
                onTap: () {
                  final profile = UserProfile(
                    name: widget.name,
                    area: _selectedArea,
                    isHardcore: _isHardcore,
                    intensityScore: _intensityScore,
                    intensityLabel: _intensityLabels[_intensityLevel],
                    faceTraits: mockUserFaceTraits(_selectedArea, _intensityScore),
                    userId: widget.authSession?.userId ??
                        'user-${widget.name.hashCode.abs()}',
                    blockedPostIds: const {'board_3'},
                  );
                  print('当前用户选择的分值: ${profile.intensityScore}');
                  print('当前用户捏脸特征: ${profile.faceTraits}');
                  if (widget.authSession != null) {
                    print('Auth: guest=${widget.authSession!.isGuest} userId=${widget.authSession!.userId}');
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MainFeedPage(
                        user: profile,
                        authSession: widget.authSession,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002FA7),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Confirm selection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaOption(AreaOption option) {
    final selected = _selectedArea == option.label;
    return ScaleTapButton(
      onTap: () {
        setState(() {
          _selectedArea = option.label;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9EDFF) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF002FA7) : Colors.transparent,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(option.icon, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF002FA7)),
          ],
        ),
      ),
    );
  }
}
