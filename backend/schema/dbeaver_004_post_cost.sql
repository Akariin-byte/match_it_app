-- ============================================================
-- 在 DBeaver 中使用：打开 SQL 编辑器，全选粘贴，执行（Ctrl+Enter）
-- 不要用 \i，那是 psql 命令行专用语法
-- ============================================================

-- 1) 若尚未创建 match_posts，先执行下面整段（无 pgvector 时用 float8[] 替代向量列）
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
    host_face_vector    DOUBLE PRECISION[] NOT NULL DEFAULT '{}',
    event_date_time     TIMESTAMPTZ,
    event_location      TEXT,
    cost_type           TEXT,
    amount              DOUBLE PRECISION,
    is_pinned           BOOLEAN NOT NULL DEFAULT false,
    pin_priority        INT NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_posts_area
    ON match_posts (area) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_match_posts_cost_type
    ON match_posts (cost_type) WHERE is_active = true AND cost_type IS NOT NULL;

-- 2) 若 match_posts 已存在（例如 Docker/pgvector 环境），只需加费用字段：
ALTER TABLE match_posts ADD COLUMN IF NOT EXISTS cost_type TEXT;
ALTER TABLE match_posts ADD COLUMN IF NOT EXISTS amount DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS idx_match_posts_cost_type
    ON match_posts (cost_type) WHERE is_active = true AND cost_type IS NOT NULL;

-- 3) 验证
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'match_posts'
  AND column_name IN ('cost_type', 'amount', 'host_face_vector')
ORDER BY column_name;
