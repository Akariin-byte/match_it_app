// 用户模型与鉴权相关请求/响应 DTO
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User 用户实体（小红书式：先设备游客，后绑定升级）
type User struct {
	ID              uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	DeviceID        string     `gorm:"size:128;uniqueIndex;not null" json:"deviceId"`
	OpenID          *string    `gorm:"column:openid;size:128;uniqueIndex" json:"openid,omitempty"`
	IsGuest         bool       `gorm:"default:true;not null" json:"isGuest"`
	Username        string     `gorm:"size:64" json:"username"`
	Phone           *string    `gorm:"size:20;uniqueIndex" json:"phone,omitempty"`
	PhoneVerifiedAt *time.Time `json:"phoneVerifiedAt,omitempty"`
	AvatarURL       string     `gorm:"size:512" json:"avatarUrl,omitempty"`
	Status          string     `gorm:"size:16;default:active;not null" json:"status"`
	LastLoginAt     *time.Time `json:"lastLoginAt,omitempty"`
	CreatedAt       time.Time  `json:"createdAt"`
}

func (User) TableName() string { return "users" }

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	if u.Status == "" {
		u.Status = "active"
	}
	return nil
}

// PublicUser 对外返回的用户信息（手机号脱敏）
type PublicUser struct {
	ID              uuid.UUID  `json:"id"`
	DeviceID        string     `json:"deviceId,omitempty"`
	IsGuest         bool       `json:"isGuest"`
	Username        string     `json:"username"`
	Phone           string     `json:"phone,omitempty"`
	PhoneMasked     string     `json:"phoneMasked,omitempty"`
	PhoneVerifiedAt *time.Time `json:"phoneVerifiedAt,omitempty"`
	AvatarURL       string     `json:"avatarUrl,omitempty"`
	Status          string     `json:"status"`
	LastLoginAt     *time.Time `json:"lastLoginAt,omitempty"`
	CreatedAt       time.Time  `json:"createdAt"`
}

func PublicUserFrom(u User) PublicUser {
	pu := PublicUser{
		ID:              u.ID,
		IsGuest:         u.IsGuest,
		Username:        u.Username,
		PhoneVerifiedAt: u.PhoneVerifiedAt,
		AvatarURL:       u.AvatarURL,
		Status:          u.Status,
		LastLoginAt:     u.LastLoginAt,
		CreatedAt:       u.CreatedAt,
	}
	if u.IsGuest {
		pu.DeviceID = u.DeviceID
	}
	if u.Phone != nil {
		pu.Phone = *u.Phone
		pu.PhoneMasked = MaskPhone(*u.Phone)
	}
	return pu
}

func MaskPhone(phone string) string {
	if len(phone) < 7 {
		return phone
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}

// AuthTokenResponse 登录/绑定/刷新统一 Token 响应
type AuthTokenResponse struct {
	Token        string     `json:"token"`
	RefreshToken string     `json:"refreshToken"`
	ExpiresAt    time.Time  `json:"expiresAt"`
	User         PublicUser `json:"user"`
}

// PhoneStatusRequest POST /auth/phone-status
type PhoneStatusRequest struct {
	Phone string `json:"phone"`
}

// PhoneStatusResponse 查询手机号是否已注册（已注册返回昵称）
type PhoneStatusResponse struct {
	Registered bool   `json:"registered"`
	Username   string `json:"username,omitempty"`
}

// GuestLoginRequest POST /auth/guest-login
type GuestLoginRequest struct {
	DeviceID string `json:"device_id" binding:"required"`
	Username string `json:"username"`
}

// SendCodeRequest POST /auth/send-code
type SendCodeRequest struct {
	Phone string `json:"phone"`
	Scene string `json:"scene"` // bind | login
}

// SendCodeResponse POST /auth/send-code
type SendCodeResponse struct {
	Message   string `json:"message"`
	ExpiresIn int    `json:"expiresInSeconds"`
	Mock      bool   `json:"mock"`
}

// RegisterRequest POST /auth/register（未注册手机号，无需游客 Token）
type RegisterRequest struct {
	Phone            string `json:"phone"`
	VerificationCode string `json:"verification_code"`
	DeviceID         string `json:"device_id"`
	Username         string `json:"username"`
}

// BindPhoneRequest POST /auth/bind-phone
type BindPhoneRequest struct {
	Phone            string `json:"phone"`
	VerificationCode string `json:"verification_code"`
	Username         string `json:"username"`
}

// LoginRequest POST /auth/login（已注册手机号 + 验证码）
type LoginRequest struct {
	Phone            string `json:"phone"`
	VerificationCode string `json:"verification_code"`
	DeviceID         string `json:"device_id"` // 可选，换设备时关联
}

// RefreshRequest POST /auth/refresh
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// LogoutRequest POST /auth/logout
type LogoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// LogoutResponse POST /auth/logout
type LogoutResponse struct {
	Message string `json:"message"`
}

// MeResponse GET /me
type MeResponse struct {
	User PublicUser `json:"user"`
}
