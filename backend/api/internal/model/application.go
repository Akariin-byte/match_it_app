package model

import "time"

// PostApplication 用户对组局帖的申请记录
type PostApplication struct {
	ID        string    `json:"id"`
	PostID    string    `json:"postId"`
	UserID    string    `json:"userId"`
	Status        string    `json:"status"`
	Message       string    `json:"message,omitempty"`
	WechatContact string    `json:"wechatContact,omitempty"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// ApplyPostRequest POST /posts/:id/apply
type ApplyPostRequest struct {
	WechatContact string `json:"wechatContact"`
	Message       string `json:"message"`
}

// PostApplicationItem 消息中心 · 我发出的申请（含帖子摘要）
type PostApplicationItem struct {
	PostApplication
	PostTitle      string `json:"postTitle"`
	PostArea       string `json:"postArea"`
	HostNickname   string `json:"hostNickname"`
	EventLocation  string `json:"eventLocation,omitempty"`
}

// ReceivedApplicationItem 消息中心 · 我收到的申请（主理人视角，需登录）
// ApplicantPhoneMasked 仅主理人审核 pending 申请时用于辅助识别，不向其他用户或公开接口暴露。
type ReceivedApplicationItem struct {
	PostApplication
	PostTitle            string `json:"postTitle"`
	PostArea             string `json:"postArea"`
	ApplicantUsername    string `json:"applicantUsername"`
	ApplicantPhoneMasked string `json:"applicantPhoneMasked"`
}
