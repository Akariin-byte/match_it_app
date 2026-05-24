class MatchPost {
  MatchPost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.competitiveness,
    required this.currentMembers,
    required this.maxMembers,
    this.hasApplied = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int competitiveness;
  final int currentMembers;
  final int maxMembers;
  bool hasApplied;

  bool get isFull => currentMembers >= maxMembers;

  MatchPost copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? competitiveness,
    int? currentMembers,
    int? maxMembers,
    bool? hasApplied,
  }) {
    return MatchPost(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      competitiveness: competitiveness ?? this.competitiveness,
      currentMembers: currentMembers ?? this.currentMembers,
      maxMembers: maxMembers ?? this.maxMembers,
      hasApplied: hasApplied ?? this.hasApplied,
    );
  }
}

final List<MatchPost> mockMatchPosts = [
  MatchPost(
    id: 'post1',
    title: '周六下午寻找《阿瓦隆》大神局',
    description: '想约一组 5 人局，必须是硬核老手。',
    category: 'BoardGames',
    competitiveness: 95, // 对应【大神 100分】档位
    currentMembers: 3,
    maxMembers: 5,
  ),
  MatchPost(
    id: 'post2',
    title: '周日早晨街头篮球 3v3',
    description: '附近友邻一起玩，装备齐全，轻松娱乐。',
    category: 'Sports',
    competitiveness: 30, // 对应【普通 25分】档位
    currentMembers: 5,
    maxMembers: 5,
  ),
  MatchPost(
    id: 'post3',
    title: '周五晚桌游《卡坦》进阶局',
    description: '熟悉规则，氛围轻松。',
    category: 'BoardGames',
    competitiveness: 55, // 对应【进阶 50分】档位
    currentMembers: 2,
    maxMembers: 4,
  ),
  MatchPost(
    id: 'post4',
    title: '周末美食探店（休闲拼餐）',
    description: '想找 4 人拼餐。',
    category: 'Food',
    competitiveness: 10, // 对应【新手 0分】档位，防止乱入大神局
    currentMembers: 3,
    maxMembers: 4,
  ),
  MatchPost(
    id: 'post5',
    title: '周六夜《电音派对》',
    description: '需要 5 人一起拼车入场。',
    category: 'Sports', // 修复拼写：Sport -> Sports
    competitiveness: 95, 
    currentMembers: 4,
    maxMembers: 5,
  ),
];
