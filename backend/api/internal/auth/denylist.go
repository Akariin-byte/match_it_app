package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"time"

	"matchit/backend/api/internal/cache"
)

type TokenDenylist struct {
	kv cache.Store
}

func NewTokenDenylist(kv cache.Store) *TokenDenylist {
	return &TokenDenylist{kv: kv}
}

func accessDenyKey(token string) string {
	sum := sha256.Sum256([]byte(token))
	return "deny:access:" + hex.EncodeToString(sum[:16])
}

func (d *TokenDenylist) Deny(ctx context.Context, accessToken string, ttl time.Duration) error {
	if accessToken == "" || ttl <= 0 {
		return nil
	}
	return d.kv.Set(ctx, accessDenyKey(accessToken), "1", ttl)
}

func (d *TokenDenylist) IsDenied(ctx context.Context, accessToken string) (bool, error) {
	if accessToken == "" {
		return false, nil
	}
	n, err := d.kv.Exists(ctx, accessDenyKey(accessToken))
	if err != nil {
		return false, err
	}
	return n > 0, nil
}
