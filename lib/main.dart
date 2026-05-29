import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/match_post.dart';
import 'models/post_member.dart';
import 'services/auth_service.dart';
import 'services/post_service.dart';
import 'services/token_storage.dart';
import 'services/vector_match_service.dart';
import 'pages/app_bootstrap_page.dart';
import 'services/push_service.dart';
import 'pages/personalization_page.dart';
import 'pages/publish_page.dart';
import 'constants/scene_categories.dart';
import 'constants/user_hashtags.dart';
import 'widgets/hashtag_chip.dart';
import 'widgets/login_bottom_sheet.dart';
import 'widgets/scene_picker_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.init();
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
  /// 用户 # 个性标签（匹配向量仍用 faceTraits 字段名对接后端）
  final List<String> faceTraits;
  /// 用户唯一 id（Redis 缓存 key、pgvector 查询用）
  final String userId;
  /// 用户已屏蔽的帖子 id
  final Set<String> blockedPostIds;
  /// 用户已读帖子 id（预留，推荐流可据此降权或隐藏）
  final Set<String> readPostIds;

  factory UserProfile.guestDefault({
    required String userId,
    required String name,
  }) {
    const sceneId = 'BoardGames';
    const score = 50;
    return UserProfile(
      name: name.trim().isEmpty ? '游客' : name.trim(),
      area: sceneId,
      isHardcore: false,
      intensityScore: score,
      intensityLabel: '普通',
      faceTraits: UserHashtags.defaultsFor(sceneId, score),
      userId: userId,
    );
  }

  UserProfile copyWith({
    String? name,
    String? area,
    bool? isHardcore,
    int? intensityScore,
    String? intensityLabel,
    List<String>? faceTraits,
    String? userId,
    Set<String>? blockedPostIds,
    Set<String>? readPostIds,
  }) {
    return UserProfile(
      name: name ?? this.name,
      area: area ?? this.area,
      isHardcore: isHardcore ?? this.isHardcore,
      intensityScore: intensityScore ?? this.intensityScore,
      intensityLabel: intensityLabel ?? this.intensityLabel,
      faceTraits: faceTraits ?? this.faceTraits,
      userId: userId ?? this.userId,
      blockedPostIds: blockedPostIds ?? this.blockedPostIds,
      readPostIds: readPostIds ?? this.readPostIds,
    );
  }
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
      home: const AppBootstrapPage(),
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

/// 用户 # 标签默认值（兼容旧 mockUserFaceTraits 调用）
List<String> mockUserFaceTraits(String area, int intensityScore) =>
    UserHashtags.defaultsFor(area, intensityScore);

