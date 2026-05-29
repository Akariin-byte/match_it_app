-- 帖子关联发布者账号（host_nickname 仍为展示快照）
ALTER TABLE match_posts
    ADD COLUMN IF NOT EXISTS host_user_id UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_match_posts_host_user
    ON match_posts (host_user_id)
    WHERE is_active = true AND host_user_id IS NOT NULL;
