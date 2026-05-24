-- 用户表：小红书式「先体验、后绑定」
-- 已有数据库请手动执行: docker exec -i matchit-postgres psql -U matchit -d matchit < schema/002_users.sql

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
