-- 向量相似度检索：替代应用层 for 循环逐帖 Jaccard 对比
--
-- 参数:
--   $1  user_face_vector   vector(128)  当前用户捏脸向量
--   $2  area               TEXT         用户选择的分类
--   $3  score_min          SMALLINT     档位下限 (含)
--   $4  score_max          SMALLINT     档位上限 (不含)
--   $5  blocked_post_ids   TEXT[]       屏蔽列表
--   $6  read_post_ids      TEXT[]       已读列表 (可选过滤)
--   $7  search_keyword     TEXT         搜索词 (空字符串表示不过滤)
--   $8  result_limit       INT          返回条数上限

SELECT
    p.id,
    p.title,
    p.description,
    p.area,
    p.tab,
    p.hardcore_score,
    p.current_members,
    p.max_members,
    p.interaction_count,
    p.last_active_time,
    p.host_nickname,
    p.host_credit_score,
    p.host_face_traits,
    p.event_date_time,
    p.event_location,
    p.is_pinned,
    p.pin_priority,
  face_similarity_percent(p.host_face_vector, $1::vector) AS match_score,
    (p.host_face_vector <=> $1::vector)                     AS cosine_distance
FROM match_posts p
WHERE p.is_active = true
  AND p.area = $2
  AND p.hardcore_score >= $3
  AND p.hardcore_score <  $4
  AND NOT (p.id = ANY($5::text[]))
  AND NOT (p.id = ANY($6::text[]))
  AND (
        $7 = ''
        OR p.title       ILIKE '%' || $7 || '%'
        OR p.description ILIKE '%' || $7 || '%'
      )
ORDER BY
    p.is_pinned DESC,
    p.pin_priority DESC,
    p.host_face_vector <=> $1::vector ASC    -- 距离越小越相似
LIMIT $8;

-- ── 仅「匹配」Tab：纯向量 Top-K（可配合 SET hnsw.ef_search = 40）──
-- SELECT ... ORDER BY host_face_vector <=> $1 LIMIT 50;
