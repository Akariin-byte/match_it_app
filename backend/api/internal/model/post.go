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
	MatchScore       float64   `json:"matchScore"`
	HostNickname     string    `json:"hostNickname"`
	HostCreditScore  int       `json:"hostCreditScore"`
	EventDateTime    time.Time `json:"eventDateTime"`
	EventLocation    string    `json:"eventLocation"`
	CostType         string    `json:"costType,omitempty"`
	Amount           *float64  `json:"amount,omitempty"`
	IsPinned         bool      `json:"isPinned"`
	PinPriority      int       `json:"pinPriority"`
}

type CreatePostRequest struct {
	MatchPost
}

type ListPostsQuery struct {
	Area string
	Tab  string
}
