package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	UserID  string `json:"user_id"`
	OpenID  string `json:"openid"`
	IsGuest bool   `json:"is_guest"`
	jwt.RegisteredClaims
}

type JWT struct {
	secret     []byte
	guestTTL   time.Duration
	memberTTL  time.Duration
}

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
