package model

import "time"

// PostMember 组局已加入成员（主理人 + 已通过申请的用户）
type PostMember struct {
	UserID   string    `json:"userId,omitempty"`
	Username string    `json:"username"`
	Role     string    `json:"role"` // host | member
	JoinedAt time.Time `json:"joinedAt,omitempty"`
}
