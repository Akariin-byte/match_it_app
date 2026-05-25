// 鉴权相关 HTTP Handler：游客登录、发码、绑定、登录、刷新、当前用户
package handler

import (
	"errors"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"matchit/backend/api/internal/auth"
	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/sms"
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

// GuestLogin 游客登录：按 device_id 查找或创建，返回 JWT + Refresh Token
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

	a.respondAuthTokens(c, user)
}

// PhoneStatus 查询手机号是否已注册（已注册返回服务端昵称）
func (a *API) PhoneStatus(c *gin.Context) {
	var req model.PhoneStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		JSONError(c, http.StatusBadRequest, "invalid phone number")
		return
	}

	user, err := a.users.FindByPhone(phone)
	if err != nil {
		if errors.Is(err, store.ErrPhoneNotRegistered) {
			JSONOK(c, model.PhoneStatusResponse{Registered: false})
			return
		}
		log.Printf("phone-status: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to check phone")
		return
	}

	if user.IsGuest {
		JSONOK(c, model.PhoneStatusResponse{Registered: false})
		return
	}

	JSONOK(c, model.PhoneStatusResponse{
		Registered: true,
		Username:   user.Username,
	})
}

// SendCode 发送短信验证码（bind / login 场景）
func (a *API) SendCode(c *gin.Context) {
	var req model.SendCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		JSONError(c, http.StatusBadRequest, "invalid phone number")
		return
	}

	scene := sms.Scene(strings.TrimSpace(req.Scene))
	if !scene.Valid() {
		JSONError(c, http.StatusBadRequest, "scene must be bind or login")
		return
	}

	if err := a.sms.SendCode(c.Request.Context(), phone, scene); err != nil {
		switch {
		case errors.Is(err, sms.ErrTooManyRequests):
			JSONErrorDetail(c, http.StatusTooManyRequests, "too_many_requests", "请稍后再试", "")
		default:
			log.Printf("send-code: %v", err)
			JSONError(c, http.StatusInternalServerError, "failed to send verification code")
		}
		return
	}

	JSONOK(c, model.SendCodeResponse{
		Message:   "verification code sent",
		ExpiresIn: int(a.smsCodeTTL.Seconds()),
		Mock:      a.smsMock,
	})
}

// BindPhone 游客绑定手机号：验证码校验后 isGuest=false 并重签 JWT
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

	code := strings.TrimSpace(req.VerificationCode)
	if code == "" {
		JSONError(c, http.StatusBadRequest, "verification_code is required")
		return
	}

	if err := a.sms.VerifyAuthCode(c.Request.Context(), phone, code); err != nil {
		a.writeSMSVerifyError(c, err)
		return
	}

	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	// 手机号已注册 → 直接登录已有账号（小红书式「登录/注册」合一）
	if existing, err := a.users.FindByPhone(phone); err == nil {
		if !existing.IsGuest {
			_ = a.users.TouchLastLogin(existing.ID.String())
			a.respondAuthTokens(c, existing)
			return
		}
		JSONErrorDetail(c, http.StatusConflict, "phone_already_registered", "该手机号已注册，请直接登录", "login")
		return
	} else if !errors.Is(err, store.ErrPhoneNotRegistered) {
		log.Printf("bind phone lookup: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to bind phone")
		return
	}

	user, err := a.users.BindPhone(userID, phone, req.Username)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrUserNotFound):
			JSONError(c, http.StatusNotFound, "user not found")
		case errors.Is(err, store.ErrNotGuestUser):
			JSONErrorDetail(c, http.StatusConflict, "account_already_registered", "账号已注册", "login")
		case errors.Is(err, store.ErrPhoneAlreadyBound):
			JSONErrorDetail(c, http.StatusConflict, "phone_already_registered", "该手机号已注册，请直接登录", "login")
		default:
			log.Printf("bind phone: %v", err)
			JSONError(c, http.StatusInternalServerError, "failed to bind phone")
		}
		return
	}

	a.respondAuthTokens(c, user)
}

// RegisterPhone 未注册手机号 + 验证码注册（欢迎页直注册，无需游客 Token）
func (a *API) RegisterPhone(c *gin.Context) {
	var req model.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		JSONError(c, http.StatusBadRequest, "invalid phone number")
		return
	}

	code := strings.TrimSpace(req.VerificationCode)
	if code == "" {
		JSONError(c, http.StatusBadRequest, "verification_code is required")
		return
	}

	deviceID := strings.TrimSpace(req.DeviceID)
	if deviceID == "" {
		JSONError(c, http.StatusBadRequest, "device_id is required")
		return
	}

	if err := a.sms.VerifyAuthCode(c.Request.Context(), phone, code); err != nil {
		a.writeSMSVerifyError(c, err)
		return
	}

	if existing, err := a.users.FindByPhone(phone); err == nil {
		if !existing.IsGuest {
			_ = a.users.TouchLastLogin(existing.ID.String())
			a.respondAuthTokens(c, existing)
			return
		}
		// 手机号已挂在游客账号上：验证码通过后直接升级为正式用户
		user, bindErr := a.users.BindPhone(existing.ID.String(), phone, req.Username)
		if bindErr != nil {
			log.Printf("register upgrade guest: %v", bindErr)
			JSONError(c, http.StatusInternalServerError, "failed to register")
			return
		}
		a.respondAuthTokens(c, user)
		return
	} else if !errors.Is(err, store.ErrPhoneNotRegistered) {
		log.Printf("register phone lookup: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to register")
		return
	}

	user, err := a.users.RegisterByPhone(deviceID, phone, req.Username)
	if err != nil {
		if errors.Is(err, store.ErrPhoneAlreadyBound) {
			JSONErrorDetail(c, http.StatusConflict, "phone_already_registered", "该手机号已注册，请直接登录", "login")
			return
		}
		log.Printf("register: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to register")
		return
	}

	a.respondAuthTokens(c, user)
}

