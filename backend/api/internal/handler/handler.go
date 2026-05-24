// HTTP 路由注册与帖子相关 Handler
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

// API 聚合数据库、用户仓储与 JWT
type API struct {
	db    *store.Postgres   // 帖子（pgx + pgvector）
	users *store.UserStore  // 用户（GORM）
	jwt   *auth.JWT
}

func New(db *store.Postgres, users *store.UserStore, jwt *auth.JWT) *API {
	return &API{db: db, users: users, jwt: jwt}
}

// Register 注册全部路由及中间件链
func (a *API) Register(r *gin.Engine) {
	r.GET("/health", a.health)

	v1 := r.Group("/api/v1")
	{
		// ── 公开接口（无需 Token）──
		authGroup := v1.Group("/auth")
		authGroup.POST("/guest-login", a.GuestLogin)
		authGroup.POST("/bind-phone",
			middleware.AuthMiddleware(a.jwt),
			middleware.GuestOnly(),
			a.BindPhone,
		)

		v1.GET("/posts/:id", a.getPost) // 帖子详情可匿名浏览
		v1.POST("/seed", a.seedPosts)   // 开发用种子数据

		// ── 需登录：游客或正式用户均可 ──
		authed := v1.Group("")
		authed.Use(middleware.AuthMiddleware(a.jwt))
		authed.GET("/me", a.Me)
		authed.GET("/posts", a.listPosts) // 推荐/Feed，依赖 user_id 做个性化（后续扩展）

		// ── 需正式用户：isGuest=false ──
		registered := authed.Group("")
		registered.Use(middleware.RegisteredOnly())
		registered.POST("/posts", a.createPost) // 发帖必须绑定手机
	}
}

func (a *API) health(c *gin.Context) {
	count, err := a.db.CountPosts(c.Request.Context())
	if err != nil {
		JSONError(c, http.StatusServiceUnavailable, "database unavailable")
		return
	}
	JSONOK(c, gin.H{
		"status":    "ok",
		"postCount": count,
		"time":      time.Now().UTC(),
	})
}

// listPosts 推荐/Feed 列表（需 Token，响应中带 userId 便于前端确认身份）
func (a *API) listPosts(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	q := model.ListPostsQuery{
		Area: c.Query("area"),
		Tab:  c.Query("tab"),
	}
	posts, err := a.db.ListPosts(c.Request.Context(), q)
	if err != nil {
		log.Printf("list posts user=%s: %v", userID, err)
		JSONError(c, http.StatusInternalServerError, "failed to list posts")
		return
	}
	if posts == nil {
		posts = []model.MatchPost{}
	}

	JSONOK(c, gin.H{
		"data":    posts,
		"total":   len(posts),
		"userId":  userID,
		"isGuest": middleware.IsGuest(c),
	})
}

func (a *API) getPost(c *gin.Context) {
	id := c.Param("id")
	post, err := a.db.GetPost(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			JSONError(c, http.StatusNotFound, "post not found")
			return
		}
		log.Printf("get post: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to get post")
		return
	}
	JSONOK(c, post)
}

// createPost 发布帖子（需正式用户；user_id 来自 JWT Context）
func (a *API) createPost(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	var req model.CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}
	post := req.MatchPost
	if err := validatePost(post); err != nil {
		JSONError(c, http.StatusBadRequest, err.Error())
		return
	}
	if post.LastActiveTime.IsZero() {
		post.LastActiveTime = time.Now().UTC()
	}
	if err := a.db.UpsertPost(c.Request.Context(), post); err != nil {
		log.Printf("create post user=%s: %v", userID, err)
		JSONError(c, http.StatusInternalServerError, "failed to save post")
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"post":   post,
		"userId": userID,
	})
}

func (a *API) seedPosts(c *gin.Context) {
	ctx := c.Request.Context()
	posts := seed.Posts(time.Now().UTC())
	for _, post := range posts {
		if err := a.db.UpsertPost(ctx, post); err != nil {
			log.Printf("seed post %s: %v", post.ID, err)
			JSONError(c, http.StatusInternalServerError, "seed failed")
			return
		}
	}
	JSONOK(c, gin.H{
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
