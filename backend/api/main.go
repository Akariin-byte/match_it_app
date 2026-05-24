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

	jwtMgr, err := auth.NewJWT(cfg.JWTSecret, cfg.JWTGuestTTL, cfg.JWTMemberTTL)
	if err != nil {
		log.Fatalf("jwt: %v", err)
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery(), corsMiddleware())
	handler.New(db, jwtMgr).Register(r)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("MATCHit API listening on http://localhost:%s", cfg.Port)
		log.Printf("  GET  /health")
		log.Printf("  POST /api/v1/auth/guest")
		log.Printf("  POST /api/v1/auth/bind-phone  (Authorization: Bearer <guest token>)")
		log.Printf("  GET  /api/v1/me               (Authorization: Bearer <token>)")
		log.Printf("  GET  /api/v1/posts?area=BoardGames&tab=推荐")
		log.Printf("  POST /api/v1/seed")
		log.Printf("  POST /api/v1/posts            (Authorization: Bearer <token>)")
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
