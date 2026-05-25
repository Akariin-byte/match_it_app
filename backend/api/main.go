// MATCHit API 入口：Gin 服务、CORS、优雅退出
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"matchit/backend/api/internal/auth"
	"matchit/backend/api/internal/config"
	"matchit/backend/api/internal/handler"
	"matchit/backend/api/internal/sms"
	"matchit/backend/api/internal/store"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	db, err := store.NewPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("postgres: %v", err)
	}
	defer db.Close()

	users, err := store.NewUserStore(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("user store: %v", err)
	}

	kv, closeCache, redisErr := store.OpenCache(cfg.RedisURL)
	defer closeCache()
	if redisErr != nil {
		log.Printf("redis unavailable, using in-memory cache: %v", redisErr)
	} else {
		log.Printf("cache: redis (%s)", cfg.RedisURL)
	}

	jwtMgr, err := auth.NewJWT(cfg.JWTSecret, cfg.JWTGuestTTL, cfg.JWTMemberTTL)
	if err != nil {
		log.Fatalf("jwt: %v", err)
	}

	smsSvc := sms.NewService(
		kv,
		cfg.SMSMock,
		cfg.SMSCodeTTL,
		cfg.SMSResendCooldown,
		cfg.SMSMaxVerifyFail,
	)
	refreshStore := auth.NewRefreshStore(kv, cfg.RefreshTokenTTL)
	denylist := auth.NewTokenDenylist(kv)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery(), corsMiddleware())
	handler.New(db, users, jwtMgr, smsSvc, refreshStore, denylist, cfg.SMSMock, cfg.SMSCodeTTL).Register(r)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("MATCHit API listening on http://localhost:%s", cfg.Port)
		log.Printf("  POST /api/v1/auth/guest-login")
		log.Printf("  POST /api/v1/auth/register      (new phone, no guest token)")
		log.Printf("  POST /api/v1/auth/bind-phone   (registered phone auto-login)")
		log.Printf("  POST /api/v1/auth/login")
		if cfg.SMSMock {
			log.Printf("  SMS_MOCK=true  dev bypass code: %s", sms.DevBypassCode)
		}
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
