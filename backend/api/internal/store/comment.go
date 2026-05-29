package store

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"matchit/backend/api/internal/model"

	"github.com/jackc/pgx/v5"
)

var (
	ErrCommentNotFound = errors.New("comment not found")
	ErrCommentInvalid  = errors.New("invalid comment")
)

func (p *Postgres) ensureCommentSchema(ctx context.Context) error {
	_, err := p.pool.Exec(ctx, `
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
`)
	return err
}

const listPostCommentsSQL = `
SELECT
    c.id::text,
    c.post_id,
    COALESCE(c.parent_id::text, ''),
    c.body,
    c.user_id::text,
    COALESCE(u.username, '用户'),
    c.created_at,
    COALESCE(p.host_user_id::text, ''),
    CASE
        WHEN c.user_id = p.host_user_id THEN 'host'
        WHEN EXISTS (
            SELECT 1 FROM post_applications a
            WHERE a.post_id = c.post_id AND a.user_id = c.user_id AND a.status = 'approved'
        ) THEN 'member'
        WHEN EXISTS (
            SELECT 1 FROM post_applications a
            WHERE a.post_id = c.post_id AND a.user_id = c.user_id
              AND a.status IN ('pending', 'approved')
        ) THEN 'applicant'
        ELSE ''
    END AS role_badge,
    COALESCE(parent_u.username, '')
FROM post_comments c
JOIN match_posts p ON p.id = c.post_id
JOIN users u ON u.id = c.user_id
LEFT JOIN post_comments parent_c ON parent_c.id = c.parent_id
LEFT JOIN users parent_u ON parent_u.id = parent_c.user_id
WHERE c.post_id = $1
ORDER BY c.created_at ASC
`

func (p *Postgres) ListPostComments(ctx context.Context, postID string) ([]model.PostComment, error) {
	rows, err := p.pool.Query(ctx, listPostCommentsSQL, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.PostComment
	for rows.Next() {
		var c model.PostComment
		var parentID, hostUserID, roleBadge, replyTo string
		if err := rows.Scan(
			&c.ID,
			&c.PostID,
			&parentID,
			&c.Body,
			&c.AuthorUserID,
			&c.AuthorUsername,
			&c.CreatedAt,
			&hostUserID,
			&roleBadge,
			&replyTo,
		); err != nil {
			return nil, err
		}
		if parentID != "" {
			c.ParentID = parentID
		}
		c.RoleBadge = roleBadgeLabel(roleBadge)
		if replyTo != "" {
			c.ReplyToUsername = replyTo
		}
		out = append(out, c)
	}
	if out == nil {
		out = []model.PostComment{}
	}
	return out, rows.Err()
}

func roleBadgeLabel(code string) string {
	switch code {
	case "host":
		return "主理"
	case "member":
		return "已加入"
	case "applicant":
		return "已申请"
	default:
		return ""
	}
}

type insertCommentResult struct {
	CommentID       string
	PostHostUserID  string
	PostTitle       string
	ParentAuthorID  string
	ParentAuthorName string
}

const insertCommentSQL = `
WITH parent AS (
    SELECT c.id, c.user_id, u.username
    FROM post_comments c
    JOIN users u ON u.id = c.user_id
    WHERE c.id = $3::uuid AND c.post_id = $1
),
ins AS (
    INSERT INTO post_comments (post_id, user_id, parent_id, body)
    VALUES (
        $1,
        $2::uuid,
        NULLIF($3, '')::uuid,
        $4
    )
    RETURNING id, post_id, user_id, parent_id, body, created_at
)
SELECT
    ins.id::text,
    COALESCE(p.host_user_id::text, ''),
    p.title,
    COALESCE(parent.user_id::text, ''),
    COALESCE(parent.username, '')
FROM ins
JOIN match_posts p ON p.id = ins.post_id
LEFT JOIN parent ON ins.parent_id = parent.id
`

func (p *Postgres) InsertPostComment(
	ctx context.Context,
	postID, userID, parentID, body string,
) (model.PostComment, insertCommentResult, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		return model.PostComment{}, insertCommentResult{}, ErrCommentInvalid
	}
	if len([]rune(body)) > 500 {
		return model.PostComment{}, insertCommentResult{}, fmt.Errorf("%w: too long", ErrCommentInvalid)
	}

	parentID = strings.TrimSpace(parentID)
	if parentID != "" {
		var exists bool
		if err := p.pool.QueryRow(ctx, `
SELECT EXISTS(
    SELECT 1 FROM post_comments WHERE id = $1::uuid AND post_id = $2
)`, parentID, postID).Scan(&exists); err != nil || !exists {
			return model.PostComment{}, insertCommentResult{}, ErrCommentInvalid
		}
	}

	var res insertCommentResult
	var commentID string
	err := p.pool.QueryRow(ctx, insertCommentSQL, postID, userID, parentID, body).Scan(
		&commentID,
		&res.PostHostUserID,
		&res.PostTitle,
		&res.ParentAuthorID,
		&res.ParentAuthorName,
	)
	if err != nil {
		if strings.Contains(err.Error(), "parent") || errors.Is(err, pgx.ErrNoRows) {
			return model.PostComment{}, insertCommentResult{}, ErrCommentInvalid
		}
		return model.PostComment{}, insertCommentResult{}, err
	}
	res.CommentID = commentID

	_, _ = p.pool.Exec(ctx, `
UPDATE match_posts SET interaction_count = interaction_count + 1, updated_at = now()
WHERE id = $1`, postID)

	comments, err := p.ListPostComments(ctx, postID)
	if err != nil {
		return model.PostComment{}, res, err
	}
	for _, c := range comments {
		if c.ID == commentID {
			return c, res, nil
		}
	}
	return model.PostComment{}, res, ErrCommentNotFound
}

