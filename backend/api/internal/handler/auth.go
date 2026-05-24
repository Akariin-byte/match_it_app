package handler

import (
	"errors"
	"log"
	"net/http"
	"regexp"
	"strings"

	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/store"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var phonePattern = regexp.MustCompile(`^1[3-9]\d{9}$`)

// GuestLogin 游客登录：无需密码，创建临时身份并返回 JWT
func (a *API) GuestLogin(c *gin.Context) {
	openid := "guest_" + uuid.NewString()

	user, err := a.db.CreateGuestUser(c.Request.Context(), openid)
	if err != nil {
		log.Printf("guest login: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create guest user"})
		return
	}

	token, expiresAt, err := a.jwt.Issue(user.ID, user.OpenID, user.IsGuest)
	if err != nil {
		log.Printf("guest login token: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue token"})
		return
	}

	c.JSON(http.StatusOK, model.GuestLoginResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      user,
	})
}

// BindPhone 绑定手机号：用游客 Token 将临时身份升级为正式用户
func (a *API) BindPhone(c *gin.Context) {
	var req model.BindPhoneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json body"})
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid phone number"})
		return
	}

	userID, _ := c.Get(middleware.ContextUserID)
	userIDStr, _ := userID.(string)

	user, err := a.db.BindPhone(c.Request.Context(), userIDStr, phone)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrUserNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		case errors.Is(err, store.ErrNotGuestUser):
			c.JSON(http.StatusConflict, gin.H{"error": "account already registered"})
		case errors.Is(err, store.ErrPhoneAlreadyBound):
			c.JSON(http.StatusConflict, gin.H{"error": "phone already in use"})
		default:
			log.Printf("bind phone: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to bind phone"})
		}
		return
	}

	token, expiresAt, err := a.jwt.Issue(user.ID, user.OpenID, user.IsGuest)
	if err != nil {
		log.Printf("bind phone token: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to issue token"})
		return
	}

	c.JSON(http.StatusOK, model.BindPhoneResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      user,
	})
}

// Me 示例：演示 JWT 中间件注入的用户身份
func (a *API) Me(c *gin.Context) {
	userID, _ := c.Get(middleware.ContextUserID)
	openid, _ := c.Get(middleware.ContextOpenID)
	isGuest, _ := c.Get(middleware.ContextIsGuest)

	c.JSON(http.StatusOK, gin.H{
		"userId":  userID,
		"openid":  openid,
		"isGuest": isGuest,
	})
}
