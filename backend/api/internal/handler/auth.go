// 鉴权相关 HTTP Handler：游客登录、绑定手机、当前用户
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
)

func openIDString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}

var phonePattern = regexp.MustCompile(`^1[3-9]\d{9}$`)

// GuestLogin 游客登录：按 device_id 查找或创建，返回 JWT
func (a *API) GuestLogin(c *gin.Context) {
	var req model.GuestLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "device_id is required")
		return
	}

	deviceID := strings.TrimSpace(req.DeviceID)
	if deviceID == "" {
		JSONError(c, http.StatusBadRequest, "device_id is required")
		return
	}

	user, err := a.users.FindOrCreateGuestUser(deviceID, req.Username)
	if err != nil {
		log.Printf("guest-login: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to find or create guest user")
		return
	}

	token, expiresAt, err := a.jwt.Issue(user.ID.String(), openIDString(user.OpenID), user.IsGuest)
	if err != nil {
		log.Printf("guest-login token: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to issue token")
		return
	}

	JSONOK(c, model.GuestLoginResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
	})
}

// BindPhone 绑定手机号：需游客 Token，成功后 isGuest=false 并重签 JWT
func (a *API) BindPhone(c *gin.Context) {
	var req model.BindPhoneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		JSONError(c, http.StatusBadRequest, "invalid phone number")
		return
	}

	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	user, err := a.users.BindPhone(userID, phone, req.Username)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrUserNotFound):
			JSONError(c, http.StatusNotFound, "user not found")
		case errors.Is(err, store.ErrNotGuestUser):
			JSONError(c, http.StatusConflict, "account already registered")
		case errors.Is(err, store.ErrPhoneAlreadyBound):
			JSONError(c, http.StatusConflict, "phone already in use")
		default:
			log.Printf("bind phone: %v", err)
			JSONError(c, http.StatusInternalServerError, "failed to bind phone")
		}
		return
	}

	token, expiresAt, err := a.jwt.Issue(user.ID.String(), openIDString(user.OpenID), user.IsGuest)
	if err != nil {
		log.Printf("bind phone token: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to issue token")
		return
	}

	JSONOK(c, model.BindPhoneResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		User:      *user,
	})
}

// Me 返回当前 Token 对应的用户身份（演示 Context 注入）
func (a *API) Me(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	JSONOK(c, gin.H{
		"userId":  userID,
		"isGuest": middleware.IsGuest(c),
	})
}
