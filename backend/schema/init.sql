-- Docker 首次启动时自动执行（pgvector/pgvector 镜像）
CREATE EXTENSION IF NOT EXISTS vector;

-- 捏脸标签词表（与 lib/services/face_vector_encoder.dart 一致，18 维）
CREATE TABLE IF NOT EXISTS face_trait_vocabulary (
    id              SERIAL PRIMARY KEY,
    tag             TEXT NOT NULL UNIQUE,
    dimension_index INT  NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO face_trait_vocabulary (tag, dimension_index) VALUES
    ('策略思维', 0), ('桌游爱好者', 1), ('逻辑型', 2),
    ('美食探索', 3), ('社交型', 4), ('慢节奏', 5),
    ('运动达人', 6), ('活力型', 7), ('竞争意识', 8),
    ('开放', 9), ('随和', 10),
    ('休闲派', 11), ('平衡型', 12), ('认真派', 13),
    ('硬核派', 14), ('团队配合', 15), ('拍照打卡', 16), ('早起党', 17)
ON CONFLICT (tag) DO NOTHING;

CREATE TABLE IF NOT EXISTS match_posts (
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
    match_score         DOUBLE PRECISION NOT NULL DEFAULT 0,
    host_nickname       TEXT NOT NULL,
    host_credit_score   SMALLINT NOT NULL DEFAULT 80,
    host_face_traits    TEXT[] NOT NULL DEFAULT '{}',
    host_face_vector    vector(18) NOT NULL,
    event_date_time     TIMESTAMPTZ,
    event_location      TEXT,
    is_pinned           BOOLEAN NOT NULL DEFAULT false,
    pin_priority        INT NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_posts_area ON match_posts (area) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_match_posts_host_vector_hnsw
    ON match_posts USING hnsw (host_face_vector vector_cosine_ops);

CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    openid      TEXT NOT NULL UNIQUE,
    phone       TEXT UNIQUE,
    is_guest    BOOLEAN NOT NULL DEFAULT true,
    nickname    TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users (phone) WHERE phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_is_guest ON users (is_guest);
