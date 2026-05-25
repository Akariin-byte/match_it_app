package store

import (
	"context"
	"errors"
	"time"

	"matchit/backend/api/internal/cache"

	"github.com/redis/go-redis/v9"
)

func cacheNotFound(err error) error {
	if errors.Is(err, redis.Nil) {
		return cache.ErrNotFound
	}
	return err
}

// RedisCache 将 go-redis 适配为 cache.Store
type RedisCache struct {
	client *redis.Client
}

func NewRedisCache(client *redis.Client) *RedisCache {
	return &RedisCache{client: client}
}

func (r *RedisCache) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	return r.client.Set(ctx, key, value, ttl).Err()
}

func (r *RedisCache) Get(ctx context.Context, key string) (string, error) {
	val, err := r.client.Get(ctx, key).Result()
	return val, cacheNotFound(err)
}

func (r *RedisCache) GetDel(ctx context.Context, key string) (string, error) {
	val, err := r.client.GetDel(ctx, key).Result()
	return val, cacheNotFound(err)
}

func (r *RedisCache) Del(ctx context.Context, keys ...string) error {
	if len(keys) == 0 {
		return nil
	}
	return r.client.Del(ctx, keys...).Err()
}

func (r *RedisCache) Exists(ctx context.Context, key string) (int64, error) {
	return r.client.Exists(ctx, key).Result()
}

func (r *RedisCache) Incr(ctx context.Context, key string) (int64, error) {
	return r.client.Incr(ctx, key).Result()
}

func (r *RedisCache) Expire(ctx context.Context, key string, ttl time.Duration) error {
	return r.client.Expire(ctx, key, ttl).Err()
}

func (r *RedisCache) TTL(ctx context.Context, key string) (time.Duration, error) {
	return r.client.TTL(ctx, key).Result()
}

// OpenCache Redis 不可用时回退到内存缓存
func OpenCache(redisURL string) (cache.Store, func(), error) {
	redisStore, err := NewRedis(redisURL)
	if err == nil {
		return NewRedisCache(redisStore.Client()), func() { _ = redisStore.Close() }, nil
	}
	return cache.NewMemory(), func() {}, err
}
