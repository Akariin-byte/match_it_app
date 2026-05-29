package handler

import (
	"errors"
	"log"
	"net/http"
	"strings"

	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/store"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

func (a *API) enrichPostsWithApplications(
	ctx *gin.Context,
	userID string,
	posts []model.MatchPost,
) []model.MatchPost {
	if len(posts) == 0 || middleware.IsGuest(ctx) {
		return posts
	}
	ids := make([]string, len(posts))
	for i := range posts {
		ids[i] = posts[i].ID
	}
	statuses, err := a.db.ApplicationStatusesForUser(ctx.Request.Context(), userID, ids)
	if err != nil {
		log.Printf("enrich applications user=%s: %v", userID, err)
		return posts
	}
	for i := range posts {
		if st, ok := statuses[posts[i].ID]; ok {
			posts[i].ApplicationStatus = st
			posts[i].HasApplied = store.IsActiveApplicationStatus(st)
		}
	}
	return posts
}

// applyToPost POST /api/v1/posts/:id/apply — 正式用户申请加入（pending，待主理人确认）
func (a *API) applyToPost(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	postID := strings.TrimSpace(c.Param("id"))
	if postID == "" {
		JSONError(c, http.StatusBadRequest, "post id is required")
		return
	}

	var req model.ApplyPostRequest
	_ = c.ShouldBindJSON(&req)
	wechatContact := strings.TrimSpace(req.WechatContact)
	if wechatContact == "" {
		JSONErrorDetail(c, http.StatusBadRequest, "wechat_contact_required",
			"请填写微信昵称或微信号", "")
		return
	}

	ctx := c.Request.Context()
	post, err := a.db.GetPost(ctx, postID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			JSONError(c, http.StatusNotFound, "post not found")
			return
		}
		log.Printf("apply get post %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to load post")
		return
	}

	if post.HostUserID != "" && post.HostUserID == userID {
		JSONErrorDetail(c, http.StatusBadRequest, "cannot_apply_own_post",
			"不能申请自己发布的组局", "")
		return
	}
	if post.CurrentMembers >= post.MaxMembers {
		JSONError(c, http.StatusConflict, "post is full")
		return
	}

	if existing, found, err := a.db.GetUserPostApplication(ctx, postID, userID); err != nil {
		log.Printf("apply check existing post=%s user=%s: %v", postID, userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	} else if found && store.IsActiveApplicationStatus(existing.Status) {
		c.JSON(http.StatusOK, gin.H{
			"application": existing,
			"hasApplied":  true,
			"message":     "already applied",
		})
		return
	}

	app, err := a.db.SubmitPostApplication(ctx, postID, userID, req.Message, wechatContact)
	if err != nil {
		if errors.Is(err, store.ErrApplicationExists) {
			existing, found, _ := a.db.GetUserPostApplication(ctx, postID, userID)
			if found {
				c.JSON(http.StatusOK, gin.H{
					"application": existing,
					"hasApplied":  store.IsActiveApplicationStatus(existing.Status),
				})
				return
			}
			JSONError(c, http.StatusConflict, "already applied")
			return
		}
		log.Printf("apply create post=%s user=%s: %v", postID, userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	}

	_ = a.db.TouchPostLastActive(ctx, postID)

	c.JSON(http.StatusCreated, gin.H{
		"application": app,
		"hasApplied":  true,
	})
}

// listMyApplications GET /api/v1/me/applications — 我发出的组局申请（消息 · 申请）
func (a *API) listMyApplications(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	if middleware.IsGuest(c) {
		JSONOK(c, gin.H{"data": []model.PostApplicationItem{}, "isGuest": true})
		return
	}

	items, err := a.db.ListApplicationsByUser(c.Request.Context(), userID, 50)
	if err != nil {
		log.Printf("list applications user=%s: %v", userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	}
	if items == nil {
		items = []model.PostApplicationItem{}
	}
	JSONOK(c, gin.H{"data": items, "total": len(items)})
}

// listReceivedApplications GET /api/v1/me/received-applications — 我收到的组局申请（主理人）
func (a *API) listReceivedApplications(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	items, err := a.db.ListReceivedApplicationsByHost(c.Request.Context(), userID, 50)
	if err != nil {
		log.Printf("list received applications host=%s: %v", userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	}
	if items == nil {
		items = []model.ReceivedApplicationItem{}
	}
	pending, _ := a.db.CountPendingReceivedApplications(c.Request.Context(), userID)
	JSONOK(c, gin.H{
		"data":          items,
		"total":         len(items),
		"pendingCount":  pending,
	})
}

func (a *API) approveApplication(c *gin.Context) {
	a.reviewApplication(c, "approved")
}

func (a *API) rejectApplication(c *gin.Context) {
	a.reviewApplication(c, "rejected")
}

// cancelApplication POST /api/v1/applications/:id/cancel — 主理人取消已通过申请（未付款等）
func (a *API) cancelApplication(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	appID := strings.TrimSpace(c.Param("id"))
	if appID == "" {
		JSONError(c, http.StatusBadRequest, "application id is required")
		return
	}

	app, err := a.db.CancelApprovedApplicationByHost(c.Request.Context(), appID, userID)
	if err != nil {
		log.Printf("cancel application %s host=%s: %v", appID, userID, err)
		code, msg := store.ApplicationHTTPError(err)
		if errors.Is(err, store.ErrNotApplicationHost) {
			JSONErrorDetail(c, code, "not_host", "仅主理人可操作", "")
			return
		}
		if errors.Is(err, store.ErrApplicationNotApproved) {
			JSONErrorDetail(c, code, "not_approved", "仅可取消已通过的申请", "")
			return
		}
		JSONError(c, code, msg)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"application": app,
		"message":     "已取消",
	})
}

func (a *API) reviewApplication(c *gin.Context, status string) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	appID := strings.TrimSpace(c.Param("id"))
	if appID == "" {
		JSONError(c, http.StatusBadRequest, "application id is required")
		return
	}

	app, err := a.db.ReviewApplication(c.Request.Context(), appID, userID, status)
	if err != nil {
		log.Printf("review application %s host=%s status=%s: %v", appID, userID, status, err)
		code, msg := store.ApplicationHTTPError(err)
		if errors.Is(err, store.ErrPostFull) {
			JSONErrorDetail(c, code, "post_full", "组局已满员，无法通过", "")
			return
		}
		if errors.Is(err, store.ErrNotApplicationHost) {
			JSONErrorDetail(c, code, "not_host", "仅主理人可操作", "")
			return
		}
		JSONError(c, code, msg)
		return
	}

	label := "已通过"
	if status == "rejected" {
		label = "已拒绝"
	}
	c.JSON(http.StatusOK, gin.H{
		"application": app,
		"message":     label,
	})
	if status == "approved" {
		a.EnsureDMOnApprove(c.Request.Context(), userID, app.UserID, app.PostID)
	}
}

// listPostReceivedApplications GET /api/v1/posts/:id/received-applications — 该帖主理人查看收到的申请
func (a *API) listPostReceivedApplications(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	postID := strings.TrimSpace(c.Param("id"))
	if postID == "" {
		JSONError(c, http.StatusBadRequest, "post id is required")
		return
	}

	ctx := c.Request.Context()
	post, err := a.db.GetPost(ctx, postID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			JSONError(c, http.StatusNotFound, "post not found")
			return
		}
		log.Printf("list post applications get post %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to load post")
		return
	}
	if post.HostUserID == "" || post.HostUserID != userID {
		JSONErrorDetail(c, http.StatusForbidden, "not_host", "仅主理人可查看该组局的申请", "")
		return
	}

	items, err := a.db.ListApplicationsForPostHost(ctx, postID, userID)
	if err != nil {
		log.Printf("list post applications post=%s host=%s: %v", postID, userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	}
	if items == nil {
		items = []model.ReceivedApplicationItem{}
	}
	pending := 0
	for _, it := range items {
		if it.Status == "pending" {
			pending++
		}
	}
	JSONOK(c, gin.H{
		"data":         items,
		"total":        len(items),
		"pendingCount": pending,
	})
}

// getMyPostApplication GET /api/v1/posts/:id/application — 当前用户对该帖的申请状态
func (a *API) getMyPostApplication(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	if middleware.IsGuest(c) {
		JSONOK(c, gin.H{"hasApplied": false})
		return
	}

	postID := strings.TrimSpace(c.Param("id"))
	app, found, err := a.db.GetUserPostApplication(c.Request.Context(), postID, userID)
	if err != nil {
		log.Printf("get application post=%s user=%s: %v", postID, userID, err)
		code, msg := store.ApplicationHTTPError(err)
		JSONError(c, code, msg)
		return
	}
	if !found || !store.IsActiveApplicationStatus(app.Status) {
		JSONOK(c, gin.H{"hasApplied": false})
		return
	}
	JSONOK(c, gin.H{
		"hasApplied":  true,
		"application": app,
		"status":      app.Status,
	})
}
