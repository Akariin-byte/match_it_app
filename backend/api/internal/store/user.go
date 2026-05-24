package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"matchit/backend/api/internal/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrPhoneAlreadyBound = errors.New("phone already bound")
	ErrNotGuestUser      = errors.New("user is not a guest")
)

const scanUserSQL = `
SELECT id::text, openid, phone, is_guest, nickname, created_at, updated_at
FROM users
`

func scanUser(row pgx.Row) (model.User, error) {
	var u model.User
	err := row.Scan(&u.ID, &u.OpenID, &u.Phone, &u.IsGuest, &u.Nickname, &u.CreatedAt, &u.UpdatedAt)
	return u, err
}

func (p *Postgres) CreateGuestUser(ctx context.Context, openid string) (model.User, error) {
	const q = `
INSERT INTO users (openid, is_guest)
VALUES ($1, true)
RETURNING id::text, openid, phone, is_guest, nickname, created_at, updated_at
`
	row := p.pool.QueryRow(ctx, q, openid)
	user, err := scanUser(row)
	if err != nil {
		return model.User{}, fmt.Errorf("create guest user: %w", err)
	}
	return user, nil
}

func (p *Postgres) GetUserByID(ctx context.Context, id string) (model.User, error) {
	row := p.pool.QueryRow(ctx, scanUserSQL+` WHERE id = $1::uuid`, id)
	user, err := scanUser(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return model.User{}, ErrUserNotFound
		}
		return model.User{}, err
	}
	return user, nil
}

func (p *Postgres) BindPhone(ctx context.Context, userID, phone string) (model.User, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return model.User{}, err
	}
	defer tx.Rollback(ctx)

	var isGuest bool
	err = tx.QueryRow(ctx, `SELECT is_guest FROM users WHERE id = $1::uuid FOR UPDATE`, userID).Scan(&isGuest)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return model.User{}, ErrUserNotFound
		}
		return model.User{}, err
	}
	if !isGuest {
		return model.User{}, ErrNotGuestUser
	}

	var takenBy string
	err = tx.QueryRow(ctx, `SELECT id::text FROM users WHERE phone = $1`, phone).Scan(&takenBy)
	if err == nil && takenBy != userID {
		return model.User{}, ErrPhoneAlreadyBound
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return model.User{}, err
	}

	const updateSQL = `
UPDATE users
SET phone = $2, is_guest = false, updated_at = $3
WHERE id = $1::uuid
RETURNING id::text, openid, phone, is_guest, nickname, created_at, updated_at
`
	row := tx.QueryRow(ctx, updateSQL, userID, phone, time.Now().UTC())
	user, err := scanUser(row)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return model.User{}, ErrPhoneAlreadyBound
		}
		return model.User{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.User{}, err
	}
	return user, nil
}
