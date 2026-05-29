package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"matchit/backend/api/internal/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrApplicationExists    = errors.New("application already exists")
	ErrPostFull             = errors.New("post is full")
	ErrCannotApplyOwnPost   = errors.New("cannot apply to own post")
	ErrApplicationNotFound  = errors.New("application not found")
	ErrNotApplicationHost   = errors.New("not application host")
	ErrApplicationNotPending  = errors.New("application not pending")
	ErrApplicationNotApproved = errors.New("application not approved")
	ErrWechatContactRequired  = errors.New("wechat contact required")
)

const applicationReturning = `
id::text, post_id, user_id::text, status, COALESCE(message, ''),
COALESCE(wechat_contact, ''), created_at, updated_at`

// SubmitPostApplication 新建或重新提交申请（rejected/cancelled 可再次 pending）
func (p *Postgres) SubmitPostApplication(
	ctx context.Context,
	postID, userID, message, wechatContact string,
) (model.PostApplication, error) {
	message = strings.TrimSpace(message)
	wechatContact = strings.TrimSpace(wechatContact)
	if wechatContact == "" {
		return model.PostApplication{}, ErrWechatContactRequired
	}

	existing, found, err := p.GetUserPostApplication(ctx, postID, userID)
	if err != nil {
		return model.PostApplication{}, err
	}
	if found && IsActiveApplicationStatus(existing.Status) {
		return existing, ErrApplicationExists
	}
	if found {
		const q = `
UPDATE post_applications
SET status = 'pending',
    message = NULLIF($3, ''),
    wechat_contact = $4,
    updated_at = now()
WHERE post_id = $1 AND user_id = $2::uuid
RETURNING ` + applicationReturning
		var app model.PostApplication
		err := p.pool.QueryRow(ctx, q, postID, userID, message, wechatContact).Scan(
			&app.ID, &app.PostID, &app.UserID, &app.Status, &app.Message,
			&app.WechatContact, &app.CreatedAt, &app.UpdatedAt,
		)
		return app, err
	}

	const q = `
INSERT INTO post_applications (post_id, user_id, message, wechat_contact, status)
VALUES ($1, $2::uuid, NULLIF($3, ''), $4, 'pending')
RETURNING ` + applicationReturning
	var app model.PostApplication
	err = p.pool.QueryRow(ctx, q, postID, userID, message, wechatContact).Scan(
		&app.ID, &app.PostID, &app.UserID, &app.Status, &app.Message,
		&app.WechatContact, &app.CreatedAt, &app.UpdatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return model.PostApplication{}, ErrApplicationExists
		}
		return model.PostApplication{}, err
	}
	return app, nil
}

func (p *Postgres) GetUserPostApplication(
	ctx context.Context,
	postID, userID string,
) (model.PostApplication, bool, error) {
	const q = `
SELECT ` + applicationReturning + `
FROM post_applications
WHERE post_id = $1 AND user_id = $2::uuid`
	var app model.PostApplication
	err := p.pool.QueryRow(ctx, q, postID, userID).Scan(
		&app.ID,
		&app.PostID,
		&app.UserID,
		&app.Status,
		&app.Message,
		&app.WechatContact,
		&app.CreatedAt,
		&app.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.PostApplication{}, false, nil
	}
	if err != nil {
		return model.PostApplication{}, false, err
	}
	return app, true, nil
}

// ApplicationStatusesForUser 返回用户对一批帖子的有效申请状态（pending/approved）
func (p *Postgres) ApplicationStatusesForUser(
	ctx context.Context,
	userID string,
	postIDs []string,
) (map[string]string, error) {
	out := make(map[string]string)
	if len(postIDs) == 0 {
		return out, nil
	}
	const q = `
SELECT post_id, status
FROM post_applications
WHERE user_id = $1::uuid
  AND post_id = ANY($2::text[])
  AND status IN ('pending', 'approved')`
	rows, err := p.pool.Query(ctx, q, userID, postIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var postID, status string
		if err := rows.Scan(&postID, &status); err != nil {
			return nil, err
		}
		out[postID] = status
	}
	return out, rows.Err()
}

func IsActiveApplicationStatus(status string) bool {
	switch status {
	case "pending", "approved":
		return true
	default:
		return false
	}
}

