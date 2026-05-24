import 'face_vector_encoder.dart';
import 'redis_match_cache.dart';

/// 向量检索请求参数（对应 similar_posts.sql 的过滤条件）
class VectorMatchQuery {
  const VectorMatchQuery({
    required this.userId,
    required this.userTraits,
    required this.area,
    required this.scoreTier,
    required this.tab,
    this.blockedPostIds = const {},
    this.readPostIds = const {},
    this.searchText = '',
    this.vectorVersion = 1,
    this.limit = 50,
  });

  final String userId;
  final List<String> userTraits;
  final String area;
  final int scoreTier;
  final String tab;
  final Set<String> blockedPostIds;
  final Set<String> readPostIds;
  final String searchText;
  final int vectorVersion;
  final int limit;

  (int min, int max) get scoreRange => switch (scoreTier) {
        0 => (0, 25),
        25 => (25, 50),
        50 => (50, 75),
        75 => (75, 90),
        100 => (90, 101),
        _ => (0, 101),
      };
}

/// 带相似度分数的检索结果
class VectorMatchResult {
  const VectorMatchResult({
    required this.postId,
    required this.matchScore,
    required this.cosineSimilarity,
  });

  final String postId;
  final double matchScore;
  final double cosineSimilarity;
}

/// pgvector 查询模板（部署到后端 API / Edge Function 执行）
abstract final class PgVectorMatchQueries {
  static const similarPosts = '''
-- 见 backend/queries/similar_posts.sql
SELECT p.id, face_similarity_percent(p.host_face_vector, \$1::vector) AS match_score
FROM match_posts p
WHERE p.area = \$2 AND p.hardcore_score >= \$3 AND p.hardcore_score < \$4
ORDER BY p.host_face_vector <=> \$1::vector
LIMIT \$8;
''';

  static String userVectorUpsert = '''
INSERT INTO user_face_profiles (user_id, area, intensity_score, face_traits, face_vector, vector_version)
VALUES (\$1, \$2, \$3, \$4, \$5::vector, \$6)
ON CONFLICT (user_id) DO UPDATE SET
  area = EXCLUDED.area,
  intensity_score = EXCLUDED.intensity_score,
  face_traits = EXCLUDED.face_traits,
  face_vector = EXCLUDED.face_vector,
  vector_version = EXCLUDED.vector_version,
  updated_at = now();
''';
}

/// 向量匹配服务：Redis 缓存 + 批量向量相似度（替代 for 循环 Jaccard）
class VectorMatchService {
  VectorMatchService({
    FaceVectorEncoder? encoder,
    MatchResultCache? cache,
  })  : _encoder = encoder ?? FaceVectorEncoder(),
        _cache = cache ?? InMemoryMatchResultCache();

  final FaceVectorEncoder _encoder;
  final MatchResultCache _cache;

  /// 帖子 id → 预编码向量（写入 DB 前在客户端/服务端构建一次）
  final Map<String, List<double>> _postVectorIndex = {};

  /// 注册帖子向量（mock 启动时或 API 分页加载时调用）
  void indexPost({required String postId, required List<String> hostFaceTraits}) {
    _postVectorIndex[postId] = _encoder.encode(hostFaceTraits);
  }

  void indexPosts(Iterable<({String id, List<String> traits})> posts) {
    for (final p in posts) {
      indexPost(postId: p.id, hostFaceTraits: p.traits);
    }
  }

  /// 核心检索：先查 Redis，未命中则批量向量相似度计算
  List<VectorMatchResult> findSimilar({
    required VectorMatchQuery query,
    required bool Function(String postId) postExists,
    required bool Function(String postId) passesFilters,
  }) {
    final cacheKey = InMemoryMatchResultCache.buildKey(
      userId: query.userId,
      area: query.area,
      tab: query.tab,
      scoreTier: query.scoreTier,
      vectorVersion: query.vectorVersion,
      search: query.searchText,
    );

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      print('[VectorMatchService] Redis 缓存命中: $cacheKey');
      return cached.postIds
          .where(passesFilters)
          .map(
            (id) => VectorMatchResult(
              postId: id,
              matchScore: cached.scores[id] ?? 0,
              cosineSimilarity: _percentToCosine(cached.scores[id] ?? 0),
            ),
          )
          .toList();
    }

    print('[VectorMatchService] 缓存未命中，执行向量 batch 检索');
    final results = _batchVectorSearch(query: query, passesFilters: passesFilters);

    _cache.set(
      cacheKey,
      MatchCachePayload(
        computedAt: DateTime.now(),
        postIds: results.map((r) => r.postId).toList(),
        scores: {for (final r in results) r.postId: r.matchScore},
      ),
      ttl: query.tab == '匹配'
          ? const Duration(minutes: 10)
          : const Duration(minutes: 5),
    );

    return results;
  }

  /// 批量向量相似度：一次编码用户向量 + 矩阵点积，无逐帖 Jaccard 字符串比较
  List<VectorMatchResult> _batchVectorSearch({
    required VectorMatchQuery query,
    required bool Function(String postId) passesFilters,
  }) {
    final userVector = _encoder.encode(query.userTraits);
    final scored = <VectorMatchResult>[];

    _postVectorIndex.forEach((postId, postVector) {
      if (!passesFilters(postId)) return;

      final cosine = FaceVectorEncoder.cosineSimilarity(userVector, postVector);
      final matchPercent = FaceVectorEncoder.toMatchPercent(cosine);

      scored.add(
        VectorMatchResult(
          postId: postId,
          matchScore: matchPercent,
          cosineSimilarity: cosine,
        ),
      );
    });

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    print('[VectorMatchService] batch 完成: ${scored.length} 条');
    for (final r in scored.take(5)) {
      print('  · ${r.postId} matchScore=${r.matchScore.toStringAsFixed(1)}');
    }

    return scored.take(query.limit).toList();
  }

  /// 生成供 PostgreSQL 执行的向量字面量（API 层调用）
  String buildPgVectorParam(List<String> userTraits) =>
      _encoder.toPgVectorLiteral(_encoder.encode(userTraits));

  static double _percentToCosine(double percent) => (percent / 50) - 1;

  void invalidateUserCache(String userId) {
    _cache.invalidateByPrefix('match:feed:$userId:');
  }
}
