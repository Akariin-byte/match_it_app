package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL string
	Port        string
	JWTSecret   string
	JWTGuestTTL time.Duration
	JWTMemberTTL time.Duration
}

func Load() (Config, error) {
	_ = godotenv.Load()

	cfg := Config{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		Port:        getenv("PORT", "8080"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
		JWTGuestTTL: durationHours("JWT_GUEST_TTL_HOURS", 30*24),
		JWTMemberTTL: durationHours("JWT_MEMBER_TTL_HOURS", 7*24),
	}
	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return cfg, fmt.Errorf("JWT_SECRET is required")
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
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
