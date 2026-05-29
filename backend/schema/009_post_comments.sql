-- 组局评论与通知
CREATE TABLE IF NOT EXISTS post_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     TEXT NOT NULL REFERENCES match_posts (id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    parent_id   UUID REFERENCES post_comments (id) ON DELETE CASCADE,
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post
    ON post_comments (post_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_post_comments_parent
    ON post_comments (parent_id)
    WHERE parent_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS comment_notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_id     TEXT NOT NULL REFERENCES match_posts (id) ON DELETE CASCADE,
    comment_id  UUID NOT NULL REFERENCES post_comments (id) ON DELETE CASCADE,
    kind        TEXT NOT NULL CHECK (kind IN ('post_comment', 'comment_reply')),
    is_read     BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comment_notifications_user
    ON comment_notifications (user_id, is_read, created_at DESC);
