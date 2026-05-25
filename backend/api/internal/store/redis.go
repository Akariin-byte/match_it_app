package store

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Redis 封装 go-redis 客户端（验证码、Refresh Token、限流）
type Redis struct {
	client *redis.Client
}

func NewRedis(redisURL string) (*Redis, error) {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("redis url: %w", err)
	}
	client := redis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping: %w", err)
	}
	return &Redis{client: client}, nil
}

func (r *Redis) Client() *redis.Client { return r.client }

func (r *Redis) Close() error { return r.client.Close() }
