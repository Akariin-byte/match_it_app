-- MATCHit · pgvector 捏脸特征向量 Schema
-- 依赖: PostgreSQL 15+ , pgvector 0.5+

CREATE EXTENSION IF NOT EXISTS vector;

-- ─────────────────────────────────────────────
-- 1. 特征词表：定义向量每一维对应的标签
-- ─────────────────────────────────────────────
CREATE TABLE face_trait_vocabulary (
    id              SERIAL PRIMARY KEY,
    tag             TEXT NOT NULL UNIQUE,
    dimension_index INT  NOT NULL UNIQUE,          -- 在 face_vector 中的下标 (0-based)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE face_trait_vocabulary IS '捏脸标签词表；向量维度数 = COUNT(*)';

-- ─────────────────────────────────────────────
-- 2. 用户捏脸档案（向量在写入时由应用层编码后 UPSERT）
-- ─────────────────────────────────────────────
CREATE TABLE user_face_profiles (
    user_id         UUID PRIMARY KEY,
    area            TEXT NOT NULL,
    intensity_score SMALLINT NOT NULL DEFAULT 50,
    face_traits     TEXT[] NOT NULL DEFAULT '{}',
    face_vector     vector(128) NOT NULL,          -- 维度需与词表一致，部署时 ALTER 或迁移
    vector_version  INT NOT NULL DEFAULT 1,          -- 词表/编码算法变更时递增，用于 Redis 失效
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_face_profiles_area ON user_face_profiles (area);

-- ─────────────────────────────────────────────
-- 3. 活动帖子（发帖人捏脸向量冗余存储，避免 JOIN 实时编码）
-- ─────────────────────────────────────────────
CREATE TABLE match_posts (
    id                  TEXT PRIMARY KEY,
    title               TEXT NOT NULL,
    description         TEXT NOT NULL,
    area                TEXT NOT NULL,
    tab                 TEXT NOT NULL DEFAULT '推荐',
    hardcore_score      SMALLINT NOT NULL,
    current_members     INT NOT NULL DEFAULT 0,
    max_members         INT NOT NULL DEFAULT 4,
    interaction_count   INT NOT NULL DEFAULT 0,
    last_active_time    TIMESTAMPTZ NOT NULL DEFAULT now(),
    host_nickname       TEXT NOT NULL,
    host_credit_score   SMALLINT NOT NULL DEFAULT 80,
    host_face_traits    TEXT[] NOT NULL DEFAULT '{}',
    host_face_vector    vector(128) NOT NULL,
    event_date_time     TIMESTAMPTZ,
    event_location      TEXT,
    is_pinned           BOOLEAN NOT NULL DEFAULT false,
    pin_priority        INT NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 分类 + 向量 ANN 索引（HNSW 适合高 QPS 近似最近邻）
CREATE INDEX idx_match_posts_area ON match_posts (area) WHERE is_active = true;
CREATE INDEX idx_match_posts_host_vector_hnsw
    ON match_posts USING hnsw (host_face_vector vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 可选：按 hardcore_score 范围过滤的复合索引
CREATE INDEX idx_match_posts_area_score
    ON match_posts (area, hardcore_score)
    WHERE is_active = true;

-- ─────────────────────────────────────────────
-- 4. 用户屏蔽 / 已读（过滤接口）
-- ─────────────────────────────────────────────
CREATE TABLE user_post_filters (
    user_id     UUID NOT NULL,
    post_id     TEXT NOT NULL,
    filter_type TEXT NOT NULL CHECK (filter_type IN ('blocked', 'read')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, post_id, filter_type)
);

CREATE INDEX idx_user_post_filters_user ON user_post_filters (user_id, filter_type);

-- ─────────────────────────────────────────────
-- 5. 辅助函数：余弦相似度 → 0–100 分（与客户端 display 对齐）
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION face_similarity_percent(a vector, b vector)
RETURNS DOUBLE PRECISION
LANGUAGE SQL IMMUTABLE PARALLEL SAFE AS $$
    SELECT GREATEST(0, LEAST(100, (1 - (a <=> b)) * 100));
$$;

COMMENT ON FUNCTION face_similarity_percent IS '<=> 为 pgvector 余弦距离；1-distance = 余弦相似度';
