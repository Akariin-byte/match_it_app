package handler

import (
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"matchit/backend/api/internal/auth"
	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/seed"
	"matchit/backend/api/internal/store"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

type API struct {
	db  *store.Postgres
	jwt *auth.JWT
}

func New(db *store.Postgres, jwt *auth.JWT) *API {
	return &API{db: db, jwt: jwt}
}

func (a *API) Register(r *gin.Engine) {
	r.GET("/health", a.health)

	v1 := r.Group("/api/v1")
	{
		authGroup := v1.Group("/auth")
		authGroup.POST("/guest", a.GuestLogin)
		authGroup.POST("/bind-phone", middleware.JWTAuth(a.jwt), middleware.GuestOnly(), a.BindPhone)

		v1.GET("/posts", a.listPosts)
		v1.GET("/posts/:id", a.getPost)
		v1.POST("/seed", a.seedPosts)

		// 需登录（游客或正式用户均可）
		authed := v1.Group("")
		authed.Use(middleware.JWTAuth(a.jwt))
		authed.GET("/me", a.Me)
		authed.POST("/posts", a.createPost)
	}
}

func (a *API) health(c *gin.Context) {
	count, err := a.db.CountPosts(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "database unavailable"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"status":    "ok",
		"postCount": count,
		"time":      time.Now().UTC(),
	})
}

func (a *API) listPosts(c *gin.Context) {
	q := model.ListPostsQuery{
		Area: c.Query("area"),
		Tab:  c.Query("tab"),
	}
	posts, err := a.db.ListPosts(c.Request.Context(), q)
	if err != nil {
		log.Printf("list posts: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list posts"})
		return
	}
	if posts == nil {
		posts = []model.MatchPost{}
	}
	c.JSON(http.StatusOK, gin.H{
		"data":  posts,
		"total": len(posts),
	})
}

func (a *API) getPost(c *gin.Context) {
	id := c.Param("id")
	post, err := a.db.GetPost(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "post not found"})
			return
		}
		log.Printf("get post: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get post"})
		return
	}
	c.JSON(http.StatusOK, post)
}

func (a *API) createPost(c *gin.Context) {
	var req model.CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json body"})
		return
	}
	post := req.MatchPost
	if err := validatePost(post); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if post.LastActiveTime.IsZero() {
		post.LastActiveTime = time.Now().UTC()
	}
	if err := a.db.UpsertPost(c.Request.Context(), post); err != nil {
		log.Printf("create post: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save post"})
		return
	}
	c.JSON(http.StatusCreated, post)
}

func (a *API) seedPosts(c *gin.Context) {
	ctx := c.Request.Context()
	posts := seed.Posts(time.Now().UTC())
	for _, post := range posts {
		if err := a.db.UpsertPost(ctx, post); err != nil {
			log.Printf("seed post %s: %v", post.ID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "seed failed"})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"message": "seed completed",
		"count":   len(posts),
	})
}

func validatePost(p model.MatchPost) error {
	if strings.TrimSpace(p.ID) == "" {
		return errors.New("id is required")
	}
	if strings.TrimSpace(p.Title) == "" {
		return errors.New("title is required")
	}
	if strings.TrimSpace(p.Area) == "" {
		return errors.New("area is required")
	}
	if p.MaxMembers <= 0 {
		return errors.New("maxMembers must be > 0")
	}
	return nil
}