/// 捏脸特征匹配分（0–100），基于标签 Jaccard 相似度
int computeFaceMatchScore(List<String> userTraits, List<String> hostTraits) {
  if (userTraits.isEmpty || hostTraits.isEmpty) return 0;
  final userSet = userTraits.toSet();
  final hostSet = hostTraits.toSet();
  final intersection = userSet.intersection(hostSet).length;
  final union = userSet.union(hostSet).length;
  return ((intersection / union) * 100).round();
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
    hostFaceTraits: ['桌游', '组局', '官方活动', '氛围轻松'],
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
    hostFaceTraits: ['桌游', '阿瓦隆', '硬核局', '认真局'],
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
    hostFaceTraits: ['桌游', '卡坦', '进阶', '氛围轻松'],
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
    hostFaceTraits: ['桌游', '卡坦', '新手友好', '同城'],
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
    hostFaceTraits: ['探店', '美食', '拼餐', '氛围轻松'],
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
    hostFaceTraits: ['篮球', '运动', '3v3', '周末局'],
    interactionCount: 310,
    lastActiveTime: DateTime.now().subtract(const Duration(days: 1)),
    matchScore: 25,
    hostNickname: '球场老炮',
    hostCreditScore: 88,
    eventDateTime: DateTime.now().add(const Duration(days: 5, hours: 8)),
    eventLocation: '上海市浦东新区张江社区篮球场',
  ),
  MatchPost(
    id: 'board_4',
    title: '#狼人杀 缺4人',
    description: '今晚 8 点开局，有法官，新手可带，氛围欢乐不贴脸。',
    currentMembers: 4,
    maxMembers: 8,
    area: 'BoardGames',
    tab: '桌游',
    hardcoreScore: 35,
    hostFaceTraits: ['狼人杀', '桌游', '欢乐局', '周末夜'],
    interactionCount: 512,
    lastActiveTime: DateTime.now().subtract(const Duration(minutes: 45)),
    matchScore: 72,
    hostNickname: '法官小姐姐',
    hostCreditScore: 91,
    eventDateTime: DateTime.now().add(const Duration(hours: 6)),
    eventLocation: '上海市杨浦区大学路剧本杀馆',
  ),
  MatchPost(
    id: 'board_5',
    title: '剧本杀《年轮》拼车 · 差2女',
    description: '情感本，6人本，已有4人，希望不跳车、能沉浸。',
    currentMembers: 4,
    maxMembers: 6,
    area: 'BoardGames',
    tab: '推荐',
    hardcoreScore: 60,
    hostFaceTraits: ['剧本杀', '情感本', '沉浸', '桌游'],
    interactionCount: 367,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 3)),
    matchScore: 55,
    hostNickname: '剧本杀队长',
    hostCreditScore: 89,
    eventDateTime: DateTime.now().add(const Duration(days: 1, hours: 19)),
    eventLocation: '上海市虹口区四川北路',
  ),
  MatchPost(
    id: 'board_6',
    title: '《血染钟楼》入门局欢迎萌新',
    description: '主持人带规则，预计 2.5 小时，结束后可一起夜宵。',
    currentMembers: 6,
    maxMembers: 10,
    area: 'BoardGames',
    tab: '桌游',
    hardcoreScore: 25,
    hostFaceTraits: ['血染钟楼', '新手友好', '桌游', '夜宵局'],
    interactionCount: 143,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 8)),
    matchScore: 48,
    hostNickname: '钟楼守夜人',
    hostCreditScore: 82,
    eventDateTime: DateTime.now().add(const Duration(days: 2, hours: 20)),
    eventLocation: '上海市闵行区莘庄商圈',
  ),
  MatchPost(
    id: 'anime_1',
    title: 'CP30 漫展同行 · 约妆造互拍',
    description: '周六全天，已有门票，求同坑 coser 一起逛展打卡。',
    currentMembers: 2,
    maxMembers: 4,
    area: 'AnimeCon',
    tab: '推荐',
    hardcoreScore: 40,
    hostFaceTraits: ['漫展', 'cos', '摄影', '互拍'],
    interactionCount: 628,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 2)),
    matchScore: 65,
    hostNickname: '二刺猿日常',
    hostCreditScore: 87,
    eventDateTime: DateTime.now().add(const Duration(days: 6, hours: 9)),
    eventLocation: '杭州市萧山区国际博览中心',
  ),
  MatchPost(
    id: 'photo_1',
    title: '外滩夜景人像约拍',
    description: '自带灯棒，返 9 张精修，希望模特有街拍经验。',
    currentMembers: 1,
    maxMembers: 2,
    area: 'Photo',
    tab: '附近',
    hardcoreScore: 50,
    hostFaceTraits: ['摄影', '人像', '夜景', '外滩'],
    interactionCount: 201,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 14)),
    matchScore: 42,
    hostNickname: '快门猎人',
    hostCreditScore: 93,
    eventDateTime: DateTime.now().add(const Duration(days: 1, hours: 18)),
    eventLocation: '上海市黄浦区中山东一路',
  ),
  MatchPost(
    id: 'game_1',
    title: '王者五排缺辅助 · 星耀局',
    description: '语音开黑，不喷人，能保射手，晚上 9 点后在线。',
    currentMembers: 4,
    maxMembers: 5,
    area: 'Game',
    tab: '匹配',
    hardcoreScore: 70,
    hostFaceTraits: ['王者荣耀', '开黑', '星耀', '语音局'],
    interactionCount: 445,
    lastActiveTime: DateTime.now().subtract(const Duration(minutes: 20)),
    matchScore: 58,
    hostNickname: '野王请带飞',
    hostCreditScore: 85,
    eventDateTime: DateTime.now().add(const Duration(hours: 4)),
    eventLocation: '线上 · 微信语音',
  ),
  MatchPost(
    id: 'game_2',
    title: '黑神话联机 Boss 互助',
    description: '卡关求大佬，也可一起探索隐藏，PC 端 Steam。',
    currentMembers: 2,
    maxMembers: 4,
    area: 'Game',
    tab: '推荐',
    hardcoreScore: 55,
    hostFaceTraits: ['黑神话', 'Steam', '联机', '互助'],
    interactionCount: 892,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 1)),
    matchScore: 38,
    hostNickname: '悟空残影',
    hostCreditScore: 90,
    eventDateTime: DateTime.now().add(const Duration(hours: 3)),
    eventLocation: '线上 · Discord',
  ),
  MatchPost(
    id: 'travel_1',
    title: '清明小长假安吉露营 · 差2人拼车',
    description: '自驾上海出发，帐篷可租，会做饭优先，AA 制。',
    currentMembers: 4,
    maxMembers: 6,
    area: 'Travel',
    tab: '附近',
    hardcoreScore: 35,
    hostFaceTraits: ['露营', '自驾', '户外', '拼车'],
    interactionCount: 278,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 5)),
    matchScore: 50,
    hostNickname: '山野旅人',
    hostCreditScore: 86,
    eventDateTime: DateTime.now().add(const Duration(days: 10, hours: 7)),
    eventLocation: '浙江省湖州市安吉县',
  ),
  MatchPost(
    id: 'study_1',
    title: '图书馆自习搭子 · 考研冲刺',
    description: '复旦附近，每天 9–18 点，互相监督不看手机。',
    currentMembers: 3,
    maxMembers: 6,
    area: 'Study',
    tab: '推荐',
    hardcoreScore: 80,
    hostFaceTraits: ['自习', '考研', '监督', '安静'],
    interactionCount: 156,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 10)),
    matchScore: 33,
    hostNickname: '早起刷题人',
    hostCreditScore: 88,
    eventDateTime: DateTime.now().add(const Duration(days: 1, hours: 9)),
    eventLocation: '上海市杨浦区复旦大学周边',
  ),
  MatchPost(
    id: 'pet_1',
    title: '周末遛狗局 · 大型犬友好',
    description: '世纪公园晨遛，家有金毛，求同好交流喂养心得。',
    currentMembers: 5,
    maxMembers: 8,
    area: 'Pet',
    tab: '附近',
    hardcoreScore: 15,
    hostFaceTraits: ['宠物', '遛狗', '金毛', '周末晨'],
    interactionCount: 124,
    lastActiveTime: DateTime.now().subtract(const Duration(days: 2)),
    matchScore: 28,
    hostNickname: '毛孩子家长',
    hostCreditScore: 81,
    eventDateTime: DateTime.now().add(const Duration(days: 3, hours: 7)),
    eventLocation: '上海市浦东新区世纪公园',
  ),
  MatchPost(
    id: 'music_1',
    title: 'Livehouse 拼票 · 独立乐队场',
    description: '本周五演出，多一张票，一起拼车往返静安。',
    currentMembers: 1,
    maxMembers: 2,
    area: 'Music',
    tab: '推荐',
    hardcoreScore: 30,
    hostFaceTraits: ['livehouse', '独立音乐', '拼票', '周五夜'],
    interactionCount: 233,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 7)),
    matchScore: 45,
    hostNickname: '耳机不离身',
    hostCreditScore: 83,
    eventDateTime: DateTime.now().add(const Duration(days: 4, hours: 20)),
    eventLocation: '上海市静安区 MAO Livehouse',
  ),
  MatchPost(
    id: 'outdoor_1',
    title: '周六徒步九溪 · 休闲线',
    description: '约 12km，中等强度，自带水和干粮，下雨顺延。',
    currentMembers: 7,
    maxMembers: 12,
    area: 'Outdoor',
    tab: '附近',
    hardcoreScore: 45,
    hostFaceTraits: ['徒步', '户外', '九溪', '周末'],
    interactionCount: 389,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 4)),
    matchScore: 52,
    hostNickname: '山系青年',
    hostCreditScore: 87,
    eventDateTime: DateTime.now().add(const Duration(days: 5, hours: 8)),
    eventLocation: '杭州市西湖区九溪烟树入口',
  ),
  MatchPost(
    id: 'drive_1',
    title: '虹桥机场接机拼车 · 今晚 22:30',
    description: '航班 MU5101，可拼 2 人，行李不多的来。',
    currentMembers: 1,
    maxMembers: 3,
    area: 'Drive',
    tab: '附近',
    hardcoreScore: 20,
    hostFaceTraits: ['拼车', '接机', '虹桥', '今晚'],
    interactionCount: 67,
    lastActiveTime: DateTime.now().subtract(const Duration(minutes: 12)),
    matchScore: 22,
    hostNickname: '顺风车老司机',
    hostCreditScore: 79,
    eventDateTime: DateTime.now().add(const Duration(hours: 8)),
    eventLocation: '上海虹桥国际机场 T2',
  ),
  MatchPost(
    id: 'food_2',
    title: '深夜火锅局 · 缺2人',
    description: '重庆牛油锅底，能吃辣的来，人均约 120。',
    currentMembers: 4,
    maxMembers: 6,
    area: 'Food',
    tab: '推荐',
    hardcoreScore: 25,
    hostFaceTraits: ['火锅', '夜宵', '辣', '拼桌'],
    interactionCount: 334,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 2)),
    matchScore: 61,
    hostNickname: '无辣不欢',
    hostCreditScore: 84,
    eventDateTime: DateTime.now().add(const Duration(hours: 5)),
    eventLocation: '上海市长宁区中山公园龙之梦附近',
  ),
  MatchPost(
    id: 'sport_2',
    title: '羽毛球双打 · 中级水平',
    description: '静安体育馆订场 2 小时，自带拍，求固定搭子。',
    currentMembers: 2,
    maxMembers: 4,
    area: 'Sport',
    tab: '匹配',
    hardcoreScore: 65,
    hostFaceTraits: ['羽毛球', '双打', '运动', '中级'],
    interactionCount: 198,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 18)),
    matchScore: 47,
    hostNickname: '羽球小张',
    hostCreditScore: 86,
    eventDateTime: DateTime.now().add(const Duration(days: 2, hours: 14)),
    eventLocation: '上海市静安区羽毛球馆',
  ),
  MatchPost(
    id: 'sport_3',
    title: '晨跑 5km · 徐汇滨江',
    description: '配速 6 分左右，跑完一起喝咖啡，新手也可跟跑。',
    currentMembers: 3,
    maxMembers: 8,
    area: 'Sport',
    tab: '附近',
    hardcoreScore: 30,
    hostFaceTraits: ['跑步', '晨跑', '滨江', '咖啡局'],
    interactionCount: 112,
    lastActiveTime: DateTime.now().subtract(const Duration(hours: 22)),
    matchScore: 36,
    hostNickname: '早起跑者',
    hostCreditScore: 80,
    eventDateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    eventLocation: '上海市徐汇区徐汇滨江绿道',
  ),
  MatchPost(
    id: 'other_1',
    title: '同城读书会 · 《被讨厌的勇气》',
    description: '线下分享 1 小时，限 8 人，需提前读完前三章。',
    currentMembers: 6,
    maxMembers: 8,
    area: 'Other',
    tab: '推荐',
    hardcoreScore: 40,
    hostFaceTraits: ['读书会', '心理学', '线下', '分享'],
    interactionCount: 89,
    lastActiveTime: DateTime.now().subtract(const Duration(days: 1)),
    matchScore: 30,
    hostNickname: '书虫阿宁',
    hostCreditScore: 85,
    eventDateTime: DateTime.now().add(const Duration(days: 7, hours: 15)),
    eventLocation: '上海市黄浦区思南公馆附近咖啡馆',
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

  /// 首页 Feed：展示推荐/匹配等 Tab
class MainFeedPage extends StatefulWidget {
  const MainFeedPage({
    super.key,
    required this.user,
    this.authSession,
    this.isLoggedIn = false,
    this.onUserProfileChanged,
    this.onAuthChanged,
    this.onRequestLogin,
    this.onApplicationChanged,
  });

  final UserProfile user;
  final AuthSession? authSession;
  final bool isLoggedIn;
  final ValueChanged<UserProfile>? onUserProfileChanged;
  final void Function(AuthSession? session, bool isLoggedIn)? onAuthChanged;
  final Future<void> Function()? onRequestLogin;
  final VoidCallback? onApplicationChanged;

  @override
  State<MainFeedPage> createState() => MainFeedPageState();
}

class MainFeedPageState extends State<MainFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late UserProfile _userProfile;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  String _searchText = '';
  String _browseSceneId = SceneCategories.allId;
  String? _lastPublishSceneId;
  final Set<String> _appliedPostIds = {};
  /// 已关注发布者（hostUserId 优先，否则 hostNickname）
  final Set<String> _followedHostKeys = {};
  Map<String, double>? _vectorMatchScoreCache;
  AuthSession? _authSession;
  bool _feedFromApi = false;
  List<MatchPost> _apiPosts = const [];
  bool _feedLoading = false;
  /// 是否处于「已登录/已绑定」UI 状态（退出后为 false，即使 device_id 对应正式账号）
  bool _isLoggedIn = false;

  /// API 拉取成功后用库内帖子；否则回退 mock（离线/后端未启）
  List<MatchPost> get _feedSource => _feedFromApi ? _apiPosts : mockPosts;

  static const List<String> _intensityLabels = ['新手', '普通', '进阶', '硬核', '大神'];

  bool get _showsRegisteredUI =>
      _isLoggedIn && _authSession != null && !_authSession!.isGuest;

  bool _postMatchesBrowse(MatchPost post) =>
      SceneCategories.postAreaMatchesBrowse(post.area.trim(), _browseSceneId);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    _userProfile = widget.user;
    _authSession = widget.authSession;
    _isLoggedIn = widget.isLoggedIn ||
        (widget.authSession != null && !widget.authSession!.isGuest);
    _mergeDefaultFollowedHosts(mockPosts);
    _bootstrapFeed();
  }

  String _hostKey(MatchPost post) {
    final id = post.hostUserId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return post.hostNickname.trim().isEmpty ? post.id : post.hostNickname.trim();
  }

  void _mergeDefaultFollowedHosts(Iterable<MatchPost> posts) {
    for (final post in posts) {
      if (post.isPinned || post.hostNickname.contains('官方')) {
        _followedHostKeys.add(_hostKey(post));
      }
    }
  }

  bool _isHostFollowed(MatchPost post) => _followedHostKeys.contains(_hostKey(post));

  void _toggleFollowHost(MatchPost post) {
    final key = _hostKey(post);
    setState(() {
      if (_followedHostKeys.contains(key)) {
        _followedHostKeys.remove(key);
      } else {
        _followedHostKeys.add(key);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void updateUserProfile(UserProfile profile) {
    setState(() => _userProfile = profile);
    _invalidateVectorCache();
  }

  Future<void> openPublishPage() => _openPublishPage();

  Future<void> logout() => _logout();

  Future<void> reloadFeed() => _loadFeedPosts();

  @override
  void didUpdateWidget(MainFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _userProfile = widget.user;
      _invalidateVectorCache();
    }
    if (widget.authSession != oldWidget.authSession) {
      _authSession = widget.authSession;
      _loadFeedPosts();
    }
    if (widget.isLoggedIn != oldWidget.isLoggedIn) {
      _isLoggedIn = widget.isLoggedIn;
    }
  }

  /// 从本地 secure storage 恢复已绑定用户的 Token
  Future<void> _restoreSessionFromStorage() async {
    final saved = await tokenStorage.loadSession();
    if (!mounted || saved == null) return;
    if (saved.isGuest) return;
    setState(() {
      _authSession = saved;
      _isLoggedIn = true;
    });
  }

  Future<void> _bootstrapFeed() async {
    await _restoreSessionFromStorage();
    if (!mounted) return;
    await _loadFeedPosts();
  }

  Future<AuthSession?> _sessionForApi() async {
    if (_authSession != null) return _authSession;
    return tokenStorage.loadSession();
  }

  Future<void> _loadFeedPosts() async {
    final session = await _sessionForApi();
    if (session == null || !mounted) return;

    setState(() => _feedLoading = true);
    try {
      final tab = _currentTabLabel;
      final tabParam = tab == '推荐' ? '' : tab;
      final posts = await postService.listPosts(
        session: session,
        tab: tabParam,
      );
      if (!mounted) return;
      setState(() {
        _apiPosts = posts;
        _feedFromApi = true;
        _feedLoading = false;
        _mergeDefaultFollowedHosts(posts);
        _appliedPostIds
          ..clear()
          ..addAll(posts.where((p) => p.hasApplied).map((p) => p.id));
      });
      _reindexFeedVectors();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedFromApi = false;
        _feedLoading = false;
      });
    }
  }

  void _reindexFeedVectors() {
    vectorMatchService.indexPosts(
      _feedSource.map((p) => (id: p.id, traits: p.hostFaceTraits)),
    );
    _invalidateVectorCache();
  }

  /// 打开登录/绑定 BottomSheet（由 Shell 托管时走 onRequestLogin）
  Future<void> _showLoginBottomSheet() async {
    if (widget.onRequestLogin != null) {
      await widget.onRequestLogin!();
      return;
    }
    await LoginBottomSheet.show(
      context,
      initialSession: _authSession,
      onLoginSuccess: _onLoginSuccess,
    );
  }

  void _onLoginSuccess(AuthSession session) {
    setState(() {
      _authSession = session;
      _isLoggedIn = true;
      _userProfile = _userProfile.copyWith(
        name: session.displayName,
        userId: session.userId,
      );
    });
    widget.onAuthChanged?.call(session, true);
    widget.onUserProfileChanged?.call(_userProfile);
    _loadFeedPosts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('登录成功，已绑定 ${session.phone ?? ''}')),
    );
  }

  /// 首页「我在看什么」场景筛选
  Future<void> _openBrowseFilter() async {
    final picked = await ScenePickerSheet.show(
      context,
      selectedId: _browseSceneId == SceneCategories.allId ? null : _browseSceneId,
      includeAll: true,
      title: '我在看什么',
      subtitle: '筛选首页展示的组局类型，不影响发布时的分类选择',
    );
    if (picked != null && mounted) {
      setState(() {
        _browseSceneId = picked;
        _invalidateVectorCache();
      });
      await _loadFeedPosts();
    }
  }

  /// 个人中心 · 个性化定制（可选，游客也可进入）
  Future<void> _openPersonalization() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PersonalizationPage(
          initialIntensityScore: _userProfile.intensityScore,
          initialPreferredSceneId: _userProfile.area,
          initialHashtags: _userProfile.faceTraits,
          onSave: (score, sceneId, hashtags) {
            final labelIdx = [0, 25, 50, 75, 100].indexOf(score);
            setState(() {
              _userProfile = _userProfile.copyWith(
                area: sceneId,
                intensityScore: score,
                intensityLabel:
                    labelIdx >= 0 ? _intensityLabels[labelIdx] : '普通',
                isHardcore: sceneId == 'BoardGames' && score >= 75,
                faceTraits: UserHashtags.normalizeAll(hashtags),
              );
              _invalidateVectorCache();
            });
            widget.onUserProfileChanged?.call(_userProfile);
          },
        ),
      ),
    );
  }

  /// 发布入口：游客引导登录，正式用户进发布页
  Future<void> _openPublishPage() async {
    if (!_showsRegisteredUI) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('登录后发布'),
          content: const Text('发布搭子帖需要绑定手机号，与小红书一致：先登录再发布。'),
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
      if (goLogin == true && mounted) {
        await _showLoginBottomSheet();
      }
      return;
    }

    final suggestedScene = _lastPublishSceneId ??
        (_browseSceneId != SceneCategories.allId
            ? _browseSceneId
            : _userProfile.area);

    final publishedSceneId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PublishPage(
          hostName: _authSession?.displayName ?? _userProfile.name,
          suggestedSceneId: suggestedScene,
          hostFaceTraits: _userProfile.faceTraits,
          intensityScore: _userProfile.intensityScore,
          authSession: _authSession,
        ),
      ),
    );

    if (publishedSceneId != null &&
        publishedSceneId.isNotEmpty &&
        mounted) {
      setState(() => _lastPublishSceneId = publishedSceneId);
      await _loadFeedPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '发布成功（${SceneCategories.labelFor(publishedSceneId)}），Feed 已刷新',
          ),
        ),
      );
    }
  }

  /// 退出登录：吊销服务端 Token，清除本地缓存，重新进入游客模式
  Future<void> _logout() async {
    final session = _authSession;
    if (session != null) {
      try {
        await authService.logout(session);
      } catch (_) {
        // 本地仍清除，方便联调
      }
    }
    await tokenStorage.clear();
    if (!mounted) return;

    try {
      final guest = await authService.guestLogin(username: _userProfile.name);
      if (!mounted) return;
      setState(() {
        _authSession = guest;
        _isLoggedIn = false;
        _userProfile = _userProfile.copyWith(
          name: guest.displayName,
          userId: guest.userId,
        );
      });
      widget.onAuthChanged?.call(guest, false);
      widget.onUserProfileChanged?.call(_userProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已退出登录，当前为游客模式')),
      );
    } catch (_) {
      setState(() {
        _authSession = widget.authSession;
        _isLoggedIn = false;
      });
      widget.onAuthChanged?.call(widget.authSession, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除本地登录状态')),
        );
      }
    }
  }

  /// AppBar 内小红书式圆角搜索框
  Widget _buildAppBarSearch() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: '搜索组局、话题、地点',
          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.black45, size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {
            _searchText = value.trim();
            _invalidateVectorCache();
          });
        },
      ),
    );
  }

  /// 顶部身份横幅：橙色=游客，绿色=已绑定手机
  Widget _buildAuthStatusBanner() {
    final session = _authSession;
    if (session == null) return const SizedBox.shrink();

    if (!_showsRegisteredUI) {
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
              onPressed: _showLoginBottomSheet,
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      );
    }

    // 已登录：右上角头像 + 菜单退出即可，不必再占一条绿色横幅（参考小红书）
    return const SizedBox.shrink();
  }

  /// 向量检索 + Redis 缓存，一次请求只算一遍 matchScore
  Map<String, double> get _vectorMatchScores {
    if (_vectorMatchScoreCache != null) return _vectorMatchScoreCache!;
    final postById = {for (final p in _feedSource) p.id: p};
    final query = VectorMatchQuery(
      userId: _userProfile.userId,
      userTraits: _userProfile.faceTraits,
      area: _userProfile.area.trim(),
      scoreTier: _userProfile.intensityScore,
      tab: _currentTabLabel,
      blockedPostIds: _userProfile.blockedPostIds,
      readPostIds: _userProfile.readPostIds,
      searchText: _searchText,
    );
    final results = vectorMatchService.findSimilar(
      query: query,
      postExists: postById.containsKey,
      passesFilters: (id) {
        final post = postById[id];
        if (post == null) return false;
        if (!_postMatchesBrowse(post)) return false;
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
    final postById = {for (final p in _feedSource) p.id: p};
    final scores = _vectorMatchScores;

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  [_getMatchTabPostsViaVector] 向量检索 + 缓存               ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('  pgvector 参数预览: ${vectorMatchService.buildPgVectorParam(_userProfile.faceTraits)}');

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
      computeFaceMatchScore(_userProfile.faceTraits, post.hostFaceTraits);

  String _formatEventBrief(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return '今天 $time';
    if (day == today.add(const Duration(days: 1))) return '明天 $time';
    return '${dt.month}月${dt.day}日 $time';
  }

  int _estimatePostCardWeight(MatchPost post) {
    var weight = post.title.length > 18 ? 2 : 1;
    weight += post.hostFaceTraits.length.clamp(0, 3);
    if (post.description.trim().isNotEmpty) weight += 1;
    if (post.isPinned || post.isFull) weight += 1;
    return weight;
  }

  Widget _buildMasonryPostGrid(
    List<MatchPost> posts, {
    required bool showMatchScore,
  }) {
    final left = <Widget>[];
    final right = <Widget>[];
    var leftWeight = 0;
    var rightWeight = 0;

    for (final post in posts) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildPostCard(
          context,
          post,
          faceMatchScore:
              showMatchScore ? _vectorMatchScores[post.id]?.round() : null,
        ),
      );
      final weight = _estimatePostCardWeight(post);
      if (leftWeight <= rightWeight) {
        left.add(card);
        leftWeight += weight;
      } else {
        right.add(card);
        rightWeight += weight;
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: left,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 推荐流混合排序系数 ──────────────────────────────────────────
  static const double _kInteractionWeight = 0.4;
  static const double _kActivityWeight = 0.3;
  static const double _kMatchScoreWeight = 0.3;
  /// 新鲜度半衰期：每经过该小时数，活跃权重衰减一半
  static const double _kActivityHalfLifeHours = 48;
  /// 字段缺失时的兜底默认值（0–100）
  static const double _kDefaultMatchScore = 50;
  static const double _kDefaultActivityScore = 30;

  int get _maxInteractionCount => _feedSource
      .map((p) => p.interactionCount)
      .fold(1, (max, count) => count > max ? count : max);

  bool _matchesSearch(MatchPost post) {
    if (_searchText.isEmpty) return true;
    final q = _searchText.trim();
    if (post.title.contains(q) || post.description.contains(q)) return true;
    for (final tag in post.hostFaceTraits) {
      if (tag.contains(q) || UserHashtags.format(tag).contains(q)) {
        return true;
      }
    }
    return false;
  }

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
    if (_userProfile.blockedPostIds.contains(post.id)) return true;
    if (_userProfile.readPostIds.contains(post.id)) return true;
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
    final browseLabel = SceneCategories.labelFor(_browseSceneId);
    final userScore = _userProfile.intensityScore;
    final seenIds = <String>{};
    final candidates = <MatchPost>[];

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║  [_getRecommendedPosts] 推荐流 · 混合排序                   ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('  浏览筛选 : "$browseLabel" ($_browseSceneId)');
    print('  用户分值 : $userScore');
    print('  屏蔽列表 : ${_userProfile.blockedPostIds.isEmpty ? "(无)" : _userProfile.blockedPostIds.join(", ")}');
    print('  已读列表 : ${_userProfile.readPostIds.isEmpty ? "(无)" : _userProfile.readPostIds.join(", ")}');
    print('  公式     : Sort Score = 互动×$_kInteractionWeight'
        ' + 活跃×$_kActivityWeight + 匹配×$_kMatchScoreWeight');
    print('  缺省值   : matchScore→$_kDefaultMatchScore, 活跃→$_kDefaultActivityScore');
    print('──────────────────────────────────────────────────────────');

    for (final post in _feedSource) {
      if (!_postMatchesBrowse(post)) continue;
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
    final browseLabel = SceneCategories.labelFor(_browseSceneId);
    final userScore = _userProfile.intensityScore;
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
    print('  浏览筛选 : "$browseLabel" ($_browseSceneId)');
    print('  用户分值 : $userScore');
    print('  用户捏脸 : ${_userProfile.faceTraits}');
    print('  当前 Tab : "$tabLabel"');
    print('  搜索词   : "${_searchText.isEmpty ? "(空)" : _searchText}"');
    print('  数据源   : Feed 共 ${_feedSource.length} 条 (api=$_feedFromApi)');
    print('──────────────────────────────────────────────────────────');

    final results = <MatchPost>[];
    var round = 0;

    for (final post in _feedSource) {
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

      final areaMatch = _postMatchesBrowse(post);
      print('  [分类] "${post.area}" vs 浏览 $_browseSceneId → ${areaMatch ? "✓" : "✗"}');
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
    print('  过滤完成: ${results.length}/${_feedSource.length} 条');
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

  /// 仅在当前浏览筛选内放宽条件，绝不跨场景展示
  List<MatchPost> get _fallbackPosts {
    final tabLabel = _currentTabLabel;
    final isMatchTab = tabLabel == '匹配';

    if (tabLabel == '推荐') {
      final seenIds = <String>{};
      final list = <MatchPost>[];

      for (final post in _feedSource) {
        if (!_postMatchesBrowse(post)) continue;
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

    final list = _feedSource.where((post) {
      if (_shouldExcludeFromRecommendFeed(post)) return false;
      if (!_postMatchesBrowse(post)) return false;
      if (post.tab != tabLabel) return false;
      return _matchesSearch(post);
    }).toList()
      ..sort((a, b) => b.hardcoreScore.compareTo(a.hardcoreScore));
    return list;
  }

  Widget _buildPostCardAuthorRow(MatchPost post) {
    final name =
        post.hostNickname.trim().isEmpty ? '用户' : post.hostNickname.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1) : 'U';
    final followed = _isHostFollowed(post);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleFollowHost(post),
        child: Row(
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: const Color(0xFFE6F0FF),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF002FA7),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            if (followed) ...[
              Icon(
                Icons.check_circle,
                size: 13,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 2),
              Text(
                '已关注',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, MatchPost post, {int? faceMatchScore}) {
    final hasApplied = _appliedPostIds.contains(post.id) || post.hasApplied;
    final isFull = post.isFull;
    final description = post.description.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      child: Opacity(
        opacity: isFull ? 0.72 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              onTap: () => _openPostDetail(post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 120,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECECF7),
                          borderRadius: BorderRadius.vertical(
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isFull
                                ? Colors.black.withValues(alpha: 0.55)
                                : Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isFull
                                ? '${post.currentMembers}/${post.peopleLimit} 满'
                                : '${post.currentMembers}/${post.peopleLimit}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (isFull)
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '已满员',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
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
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isFull
                                    ? Colors.grey.shade300
                                    : const Color(0xFFE6F0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isFull
                                    ? '已满员'
                                    : hasApplied
                                        ? '已申请'
                                        : '组队中',
                                style: TextStyle(
                                  color: isFull
                                      ? const Color(0xFF424242)
                                      : hasApplied
                                          ? Colors.orange.shade800
                                          : const Color(0xFF002FA7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (faceMatchScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F0FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '匹配 $faceMatchScore%',
                                  style: const TextStyle(
                                    color: Color(0xFF002FA7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (post.isPinned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF002FA7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '置顶',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            HashtagChip(
                              tag: SceneCategories.labelFor(post.area),
                              compact: true,
                            ),
                            ...post.hostFaceTraits.take(2).map(
                                  (t) => HashtagChip(tag: t, compact: true),
                                ),
                          ],
                        ),
                        if (post.eventLocation.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatEventBrief(post.eventDateTime),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  post.eventLocation.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildPostCardAuthorRow(post),
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
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        titleSpacing: 16,
        title: _buildAppBarSearch(),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildAuthStatusBanner(),
              Text(
                '嘿，${_userProfile.name}，发现附近的组局搭子',
                style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 0,
                shadowColor: Colors.black26,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openBrowseFilter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list_rounded, color: Color(0xFF002FA7)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '我在看：${SceneCategories.labelFor(_browseSceneId)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_userProfile.isHardcore && _userProfile.area == 'BoardGames')
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
              if (_userProfile.isHardcore && _userProfile.area == 'BoardGames')
                const SizedBox(height: 16),
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
                    setState(() => _invalidateVectorCache());
                    _loadFeedPosts();
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
                            child: _buildMasonryPostGrid(
                              fallback,
                              showMatchScore: _isMatchTab,
                            ),
                          ),
                        ],
                      );
                    }
                    return _buildMasonryPostGrid(
                      posts,
                      showMatchScore: _isMatchTab,
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

  Future<void> _openPostDetail(MatchPost post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          post: post,
          hasApplied: _appliedPostIds.contains(post.id) || post.hasApplied,
          isGuest: !_showsRegisteredUI,
          authSession: _authSession,
          onApply: () {
            if (!mounted) return;
            setState(() => _appliedPostIds.add(post.id));
            widget.onApplicationChanged?.call();
          },
          onRequestLogin: _showLoginBottomSheet,
        ),
      ),
    );
    if (mounted) await _loadFeedPosts();
  }
}

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.hasApplied,
    required this.isGuest,
    required this.onApply,
    this.authSession,
    this.onRequestLogin,
  });

  final MatchPost post;
  final bool hasApplied;
  final bool isGuest;
  final AuthSession? authSession;
  final VoidCallback onApply;
  final Future<void> Function()? onRequestLogin;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool _hasApplied;
  late MatchPost _post;
  List<PostMember> _members = const [];

  MatchPost get post => _post;

  bool get _isHost {
    final hostId = post.hostUserId?.trim();
    final myId = widget.authSession?.userId.trim();
    if (hostId == null || hostId.isEmpty || myId == null || myId.isEmpty) {
      return false;
    }
    return hostId == myId;
  }

  static const Color _primary = Color(0xFF002FA7);
  static const Color _background = Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    _hasApplied = widget.hasApplied;
    _post = widget.post;
    _loadPostDetail();
    _syncAppliedFromApi();
  }

  Future<void> _loadPostDetail() async {
    try {
      final fresh = await postService.fetchPost(_post.id);
      final members = await postService.fetchPostMembers(_post.id);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _post = fresh;
        _members = members;
      });
    } catch (_) {}
  }

  Future<void> _syncAppliedFromApi() async {
    final session = widget.authSession;
    if (session == null || session.isGuest || _hasApplied) return;
    try {
      final applied = await postService.fetchHasApplied(
        session: session,
        postId: post.id,
      );
      if (mounted && applied) {
        setState(() => _hasApplied = true);
      }
    } catch (_) {}
  }

  String _formatEventDate(DateTime dt) =>
      '${dt.year}年${dt.month}月${dt.day}日';

  String _formatEventTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _promptLogin(String title) async {
    final goLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('游客仅可浏览帖子。申请加入、私聊需先登录账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续浏览'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
    if (goLogin == true && widget.onRequestLogin != null) {
      await widget.onRequestLogin!();
    }
  }

  Future<void> _handleApply() async {
    if (_isHost || _hasApplied || post.isFull) return;

    if (widget.isGuest) {
      await _promptLogin('登录后申请加入');
      return;
    }

    final session = widget.authSession;
    if (session == null) {
      await _promptLogin('登录后申请加入');
      return;
    }

    final wechatController = TextEditingController();
    final wechat = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('微信昵称或微信号'),
          content: TextField(
            controller: wechatController,
            decoration: const InputDecoration(
              hintText: '必填，方便主理人对账',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(wechatController.text.trim()),
              child: const Text('提交申请'),
            ),
          ],
        );
      },
    );
    wechatController.dispose();
    if (wechat == null || wechat.isEmpty) {
      if (mounted && wechat != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请填写微信昵称或微信号')),
        );
      }
      return;
    }

    try {
      await postService.applyToPost(
        session: session,
        postId: post.id,
        wechatContact: wechat,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.action == 'bind_phone') {
        await _promptLogin('登录后申请加入');
        return;
      }
      final msg = e.message.contains('own post') ||
              e.message.contains('不能申请自己')
          ? '不能申请自己发布的组局'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('申请失败：$e')),
      );
      return;
    }

    setState(() => _hasApplied = true);
    widget.onApply();
    await _loadPostDetail();

    if (!mounted) return;
    await showDialog<void>(
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

  Future<void> _onPrivateChat() async {
    if (widget.isGuest) {
      await _promptLogin('登录后私聊');
      return;
    }

    if (!mounted) return;
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
                  if (_isHost)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                      ),
                      child: const Text(
                        '这是你发布的组局。可在底部「消息 → 申请」查看他人报名（功能完善中）。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  if (widget.isGuest)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: const Text(
                        '当前为游客，仅可浏览。申请加入、私聊需先登录账号。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  _buildPublisherCard(),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HashtagChip(
                        tag: SceneCategories.labelFor(post.area),
                        compact: true,
                      ),
                      ...post.hostFaceTraits.map(
                        (t) => HashtagChip(tag: t, compact: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildEventInfoCard(),
                  const SizedBox(height: 16),
                  _buildTeamSection(progress),
                ],
              ),
            ),
          ),
          _buildActionBar(),
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
                      .map((tag) => HashtagChip(tag: tag, compact: true))
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
    final memberList = _members.isNotEmpty
        ? _members.take(8).toList()
        : <PostMember>[];
    final displayCount = memberList.isNotEmpty
        ? memberList.length
        : post.currentMembers.clamp(0, 8);
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
                            memberList.isNotEmpty
                                ? memberList[i].initial
                                : '${i + 1}',
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
            if (memberList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: memberList.map((m) {
                  return Text(
                    m.isHost ? '${m.displayName}（主理人）' : m.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  );
                }).toList(),
              ),
            ],
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

  Widget _buildActionBar() {
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
              onPressed: _onPrivateChat,
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
              onPressed: _isHost || post.isFull || _hasApplied
                  ? null
                  : _handleApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isHost || post.isFull || _hasApplied
                    ? Colors.grey.shade400
                    : _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                _isHost
                    ? '我是主理人'
                    : post.isFull
                        ? '已满员'
                        : _hasApplied
                            ? '已申请'
                            : '申请加入',
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
