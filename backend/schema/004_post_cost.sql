-- 活动帖费用规则：free | aa | fixed | negotiate
ALTER TABLE match_posts ADD COLUMN IF NOT EXISTS cost_type TEXT;
ALTER TABLE match_posts ADD COLUMN IF NOT EXISTS amount DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS idx_match_posts_cost_type
    ON match_posts (cost_type) WHERE is_active = true AND cost_type IS NOT NULL;
