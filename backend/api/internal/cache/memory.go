// 开发环境内存 KV（Redis 不可用时的回退）
package cache

import (
	"context"
	"sync"
	"time"
)

type entry struct {
	value     string
	expiresAt time.Time
}

// Memory 线程安全内存缓存，接口对齐 SMS / Refresh / Denylist 所需操作
type Memory struct {
	mu   sync.Mutex
	data map[string]entry
}

func NewMemory() *Memory {
	return &Memory{data: make(map[string]entry)}
}

func (m *Memory) cleanupLocked(now time.Time) {
	for k, v := range m.data {
		if !v.expiresAt.IsZero() && now.After(v.expiresAt) {
			delete(m.data, k)
		}
	}
}

func (m *Memory) Set(_ context.Context, key, value string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cleanupLocked(time.Now())
	var exp time.Time
	if ttl > 0 {
		exp = time.Now().Add(ttl)
	}
	m.data[key] = entry{value: value, expiresAt: exp}
	return nil
}

func (m *Memory) Get(_ context.Context, key string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cleanupLocked(time.Now())
	e, ok := m.data[key]
	if !ok || (!e.expiresAt.IsZero() && time.Now().After(e.expiresAt)) {
		return "", ErrNotFound
	}
	return e.value, nil
}

func (m *Memory) GetDel(ctx context.Context, key string) (string, error) {
	val, err := m.Get(ctx, key)
	if err != nil {
		return "", err
	}
	_ = m.Del(ctx, key)
	return val, nil
}

func (m *Memory) Del(_ context.Context, keys ...string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, k := range keys {
		delete(m.data, k)
	}
	return nil
}

func (m *Memory) Exists(ctx context.Context, key string) (int64, error) {
	_, err := m.Get(ctx, key)
	if err != nil {
		return 0, nil
	}
	return 1, nil
}

func (m *Memory) Incr(_ context.Context, key string) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cleanupLocked(time.Now())
	e, ok := m.data[key]
	n := int64(1)
	if ok && (e.expiresAt.IsZero() || time.Now().Before(e.expiresAt)) {
		if v, err := parseInt64(e.value); err == nil {
			n = v + 1
		}
	}
	m.data[key] = entry{value: int64String(n), expiresAt: e.expiresAt}
	return n, nil
}

func (m *Memory) Expire(_ context.Context, key string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.data[key]
	if !ok {
		return ErrNotFound
	}
	if ttl > 0 {
		e.expiresAt = time.Now().Add(ttl)
	}
	m.data[key] = e
	return nil
}

func (m *Memory) TTL(_ context.Context, key string) (time.Duration, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.data[key]
	if !ok {
		return -2 * time.Second, nil
	}
	if e.expiresAt.IsZero() {
		return -1 * time.Second, nil
	}
	return time.Until(e.expiresAt), nil
}

func parseInt64(s string) (int64, error) {
	var n int64
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, ErrNotFound
		}
		n = n*10 + int64(c-'0')
	}
	return n, nil
}

func int64String(n int64) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}
