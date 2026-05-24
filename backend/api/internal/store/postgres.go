package store

import (
	"context"
	"fmt"
	"time"

	"matchit/backend/api/internal/encoder"
	"matchit/backend/api/internal/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	pgxvec "github.com/pgvector/pgvector-go/pgx"
)

type Postgres struct {
	pool *pgxpool.Pool
}

func NewPostgres(ctx context.Context, databaseURL string) (*Postgres, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		return pgxvec.RegisterTypes(ctx, conn)
	}

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("connect postgres: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	return &Postgres{pool: pool}, nil
}

func (p *Postgres) Close() {
	p.pool.Close()
}

const upsertPostSQL = `
INSERT INTO match_posts (
    id, title, description, area, tab, hardcore_score,
    current_members, max_members, interaction_count, last_active_time,
    match_score, host_nickname, host_credit_score, host_face_traits,
    host_face_vector, event_date_time, event_location, is_pinned, pin_priority,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6,
    $7, $8, $9, $10,
    $11, $12, $13, $14,
    $15, $16, $17, $18, $19,
    now()
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    area = EXCLUDED.area,
    tab = EXCLUDED.tab,
    hardcore_score = EXCLUDED.hardcore_score,
    current_members = EXCLUDED.current_members,
    max_members = EXCLUDED.max_members,
    interaction_count = EXCLUDED.interaction_count,
    last_active_time = EXCLUDED.last_active_time,
    match_score = EXCLUDED.match_score,
    host_nickname = EXCLUDED.host_nickname,
    host_credit_score = EXCLUDED.host_credit_score,
    host_face_traits = EXCLUDED.host_face_traits,
    host_face_vector = EXCLUDED.host_face_vector,
    event_date_time = EXCLUDED.event_date_time,
    event_location = EXCLUDED.event_location,
    is_pinned = EXCLUDED.is_pinned,
    pin_priority = EXCLUDED.pin_priority,
    updated_at = now()
`

func (p *Postgres) UpsertPost(ctx context.Context, post model.MatchPost) error {
	vec := encoder.EncodeTraits(post.HostFaceTraits)
	_, err := p.pool.Exec(ctx, upsertPostSQL,
		post.ID,
		post.Title,
		post.Description,
		post.Area,
		post.Tab,
		post.HardcoreScore,
		post.CurrentMembers,
		post.MaxMembers,
		post.InteractionCount,
		post.LastActiveTime,
		post.MatchScore,
		post.HostNickname,
		post.HostCreditScore,
		post.HostFaceTraits,
		vec,
		post.EventDateTime,
		post.EventLocation,
		post.IsPinned,
		post.PinPriority,
	)
	return err
}

const listPostsSQL = `
SELECT
    id, title, description, area, tab, hardcore_score,
    current_members, max_members, interaction_count, last_active_time,
    match_score, host_nickname, host_credit_score, host_face_traits,
    event_date_time, event_location, is_pinned, pin_priority
FROM match_posts
WHERE is_active = true
  AND ($1 = '' OR area = $1)
  AND ($2 = '' OR tab = $2)
ORDER BY is_pinned DESC, pin_priority DESC, last_active_time DESC
`

func (p *Postgres) ListPosts(ctx context.Context, q model.ListPostsQuery) ([]model.MatchPost, error) {
	rows, err := p.pool.Query(ctx, listPostsSQL, q.Area, q.Tab)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []model.MatchPost
	for rows.Next() {
		post, err := scanPost(rows)
		if err != nil {
			return nil, err
		}
		posts = append(posts, post)
	}
	return posts, rows.Err()
}

const getPostSQL = `
SELECT
    id, title, description, area, tab, hardcore_score,
    current_members, max_members, interaction_count, last_active_time,
    match_score, host_nickname, host_credit_score, host_face_traits,
    event_date_time, event_location, is_pinned, pin_priority
FROM match_posts
WHERE id = $1 AND is_active = true
`

func (p *Postgres) GetPost(ctx context.Context, id string) (model.MatchPost, error) {
	row := p.pool.QueryRow(ctx, getPostSQL, id)
	return scanPostRow(row)
}

type scannable interface {
	Scan(dest ...any) error
}

func scanPost(row scannable) (model.MatchPost, error) {
	return scanPostRow(row)
}

func scanPostRow(row scannable) (model.MatchPost, error) {
	var post model.MatchPost
	var eventTime *time.Time
	err := row.Scan(
		&post.ID,
		&post.Title,
		&post.Description,
		&post.Area,
		&post.Tab,
		&post.HardcoreScore,
		&post.CurrentMembers,
		&post.MaxMembers,
		&post.InteractionCount,
		&post.LastActiveTime,
		&post.MatchScore,
		&post.HostNickname,
		&post.HostCreditScore,
		&post.HostFaceTraits,
		&eventTime,
		&post.EventLocation,
		&post.IsPinned,
		&post.PinPriority,
	)
	if eventTime != nil {
		post.EventDateTime = *eventTime
	}
	return post, err
}

func (p *Postgres) CountPosts(ctx context.Context) (int, error) {
	var n int
	err := p.pool.QueryRow(ctx, `SELECT COUNT(*) FROM match_posts WHERE is_active = true`).Scan(&n)
	return n, err
}
