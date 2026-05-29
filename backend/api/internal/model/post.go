package model

import "time"

// MatchPost 与 Flutter lib/main.dart 中 MatchPost 字段对齐（JSON camelCase）
type MatchPost struct {
	ID               string    `json:"id"`
	Title            string    `json:"title"`
	Description      string    `json:"description"`
	CurrentMembers   int       `json:"currentMembers"`
	MaxMembers       int       `json:"maxMembers"`
	MaxPeople        int       `json:"maxPeople"`
	Area             string    `json:"area"`
	Tab              string    `json:"tab"`
	HardcoreScore    int       `json:"hardcoreScore"`
	HostFaceTraits   []string  `json:"hostFaceTraits"`
	InteractionCount int       `json:"interactionCount"`
	LastActiveTime   time.Time `json:"lastActiveTime"`
	CreatedAt        time.Time `json:"createdAt"`
	MatchScore       float64   `json:"matchScore"`
	HostUserID       string    `json:"hostUserId,omitempty"`
	HostNickname     string    `json:"hostNickname"`
	HostCreditScore  int       `json:"hostCreditScore"`
	EventDateTime    time.Time `json:"eventDateTime"`
	EventLocation    string    `json:"eventLocation"`
	CostType         string    `json:"costType,omitempty"`
	Amount           *float64  `json:"amount,omitempty"`
	IsPinned          bool   `json:"isPinned"`
	PinPriority       int    `json:"pinPriority"`
	HasApplied        bool   `json:"hasApplied,omitempty"`
	ApplicationStatus string `json:"applicationStatus,omitempty"`
}

// CreatePostPayload 发布页单框内容 + 结构化字段（title 由服务端从 content 生成）
type CreatePostPayload struct {
	Content       string     `json:"content"`
	Area          string     `json:"area"`
	MaxPeople     int        `json:"maxPeople"`
	CostType      string     `json:"costType,omitempty"`
	Amount        *float64   `json:"amount,omitempty"`
	EventDateTime *time.Time `json:"eventDateTime,omitempty"`
	EventLocation string     `json:"eventLocation,omitempty"`
	Tags          []string   `json:"tags,omitempty"`
	Tab           string     `json:"tab,omitempty"`
	HardcoreScore *int       `json:"hardcoreScore,omitempty"`
}

// CreatePostRequest 兼容旧客户端整帖 JSON（保留给 seed / 调试）
type CreatePostRequest struct {
	MatchPost
}

type ListPostsQuery struct {
	Area string
	Tab  string
}
