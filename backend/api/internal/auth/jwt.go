// JWT 签发与解析：Token 内携带 user_id、is_guest，供 AuthMiddleware 使用。
package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims JWT 载荷，与中间件注入 Context 的字段一致
type Claims struct {
	UserID  string `json:"user_id"`  // 用户 UUID
	OpenID  string `json:"openid"`     // 第三方绑定标识（微信等），游客可为空
	IsGuest bool   `json:"is_guest"`   // true=游客，false=已绑定手机
	jwt.RegisteredClaims
}

// JWT 令牌管理器
type JWT struct {
	secret    []byte
	guestTTL  time.Duration // 游客 Token 有效期
	memberTTL time.Duration // 正式用户 Token 有效期
}

// NewJWT 创建 JWT 管理器，secret 来自环境变量 JWT_SECRET
func NewJWT(secret string, guestTTL, memberTTL time.Duration) (*JWT, error) {
	if secret == "" {
		return nil, fmt.Errorf("JWT secret is required")
	}
	if guestTTL <= 0 {
		guestTTL = 30 * 24 * time.Hour
	}
	if memberTTL <= 0 {
		memberTTL = 7 * 24 * time.Hour
	}
	return &JWT{
		secret:    []byte(secret),
		guestTTL:  guestTTL,
		memberTTL: memberTTL,
	}, nil
}

// Issue 签发 Token，游客与正式用户使用不同时长
func (j *JWT) Issue(userID, openid string, isGuest bool) (token string, expiresAt time.Time, err error) {
	ttl := j.memberTTL
	if isGuest {
		ttl = j.guestTTL
	}
	expiresAt = time.Now().UTC().Add(ttl)
	claims := Claims{
		UserID:  userID,
		OpenID:  openid,
		IsGuest: isGuest,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now().UTC()),
			Issuer:    "matchit-api",
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := t.SignedString(j.secret)
	return signed, expiresAt, err
}

// Parse 校验并解析 Bearer Token
func (j *JWT) Parse(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if token.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return j.secret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}
