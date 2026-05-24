package model

import "time"

// User 用户实体（先体验、后绑定）
type User struct {
	ID        string    `json:"id"`
	OpenID    string    `json:"openid"`
	Phone     *string   `json:"phone,omitempty"`
	IsGuest   bool      `json:"isGuest"`
	Nickname  string    `json:"nickname,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type GuestLoginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	User      User      `json:"user"`
}

type BindPhoneRequest struct {
	Phone string `json:"phone"`
}

type BindPhoneResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	User      User      `json:"user"`
}