func (p *Postgres) ListApplicationsByUser(
	ctx context.Context,
	userID string,
	limit int,
) ([]model.PostApplicationItem, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	const q = `
SELECT
    a.id::text, a.post_id, a.user_id::text, a.status, COALESCE(a.message, ''),
    COALESCE(a.wechat_contact, ''), a.created_at, a.updated_at,
    p.title, p.area, p.host_nickname, COALESCE(p.event_location, '')
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id AND p.is_active = true
WHERE a.user_id = $1::uuid
ORDER BY a.created_at DESC
LIMIT $2`
	rows, err := p.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.PostApplicationItem
	for rows.Next() {
		var item model.PostApplicationItem
		err := rows.Scan(
			&item.ID,
			&item.PostID,
			&item.UserID,
			&item.Status,
			&item.Message,
			&item.WechatContact,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.PostTitle,
			&item.PostArea,
			&item.HostNickname,
			&item.EventLocation,
		)
		if err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (p *Postgres) ListReceivedApplicationsByHost(
	ctx context.Context,
	hostUserID string,
	limit int,
) ([]model.ReceivedApplicationItem, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	const q = `
SELECT
    a.id::text, a.post_id, a.user_id::text, a.status, COALESCE(a.message, ''),
    COALESCE(a.wechat_contact, ''), a.created_at, a.updated_at,
    p.title, p.area,
    COALESCE(NULLIF(TRIM(u.username), ''), '用户'),
    COALESCE(u.phone, '')
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id AND p.is_active = true
JOIN users u ON u.id = a.user_id
WHERE p.host_user_id = $1::uuid
ORDER BY
    CASE WHEN a.status = 'pending' THEN 0 ELSE 1 END,
    a.created_at DESC
LIMIT $2`
	rows, err := p.pool.Query(ctx, q, hostUserID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.ReceivedApplicationItem
	for rows.Next() {
		var item model.ReceivedApplicationItem
		var phone string
		err := rows.Scan(
			&item.ID,
			&item.PostID,
			&item.UserID,
			&item.Status,
			&item.Message,
			&item.WechatContact,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.PostTitle,
			&item.PostArea,
			&item.ApplicantUsername,
			&phone,
		)
		if err != nil {
			return nil, err
		}
		if phone != "" {
			item.ApplicantPhoneMasked = model.MaskPhone(phone)
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (p *Postgres) ListApplicationsForPostHost(
	ctx context.Context,
	postID, hostUserID string,
) ([]model.ReceivedApplicationItem, error) {
	const q = `
SELECT
    a.id::text, a.post_id, a.user_id::text, a.status, COALESCE(a.message, ''),
    COALESCE(a.wechat_contact, ''), a.created_at, a.updated_at,
    p.title, p.area,
    COALESCE(NULLIF(TRIM(u.username), ''), '用户'),
    COALESCE(u.phone, '')
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id AND p.is_active = true
JOIN users u ON u.id = a.user_id
WHERE a.post_id = $1 AND p.host_user_id = $2::uuid
ORDER BY
    CASE WHEN a.status = 'pending' THEN 0 ELSE 1 END,
    a.created_at DESC`
	rows, err := p.pool.Query(ctx, q, postID, hostUserID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.ReceivedApplicationItem
	for rows.Next() {
		var item model.ReceivedApplicationItem
		var phone string
		err := rows.Scan(
			&item.ID,
			&item.PostID,
			&item.UserID,
			&item.Status,
			&item.Message,
			&item.WechatContact,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.PostTitle,
			&item.PostArea,
			&item.ApplicantUsername,
			&phone,
		)
		if err != nil {
			return nil, err
		}
		if phone != "" {
			item.ApplicantPhoneMasked = model.MaskPhone(phone)
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (p *Postgres) CountPendingReceivedApplications(
	ctx context.Context,
	hostUserID string,
) (int, error) {
	const q = `
SELECT COUNT(*)
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id AND p.is_active = true
WHERE p.host_user_id = $1::uuid AND a.status = 'pending'`
	var n int
	err := p.pool.QueryRow(ctx, q, hostUserID).Scan(&n)
	return n, err
}

func (p *Postgres) ReviewApplication(
	ctx context.Context,
	applicationID, hostUserID, newStatus string,
) (model.PostApplication, error) {
	if newStatus != "approved" && newStatus != "rejected" {
		return model.PostApplication{}, fmt.Errorf("invalid status %q", newStatus)
	}

	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return model.PostApplication{}, err
	}
	defer tx.Rollback(ctx)

	const loadQ = `
SELECT a.id::text, a.post_id, a.user_id::text, a.status, COALESCE(a.message, ''),
       a.created_at, a.updated_at, p.host_user_id::text, p.current_members, p.max_members
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id
WHERE a.id = $1::uuid
FOR UPDATE OF a`
	var app model.PostApplication
	var postHostID string
	var currentMembers, maxMembers int
	err = tx.QueryRow(ctx, loadQ, applicationID).Scan(
		&app.ID,
		&app.PostID,
		&app.UserID,
		&app.Status,
		&app.Message,
		&app.CreatedAt,
		&app.UpdatedAt,
		&postHostID,
		&currentMembers,
		&maxMembers,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.PostApplication{}, ErrApplicationNotFound
	}
	if err != nil {
		return model.PostApplication{}, err
	}
	if postHostID != hostUserID {
		return model.PostApplication{}, ErrNotApplicationHost
	}
	if app.Status != "pending" {
		return model.PostApplication{}, ErrApplicationNotPending
	}
	if newStatus == "approved" && currentMembers >= maxMembers {
		return model.PostApplication{}, ErrPostFull
	}

	now := time.Now().UTC()
	_, err = tx.Exec(ctx,
		`UPDATE post_applications SET status = $2, updated_at = $3 WHERE id = $1::uuid`,
		applicationID, newStatus, now,
	)
	if err != nil {
		return model.PostApplication{}, err
	}
	if newStatus == "approved" {
		_, err = tx.Exec(ctx,
			`UPDATE match_posts SET current_members = current_members + 1, last_active_time = $2, updated_at = $2 WHERE id = $1`,
			app.PostID, now,
		)
		if err != nil {
			return model.PostApplication{}, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return model.PostApplication{}, err
	}
	app.Status = newStatus
	app.UpdatedAt = now
	return app, nil
}

// CancelApprovedApplicationByHost 主理人取消已通过但未付款等情形的申请
func (p *Postgres) CancelApprovedApplicationByHost(
	ctx context.Context,
	applicationID, hostUserID string,
) (model.PostApplication, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return model.PostApplication{}, err
	}
	defer tx.Rollback(ctx)

	const loadQ = `
SELECT a.id::text, a.post_id, a.user_id::text, a.status, COALESCE(a.message, ''),
       COALESCE(a.wechat_contact, ''), a.created_at, a.updated_at, p.host_user_id::text
FROM post_applications a
JOIN match_posts p ON p.id = a.post_id
WHERE a.id = $1::uuid
FOR UPDATE OF a`
	var app model.PostApplication
	var postHostID string
	err = tx.QueryRow(ctx, loadQ, applicationID).Scan(
		&app.ID, &app.PostID, &app.UserID, &app.Status, &app.Message,
		&app.WechatContact, &app.CreatedAt, &app.UpdatedAt, &postHostID,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return model.PostApplication{}, ErrApplicationNotFound
	}
	if err != nil {
		return model.PostApplication{}, err
	}
	if postHostID != hostUserID {
		return model.PostApplication{}, ErrNotApplicationHost
	}
	if app.Status != "approved" {
		return model.PostApplication{}, ErrApplicationNotApproved
	}

	now := time.Now().UTC()
	_, err = tx.Exec(ctx,
		`UPDATE post_applications SET status = 'cancelled', updated_at = $2 WHERE id = $1::uuid`,
		applicationID, now,
	)
	if err != nil {
		return model.PostApplication{}, err
	}
	_, err = tx.Exec(ctx,
		`UPDATE match_posts
SET current_members = GREATEST(1, current_members - 1),
    last_active_time = $2,
    updated_at = $2
WHERE id = $1`,
		app.PostID, now,
	)
	if err != nil {
		return model.PostApplication{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return model.PostApplication{}, err
	}
	app.Status = "cancelled"
	app.UpdatedAt = now
	return app, nil
}

func (p *Postgres) ListPostMembers(
	ctx context.Context,
	postID string,
) ([]model.PostMember, error) {
	post, err := p.GetPost(ctx, postID)
	if err != nil {
		return nil, err
	}

	var members []model.PostMember
	hostAdded := false
	if post.HostUserID != "" || post.HostNickname != "" {
		members = append(members, model.PostMember{
			UserID:   post.HostUserID,
			Username: post.HostNickname,
			Role:     "host",
		})
		hostAdded = post.HostUserID != ""
	}

	const q = `
SELECT u.id::text, COALESCE(NULLIF(TRIM(u.username), ''), '用户'), a.updated_at
FROM post_applications a
JOIN users u ON u.id = a.user_id
WHERE a.post_id = $1 AND a.status = 'approved'
ORDER BY a.updated_at ASC`
	rows, err := p.pool.Query(ctx, q, postID)
	if err != nil {
		return members, err
	}
	defer rows.Close()
	for rows.Next() {
		var m model.PostMember
		var joinedAt time.Time
		if err := rows.Scan(&m.UserID, &m.Username, &joinedAt); err != nil {
			return nil, err
		}
		if hostAdded && m.UserID == post.HostUserID {
			continue
		}
		m.Role = "member"
		m.JoinedAt = joinedAt
		members = append(members, m)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return members, nil
}

func (p *Postgres) TouchPostLastActive(ctx context.Context, postID string) error {
	_, err := p.pool.Exec(ctx,
		`UPDATE match_posts SET last_active_time = $2, updated_at = $2 WHERE id = $1`,
		postID, time.Now().UTC(),
	)
	return err
}

func ApplicationHTTPError(err error) (int, string) {
	switch {
	case errors.Is(err, ErrApplicationExists):
		return 409, "already applied"
	case errors.Is(err, ErrPostFull):
		return 409, "post is full"
	case errors.Is(err, ErrCannotApplyOwnPost):
		return 400, "cannot apply to own post"
	case errors.Is(err, ErrApplicationNotFound):
		return 404, "application not found"
	case errors.Is(err, ErrNotApplicationHost):
		return 403, "not post host"
	case errors.Is(err, ErrApplicationNotPending):
		return 409, "application not pending"
	case errors.Is(err, ErrApplicationNotApproved):
		return 409, "application not approved"
	case errors.Is(err, ErrWechatContactRequired):
		return 400, "wechat_contact_required"
	default:
		if strings.Contains(err.Error(), "post_applications") &&
			strings.Contains(err.Error(), "does not exist") {
			return 503, "applications table missing; run schema 006_post_applications.sql"
		}
		return 500, fmt.Sprintf("internal error: %v", err)
	}
}
