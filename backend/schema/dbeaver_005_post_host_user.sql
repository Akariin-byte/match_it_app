-- DBeaver：粘贴执行（勿用 \i）
ALTER TABLE match_posts
    ADD COLUMN IF NOT EXISTS host_user_id UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_match_posts_host_user
    ON match_posts (host_user_id)
    WHERE is_active = true AND host_user_id IS NOT NULL;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'match_posts' AND column_name = 'host_user_id';
