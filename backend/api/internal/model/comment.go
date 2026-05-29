package model

import "time"

type PostComment struct {
	ID               string    `json:"id"`
	PostID           string    `json:"postId"`
	ParentID         string    `json:"parentId,omitempty"`
	Body             string    `json:"body"`
	AuthorUserID     string    `json:"authorUserId"`
	AuthorUsername   string    `json:"authorUsername"`
	RoleBadge        string    `json:"roleBadge,omitempty"`
	ReplyToUsername  string    `json:"replyToUsername,omitempty"`
	CreatedAt        time.Time `json:"createdAt"`
}

type CreatePostCommentRequest struct {
	Body     string `json:"body"`
	ParentID string `json:"parentId,omitempty"`
}

type CommentNotification struct {
	ID              string    `json:"id"`
	Kind            string    `json:"kind"`
	PostID          string    `json:"postId"`
	PostTitle       string    `json:"postTitle"`
	CommentID       string    `json:"commentId"`
	CommentBody     string    `json:"commentBody"`
	ActorUsername   string    `json:"actorUsername"`
	IsRead          bool      `json:"isRead"`
	CreatedAt       time.Time `json:"createdAt"`
}
