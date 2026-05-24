// 用户模型与鉴权相关请求/响应 DTO
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User 用户实体（小红书式：先设备游客，后绑定升级）
type User struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	DeviceID  string    `gorm:"size:128;uniqueIndex;not null" json:"deviceId"` // 设备唯一标识，同一设备只对应一个账号
	OpenID    *string   `gorm:"column:openid;size:128;uniqueIndex" json:"openid,omitempty"`
	IsGuest   bool      `gorm:"default:true;not null" json:"isGuest"` // 默认游客
	Username  string    `gorm:"size:64" json:"username"`
	Phone     *string   `gorm:"size:20;uniqueIndex" json:"phone,omitempty"` // 绑定后写入
	CreatedAt time.Time `json:"createdAt"`
}

func (User) TableName() string { return "users" }

// BeforeCreate 插入前自动生成 UUID
func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}

// GuestLoginRequest POST /auth/guest-login 请求体
type GuestLoginRequest struct {
	DeviceID string `json:"device_id" binding:"required"`
	Username string `json:"username"` // 可选，登录页 Name 字段
}

// GuestLoginResponse 游客登录响应
type GuestLoginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	User      User      `json:"user"`
}

// BindPhoneRequest POST /auth/bind-phone 请求体
type BindPhoneRequest struct {
	Phone    string `json:"phone"`
	Username string `json:"username"` // 可选，补全昵称
}

// BindPhoneResponse 绑定手机响应（含新 Token，isGuest=false）
type BindPhoneResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	User      User      `json:"user"`
}
