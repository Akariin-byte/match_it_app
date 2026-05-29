import 'dart:math' as math;

/// 将 # 标签编码为 L2 归一化向量，供 pgvector / 本地批量余弦相似度使用。
///
/// 编码策略：multi-hot + L2 归一化
///   - 每个标签对应词表中的一个维度，命中则为 1
///   - 除以 L2 模长后，余弦相似度可直接用点积计算
class FaceVectorEncoder {
  FaceVectorEncoder({List<String>? vocabulary})
      : _vocabulary = List.unmodifiable(vocabulary ?? defaultVocabulary),
        _tagToIndex = {
          for (var i = 0; i < (vocabulary ?? defaultVocabulary).length; i++)
            (vocabulary ?? defaultVocabulary)[i]: i,
        };

  final List<String> _vocabulary;
  final Map<String, int> _tagToIndex;

  int get dimension => _vocabulary.length;

  static const defaultVocabulary = [
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
    '桌游',
    '组局',
    '剧本杀',
    '阿瓦隆',
    '卡坦',
    '狼人杀',
    '探店',
    '美食',
    '拼餐',
    '火锅',
    '咖啡',
    '运动',
    '篮球',
    '羽毛球',
    '跑步',
    '漫展',
    '二次元',
    'cos',
    '约拍',
    '摄影',
    '出片',
    '旅行',
    '开黑',
    '游戏',
    '宠物',
    'live',
    '户外',
    '露营',
    '自驾',
    '官方活动',
    '进阶',
    '3v3',
  ];

  List<double> encode(Iterable<String> traits) {
    final vec = List<double>.filled(dimension, 0);
    var hit = 0;
    for (final tag in traits) {
      final idx = _tagToIndex[tag.trim()];
      if (idx != null) {
        vec[idx] = 1;
        hit++;
      }
    }
    if (hit == 0) return vec;
    return _l2Normalize(vec);
  }

  String toPgVectorLiteral(List<double> vector) {
    final body = vector.map((v) => v.toStringAsFixed(6)).join(',');
    return '[$body]';
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length);
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  /// 与 PostgreSQL face_similarity_percent() 对齐：0–100
  static double toMatchPercent(double cosineSim) =>
      ((cosineSim + 1) / 2 * 100).clamp(0, 100);

  static List<double> _l2Normalize(List<double> vec) {
    var sum = 0.0;
    for (final x in vec) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return vec;
    return vec.map((v) => v / norm).toList();
  }
}
