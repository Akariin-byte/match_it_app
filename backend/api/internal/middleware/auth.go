// Gin 鉴权中间件：解析 JWT，向 Context 注入 user_id / is_guest
package middleware

import (
	"net/http"
	"strings"

	"matchit/backend/api/internal/auth"

	"github.com/gin-gonic/gin"
)

// Context 键名，Handler 中通过 c.Get(ContextUserID) 或 GetUserID(c) 读取
const (
	ContextUserID      = "user_id"
	ContextIsGuest     = "is_guest"
	ContextOpenID      = "openid"
	ContextAccessToken = "access_token"
	ContextTokenExpiry = "token_expiry"
)

// AuthMiddleware 校验 Authorization: Bearer <token>，注入用户身份
func AuthMiddleware(jwtMgr *auth.JWT, denylist *auth.TokenDenylist) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractBearer(c.GetHeader("Authorization"))
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization token"})
			return
		}

		if denylist != nil {
			denied, err := denylist.IsDenied(c.Request.Context(), token)
			if err != nil {
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "auth check failed"})
				return
			}
			if denied {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token revoked"})
				return
			}
		}

		claims, err := jwtMgr.Parse(token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}

		c.Set(ContextUserID, claims.UserID)
		c.Set(ContextIsGuest, claims.IsGuest)
		c.Set(ContextOpenID, claims.OpenID)
		c.Set(ContextAccessToken, token)
		if claims.ExpiresAt != nil {
			c.Set(ContextTokenExpiry, claims.ExpiresAt.Time)
		}
		c.Next()
	}
}

// JWTAuth AuthMiddleware 别名，兼容旧引用
func JWTAuth(jwtMgr *auth.JWT) gin.HandlerFunc {
	return AuthMiddleware(jwtMgr, nil)
}

// GuestOnly 仅允许游客访问（如 bind-phone 升级流程）
func GuestOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isGuestFromContext(c) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "guest account required"})
			return
		}
		c.Next()
	}
}

// RegisteredOnly 仅允许正式用户（isGuest=false）；游客访问返回 403
func RegisteredOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, ok := GetUserID(c); !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
			return
		}
		if isGuestFromContext(c) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":   "registered_account_required",
				"message": "请先绑定手机号后再进行此操作",
				"action":  "bind_phone",
			})
			return
		}
		c.Next()
	}
}

// GetUserID 读取当前操作者 ID，需先经过 AuthMiddleware
func GetUserID(c *gin.Context) (string, bool) {
	raw, ok := c.Get(ContextUserID)
	if !ok {
		return "", false
	}
	id, ok := raw.(string)
	return id, ok && id != ""
}

// IsGuest 当前用户是否为游客
func IsGuest(c *gin.Context) bool {
	return isGuestFromContext(c)
}

func isGuestFromContext(c *gin.Context) bool {
	raw, ok := c.Get(ContextIsGuest)
	if !ok {
		return true
	}
	isGuest, ok := raw.(bool)
	return !ok || isGuest
}

func extractBearer(header string) string {
	header = strings.TrimSpace(header)
	if header == "" {
		return ""
	}
	const prefix = "Bearer "
	if len(header) > len(prefix) && strings.EqualFold(header[:len(prefix)], prefix) {
		return strings.TrimSpace(header[len(prefix):])
	}
	return header
}
