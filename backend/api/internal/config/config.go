package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL      string
	RedisURL         string
	Port             string
	JWTSecret        string
	JWTGuestTTL      time.Duration
	JWTMemberTTL     time.Duration
	RefreshTokenTTL  time.Duration
	SMSMock          bool
	SMSCodeTTL       time.Duration
	SMSResendCooldown time.Duration
	SMSMaxVerifyFail int
}

func Load() (Config, error) {
	_ = godotenv.Load()

	cfg := Config{
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		RedisURL:          getenv("REDIS_URL", "redis://localhost:6379/0"),
		Port:              getenv("PORT", "8080"),
		JWTSecret:         os.Getenv("JWT_SECRET"),
		JWTGuestTTL:       durationHours("JWT_GUEST_TTL_HOURS", 30*24),
		JWTMemberTTL:      durationHours("JWT_MEMBER_TTL_HOURS", 7*24),
		RefreshTokenTTL:   durationHours("REFRESH_TOKEN_TTL_HOURS", 30*24),
		SMSMock:           getenvBool("SMS_MOCK", true),
		SMSCodeTTL:        durationMinutes("SMS_CODE_TTL_MINUTES", 5),
		SMSResendCooldown: durationSeconds("SMS_RESEND_COOLDOWN_SECONDS", 60),
		SMSMaxVerifyFail:  intFromEnv("SMS_MAX_VERIFY_FAIL", 5),
	}
	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return cfg, fmt.Errorf("JWT_SECRET is required")
	}
	if cfg.SMSMaxVerifyFail <= 0 {
		cfg.SMSMaxVerifyFail = 5
	}
	// Mock 模式便于联调：不限制重复获取验证码
	if cfg.SMSMock {
		cfg.SMSResendCooldown = 0
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvBool(key string, fallback bool) bool {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		return fallback
	}
	return v
}

func intFromEnv(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return v
}

func durationHours(key string, defaultHours int) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return time.Duration(defaultHours) * time.Hour
	}
	hours, err := strconv.Atoi(raw)
	if err != nil || hours <= 0 {
		return time.Duration(defaultHours) * time.Hour
	}
	return time.Duration(hours) * time.Hour
}

func durationMinutes(key string, defaultMinutes int) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return time.Duration(defaultMinutes) * time.Minute
	}
	minutes, err := strconv.Atoi(raw)
	if err != nil || minutes <= 0 {
		return time.Duration(defaultMinutes) * time.Minute
	}
	return time.Duration(minutes) * time.Minute
}

func durationSeconds(key string, defaultSeconds int) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return time.Duration(defaultSeconds) * time.Second
	}
	seconds, err := strconv.Atoi(raw)
	if err != nil || seconds <= 0 {
		return time.Duration(defaultSeconds) * time.Second
	}
	return time.Duration(seconds) * time.Second
}