// Login 已注册手机号 + 验证码登录（换设备场景）
func (a *API) Login(c *gin.Context) {
	var req model.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		JSONError(c, http.StatusBadRequest, "invalid phone number")
		return
	}

	code := strings.TrimSpace(req.VerificationCode)
	if code == "" {
		JSONError(c, http.StatusBadRequest, "verification_code is required")
		return
	}

	if err := a.sms.VerifyAuthCode(c.Request.Context(), phone, code); err != nil {
		a.writeSMSVerifyError(c, err)
		return
	}

	user, err := a.users.FindByPhone(phone)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrPhoneNotRegistered):
			JSONErrorDetail(c, http.StatusNotFound, "phone_not_registered", "该手机号尚未注册，请先绑定", "bind_phone")
		default:
			log.Printf("login find phone: %v", err)
			JSONError(c, http.StatusInternalServerError, "failed to login")
		}
		return
	}
	if user.IsGuest {
		JSONErrorDetail(c, http.StatusConflict, "account_not_registered", "账号未完成绑定", "bind_phone")
		return
	}
	if user.Status != "" && user.Status != "active" {
		JSONError(c, http.StatusForbidden, "account unavailable")
		return
	}

	_ = a.users.TouchLastLogin(user.ID.String())
	a.respondAuthTokens(c, user)
}

// Refresh 用 Refresh Token 换取新的 Access + Refresh Token
func (a *API) Refresh(c *gin.Context) {
	var req model.RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}

	token := strings.TrimSpace(req.RefreshToken)
	if token == "" {
		JSONError(c, http.StatusBadRequest, "refresh_token is required")
		return
	}

	userID, err := a.refresh.Consume(c.Request.Context(), token)
	if err != nil {
		if errors.Is(err, auth.ErrRefreshTokenInvalid) {
			JSONError(c, http.StatusUnauthorized, "invalid or expired refresh token")
			return
		}
		log.Printf("refresh: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to refresh token")
		return
	}

	user, err := a.users.GetUserByID(userID)
	if err != nil {
		JSONError(c, http.StatusUnauthorized, "user not found")
		return
	}

	a.respondAuthTokens(c, user)
}

// Me 返回当前 Token 对应的完整用户信息
func (a *API) Me(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}

	user, err := a.users.GetUserByID(userID)
	if err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			JSONError(c, http.StatusNotFound, "user not found")
			return
		}
		log.Printf("me: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to load user")
		return
	}

	JSONOK(c, model.MeResponse{User: model.PublicUserFrom(*user)})
}

// Logout 退出登录：吊销 Refresh Token，短期拉黑当前 Access Token
func (a *API) Logout(c *gin.Context) {
	var req model.LogoutRequest
	_ = c.ShouldBindJSON(&req)

	refreshToken := strings.TrimSpace(req.RefreshToken)
	if refreshToken != "" {
		if err := a.refresh.Revoke(c.Request.Context(), refreshToken); err != nil {
			log.Printf("logout revoke refresh: %v", err)
		}
	}

	if raw, ok := c.Get(middleware.ContextAccessToken); ok {
		if accessToken, ok := raw.(string); ok && accessToken != "" {
			ttl := time.Until(tokenExpiryFromContext(c))
			if ttl > 0 {
				if err := a.denylist.Deny(c.Request.Context(), accessToken, ttl); err != nil {
					log.Printf("logout deny access: %v", err)
				}
			}
		}
	}

	JSONOK(c, model.LogoutResponse{Message: "logged out"})
}

func tokenExpiryFromContext(c *gin.Context) time.Time {
	raw, ok := c.Get(middleware.ContextTokenExpiry)
	if !ok {
		return time.Time{}
	}
	expiry, ok := raw.(time.Time)
	if !ok {
		return time.Time{}
	}
	return expiry
}

func (a *API) respondAuthTokens(c *gin.Context, user *model.User) {
	token, expiresAt, err := a.jwt.Issue(user.ID.String(), openIDString(user.OpenID), user.IsGuest)
	if err != nil {
		log.Printf("issue token: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to issue token")
		return
	}

	refreshToken, err := a.refresh.Issue(c.Request.Context(), user.ID.String())
	if err != nil {
		log.Printf("issue refresh: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to issue refresh token")
		return
	}

	JSONOK(c, model.AuthTokenResponse{
		Token:        token,
		RefreshToken: refreshToken,
		ExpiresAt:    expiresAt,
		User:         model.PublicUserFrom(*user),
	})
}

func (a *API) writeSMSVerifyError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, sms.ErrCodeExpired):
		JSONError(c, http.StatusBadRequest, "verification code expired or not sent")
	case errors.Is(err, sms.ErrCodeInvalid):
		JSONError(c, http.StatusBadRequest, "invalid verification code")
	case errors.Is(err, sms.ErrTooManyFailures):
		JSONErrorDetail(c, http.StatusTooManyRequests, "too_many_failures", "验证码错误次数过多，请稍后再试", "")
	default:
		log.Printf("sms verify: %v", err)
		JSONError(c, http.StatusInternalServerError, "failed to verify code")
	}
}
