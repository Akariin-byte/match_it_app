/// 用户 # 个性标签：存储不带 `#`，展示时加前缀（与小红书 / X 一致）
class UserHashtags {
  UserHashtags._();

  static const int maxSelected = 8;

  /// 规范化：去 `#`、首尾空格，合并连续空白
  static String normalize(String raw) {
    var s = raw.trim();
    while (s.startsWith('#')) {
      s = s.substring(1).trim();
    }
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String format(String tag) {
    final n = normalize(tag);
    return n.isEmpty ? '' : '#$n';
  }

  static List<String> normalizeAll(Iterable<String> tags) {
    final out = <String>[];
    for (final t in tags) {
      final n = normalize(t);
      if (n.isEmpty) continue;
      if (!out.contains(n)) out.add(n);
    }
    return out;
  }

  /// 从正文解析 `#标签`（与小红书 / X 一致）
  static List<String> parseFromText(String text) {
    final matches = RegExp(r'#[^\s#]+').allMatches(text);
    return normalizeAll(matches.map((m) => m.group(0)!));
  }

  /// 按场景 + 强度给出默认 # 标签（新用户 / 未定制时）
  static List<String> defaultsFor(String sceneId, int intensityScore) {
    final base = switch (sceneId) {
      'BoardGames' => ['桌游', '组局', '周末局'],
      'Food' => ['探店', '美食', '拼餐'],
      'Sport' => ['运动', '健身', '出汗'],
      'AnimeCon' => ['漫展', '二次元', 'cos'],
      'Photo' => ['约拍', '摄影', '出片'],
      'Travel' => ['旅行', '出行', '打卡'],
      'Study' => ['自习', '学习搭子', '安静'],
      'Game' => ['开黑', '游戏', '联机'],
      'Pet' => ['宠物', '遛狗', '治愈'],
      'Music' => ['live', '音乐', '现场'],
      'Outdoor' => ['户外', '露营', '徒步'],
      'Drive' => ['自驾', '拼车', '路线'],
      _ => ['组局', '搭子'],
    };
    final vibe = switch (intensityScore) {
      0 || 25 => '新手友好',
      50 => '氛围轻松',
      75 => '认真局',
      100 => '硬核局',
      _ => '氛围轻松',
    };
    return normalizeAll([...base, vibe]);
  }

  /// 个性化页推荐词（可点选，也可自填）
  static List<String> suggestedFor(String sceneId) {
    const common = [
      '搭子',
      '同城',
      '周末局',
      '新手友好',
      '氛围轻松',
      '认真局',
      '硬核局',
      'i人友好',
      'e人局',
      'AA制',
    ];
    final scene = switch (sceneId) {
      'BoardGames' => ['桌游', '剧本杀', '阿瓦隆', '卡坦', '狼人杀'],
      'Food' => ['探店', '火锅', '咖啡', 'brunch', '夜宵'],
      'Sport' => ['篮球', '羽毛球', '跑步', '飞盘', '撸铁'],
      'AnimeCon' => ['漫展', 'cos', '谷子', '同人'],
      'Photo' => ['约拍', '互免', '人像', '街拍'],
      'Travel' => ['短途', '周边游', 'Citywalk'],
      'Study' => ['图书馆', '考研', '考证'],
      'Game' => ['王者', 'Steam', '主机'],
      'Pet' => ['猫奴', '遛狗', '异宠'],
      'Music' => ['livehouse', '音乐节', '乐队'],
      'Outdoor' => ['露营', '徒步', '骑行'],
      'Drive' => ['自驾', '顺风车', '周边'],
      _ => <String>[],
    };
    return normalizeAll([...scene, ...common]);
  }
}