func (p *Postgres) InsertCommentNotification(
	ctx context.Context,
	userID, postID, commentID, kind string,
) error {
	if userID == "" {
		return nil
	}
	_, err := p.pool.Exec(ctx, `
INSERT INTO comment_notifications (user_id, post_id, comment_id, kind)
VALUES ($1::uuid, $2, $3::uuid, $4)`, userID, postID, commentID, kind)
	return err
}

const listCommentNotificationsSQL = `
SELECT
    n.id::text,
    n.kind,
    n.post_id,
    p.title,
    n.comment_id::text,
    c.body,
    COALESCE(u.username, '用户'),
    n.is_read,
    n.created_at
FROM comment_notifications n
JOIN post_comments c ON c.id = n.comment_id
JOIN match_posts p ON p.id = n.post_id
JOIN users u ON u.id = c.user_id
WHERE n.user_id = $1::uuid
ORDER BY n.created_at DESC
LIMIT 100
`

func (p *Postgres) ListCommentNotifications(
	ctx context.Context,
	userID string,
) ([]model.CommentNotification, error) {
	rows, err := p.pool.Query(ctx, listCommentNotificationsSQL, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.CommentNotification
	for rows.Next() {
		var n model.CommentNotification
		if err := rows.Scan(
			&n.ID,
			&n.Kind,
			&n.PostID,
			&n.PostTitle,
			&n.CommentID,
			&n.CommentBody,
			&n.ActorUsername,
			&n.IsRead,
			&n.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	if out == nil {
		out = []model.CommentNotification{}
	}
	return out, rows.Err()
}

func (p *Postgres) MarkCommentNotificationRead(ctx context.Context, userID, notificationID string) error {
	tag, err := p.pool.Exec(ctx, `
UPDATE comment_notifications
SET is_read = true
WHERE id = $1::uuid AND user_id = $2::uuid`, notificationID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrCommentNotFound
	}
	return nil
}

func (p *Postgres) CountUnreadCommentNotifications(ctx context.Context, userID string) (int, error) {
	var n int
	err := p.pool.QueryRow(ctx, `
SELECT COUNT(*) FROM comment_notifications
WHERE user_id = $1::uuid AND is_read = false`, userID).Scan(&n)
	return n, err
}

func TruncateCommentPreview(body string, max int) string {
	runes := []rune(strings.TrimSpace(body))
	if len(runes) <= max {
		return string(runes)
	}
	return string(runes[:max]) + "…"
}

func CommentNotificationTitle(kind, actor, postTitle string) string {
	switch kind {
	case "comment_reply":
		return fmt.Sprintf("%s 回复了你的评论", actor)
	default:
		return fmt.Sprintf("%s 评论了你的组局", actor)
	}
}

func CommentNotificationPreview(body string) string {
	return TruncateCommentPreview(body, 80)
}
