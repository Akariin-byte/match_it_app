-- GORM 用户表结构（device_id 唯一游客身份）
-- 已有库执行: Get-Content backend\schema\003_users_gorm.sql | docker exec -i matchit-postgres psql -U matchit -d matchit

DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id   VARCHAR(128) NOT NULL UNIQUE,
    openid      TEXT UNIQUE,
    is_guest    BOOLEAN NOT NULL DEFAULT true,
    username    VARCHAR(64) NOT NULL DEFAULT '',
    phone       TEXT UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_device_id ON users (device_id);
CREATE INDEX idx_users_is_guest ON users (is_guest);
