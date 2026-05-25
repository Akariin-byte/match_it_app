// Refresh Token 存储与轮换
package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"matchit/backend/api/internal/cache"
)

var ErrRefreshTokenInvalid = errors.New("invalid or expired refresh token")

type RefreshStore struct {
	kv  cache.Store
	ttl time.Duration
}

func NewRefreshStore(kv cache.Store, ttl time.Duration) *RefreshStore {
	return &RefreshStore{kv: kv, ttl: ttl}
}

func refreshKey(token string) string {
	return "refresh:" + token
}

func (s *RefreshStore) Issue(ctx context.Context, userID string) (string, error) {
	token, err := randomToken()
	if err != nil {
		return "", err
	}
	if err := s.kv.Set(ctx, refreshKey(token), userID, s.ttl); err != nil {
		return "", err
	}
	return token, nil
}

func (s *RefreshStore) Consume(ctx context.Context, token string) (string, error) {
	userID, err := s.kv.GetDel(ctx, refreshKey(token))
	if cache.IsNotFound(err) {
		return "", ErrRefreshTokenInvalid
	}
	if err != nil {
		return "", err
	}
	if userID == "" {
		return "", ErrRefreshTokenInvalid
	}
	return userID, nil
}

func (s *RefreshStore) Revoke(ctx context.Context, token string) error {
	if token == "" {
		return nil
	}
	return s.kv.Del(ctx, refreshKey(token))
}

func randomToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("random token: %w", err)
	}
	return hex.EncodeToString(b), nil
}
