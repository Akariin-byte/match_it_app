/// Redis 匹配结果缓存层
///
/// ## Key 设计
/// ```
/// match:feed:{userId}:{area}:{tab}:{scoreTier}:v{vectorVersion}
/// ```
/// - userId: 用户 UUID
/// - area: BoardGames / Food / Sport
/// - tab: 推荐 | 匹配 | 附近 | 桌游
/// - scoreTier: 0 | 25 | 50 | 75 | 100
/// - vectorVersion: 与 user_face_profiles.vector_version 同步；词表变更时 +1 全量失效
///
/// ## Value 结构 (JSON)
/// ```json
/// {
///   "computedAt": "2026-05-24T10:00:00Z",
///   "postIds": ["board_1", "board_2"],
///   "scores": {"board_1": 87.5, "board_2": 72.1}
/// }
/// ```
///
/// ## TTL 建议
/// | 场景 | TTL | 说明 |
/// |------|-----|------|
/// | 匹配 Tab | 5–10 min | 向量分相对稳定 |
/// | 推荐 Tab | 3–5 min | 含互动/活跃，变化更快 |
/// | 用户改捏脸 | 立即 DEL | 监听 profile.updated 事件 |
/// | 新帖发布 | 按 area 批量 DEL | `SCAN match:feed:*:{area}:*` |
///
/// ## 部署示例 (redis-cli)
/// ```bash
/// SET match:feed:uuid:BoardGames:匹配:50:v1 '{"postIds":[...],"scores":{...}}' EX 600
/// ```
///
/// ## 后端伪代码
/// ```python
/// key = f"match:feed:{user_id}:{area}:{tab}:{tier}:v{version}"
/// cached = redis.get(key)
/// if cached:
///     return hydrate_posts(json.loads(cached))
/// rows = db.execute(SIMILAR_POSTS_SQL, user_vector, ...)
/// payload = serialize(rows)
/// redis.setex(key, 600, payload)
/// return rows
/// ```
library;

import 'dart:convert';

/// 缓存条目
class MatchCachePayload {
  const MatchCachePayload({
    required this.computedAt,
    required this.postIds,
    required this.scores,
  });

  final DateTime computedAt;
  final List<String> postIds;
  final Map<String, double> scores;

  Map<String, dynamic> toJson() => {
        'computedAt': computedAt.toUtc().toIso8601String(),
        'postIds': postIds,
        'scores': scores,
      };

  factory MatchCachePayload.fromJson(Map<String, dynamic> json) {
    return MatchCachePayload(
      computedAt: DateTime.parse(json['computedAt'] as String),
      postIds: List<String>.from(json['postIds'] as List),
      scores: (json['scores'] as Map).map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ),
    );
  }
}

abstract class MatchResultCache {
  MatchCachePayload? get(String key);
  void set(String key, MatchCachePayload payload, {Duration ttl});
  void invalidate(String key);
  void invalidateByPrefix(String prefix);
}

/// 开发 / 单测用内存实现；生产环境替换为 Redis 客户端 (ioredis / go-redis / redis-py)
class InMemoryMatchResultCache implements MatchResultCache {
  final Map<String, _CacheEntry> _store = {};

  static String buildKey({
    required String userId,
    required String area,
    required String tab,
    required int scoreTier,
    required int vectorVersion,
    String search = '',
  }) =>
      'match:feed:$userId:$area:$tab:$scoreTier:v$vectorVersion'
      '${search.isEmpty ? '' : ':q${search.hashCode}' }';

  @override
  MatchCachePayload? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _store.remove(key);
      return null;
    }
    return entry.payload;
  }

  @override
  void set(String key, MatchCachePayload payload, {Duration ttl = const Duration(minutes: 10)}) {
    _store[key] = _CacheEntry(
      payload: payload,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  @override
  void invalidate(String key) => _store.remove(key);

  @override
  void invalidateByPrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// 调试：序列化为 Redis SET 命令可读的 JSON
  String exportJson(String key) {
    final p = get(key);
    return p == null ? '{}' : jsonEncode(p.toJson());
  }
}

class _CacheEntry {
  _CacheEntry({required this.payload, required this.expiresAt});
  final MatchCachePayload payload;
  final DateTime expiresAt;
}
