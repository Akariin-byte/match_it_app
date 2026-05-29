package handler

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"

	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/push"
	"matchit/backend/api/internal/store"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

func (a *API) listPostComments(c *gin.Context) {
	postID := strings.TrimSpace(c.Param("id"))
	if postID == "" {
		JSONError(c, http.StatusBadRequest, "post id is required")
		return
	}
	if _, err := a.db.GetPost(c.Request.Context(), postID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			JSONError(c, http.StatusNotFound, "post not found")
			return
		}
		log.Printf("list comments get post %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to load post")
		return
	}
	comments, err := a.db.ListPostComments(c.Request.Context(), postID)
	if err != nil {
		log.Printf("list comments %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to list comments")
		return
	}
	JSONOK(c, gin.H{"data": comments, "total": len(comments)})
}

func (a *API) createPostComment(c *gin.Context) {
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

	var req model.CreatePostCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	ctx := c.Request.Context()
	if _, err := a.db.GetPost(ctx, postID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			JSONError(c, http.StatusNotFound, "post not found")
			return
		}
		log.Printf("create comment get post %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to load post")
		return
	}

	comment, meta, err := a.db.InsertPostComment(ctx, postID, userID, req.ParentID, req.Body)
	if err != nil {
		if errors.Is(err, store.ErrCommentInvalid) {
			JSONError(c, http.StatusBadRequest, "comment body is required")
			return
		}
		log.Printf("create comment %s: %v", postID, err)
		JSONError(c, http.StatusInternalServerError, "failed to create comment")
		return
	}

	parentID := strings.TrimSpace(req.ParentID)
	if parentID == "" {
		if meta.PostHostUserID != "" && meta.PostHostUserID != userID {
			_ = a.db.InsertCommentNotification(ctx, meta.PostHostUserID, postID, meta.CommentID, "post_comment")
			a.notifyCommentUser(ctx, meta.PostHostUserID, "post_comment", comment.AuthorUsername, meta.PostTitle, comment.Body, postID)
		}
	} else if meta.ParentAuthorID != "" && meta.ParentAuthorID != userID {
		_ = a.db.InsertCommentNotification(ctx, meta.ParentAuthorID, postID, meta.CommentID, "comment_reply")
		a.notifyCommentUser(ctx, meta.ParentAuthorID, "comment_reply", comment.AuthorUsername, meta.PostTitle, comment.Body, postID)
	}

	JSONOK(c, gin.H{"data": comment})
}

func (a *API) notifyCommentUser(
	ctx context.Context,
	targetUserID, kind, actorName, postTitle, body, postID string,
) {
	if a.fcm == nil || !a.fcm.Enabled() {
		return
	}
	tokens, err := a.db.ListDeviceTokens(ctx, targetUserID)
	if err != nil || len(tokens) == 0 {
		return
	}
	title := store.CommentNotificationTitle(kind, actorName, postTitle)
	preview := store.CommentNotificationPreview(body)
	push.NotifyTokens(ctx, a.fcm, tokens, title, preview, map[string]string{
		"type":   "post_comment",
		"postId": postID,
		"kind":   kind,
	})
}

func (a *API) listMyCommentNotifications(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	items, err := a.db.ListCommentNotifications(c.Request.Context(), userID)
	if err != nil {
		log.Printf("list comment notifications user=%s: %v", userID, err)
		JSONError(c, http.StatusInternalServerError, "failed to list notifications")
		return
	}
	unread, _ := a.db.CountUnreadCommentNotifications(c.Request.Context(), userID)
	JSONOK(c, gin.H{
		"data":         items,
		"total":        len(items),
		"unreadCount":  unread,
	})
}

func (a *API) markCommentNotificationRead(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		JSONError(c, http.StatusBadRequest, "notification id is required")
		return
	}
	if err := a.db.MarkCommentNotificationRead(c.Request.Context(), userID, id); err != nil {
		if errors.Is(err, store.ErrCommentNotFound) {
			JSONError(c, http.StatusNotFound, "notification not found")
			return
		}
		log.Printf("mark comment notification read %s: %v", id, err)
		JSONError(c, http.StatusInternalServerError, "failed to update notification")
		return
	}
	JSONOK(c, gin.H{"ok": true})
}
