package middleware

import (
	"net/http"
	"strings"

	"matchit/backend/api/internal/auth"

	"github.com/gin-gonic/gin"
)

const (
	ContextUserID  = "user_id"
	ContextOpenID  = "openid"
	ContextIsGuest = "is_guest"
)

func JWTAuth(jwtMgr *auth.JWT) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractBearer(c.GetHeader("Authorization"))
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization token"})
			return
		}

		claims, err := jwtMgr.Parse(token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}

		c.Set(ContextUserID, claims.UserID)
		c.Set(ContextOpenID, claims.OpenID)
		c.Set(ContextIsGuest, claims.IsGuest)
		c.Next()
	}
}

// GuestOnly 仅允许游客身份访问（用于 BindPhone 升级流程）
func GuestOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		raw, ok := c.Get(ContextIsGuest)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
			return
		}
		isGuest, ok := raw.(bool)
		if !ok || !isGuest {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "guest account required"})
			return
		}
		c.Next()
	}
}

// RegisteredOnly 仅允许已绑定手机号的正式用户
func RegisteredOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		raw, ok := c.Get(ContextIsGuest)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
			return
		}
		isGuest, ok := raw.(bool)
		if !ok || isGuest {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "registered account required"})
			return
		}
		c.Next()
	}
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
