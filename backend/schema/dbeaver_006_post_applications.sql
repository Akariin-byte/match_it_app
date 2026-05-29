-- DBeaver: 在 matchit 库执行
CREATE TABLE IF NOT EXISTS post_applications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     TEXT NOT NULL REFERENCES match_posts (id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    message     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_applications_user
    ON post_applications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_post_applications_post
    ON post_applications (post_id, status);
