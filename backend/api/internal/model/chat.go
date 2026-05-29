package model

import "time"

type ChatMessage struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversationId"`
	SenderID       string    `json:"senderId"`
	ClientID       string    `json:"clientId"`
	Seq            int64     `json:"seq"`
	Body           string    `json:"body"`
	CreatedAt      time.Time `json:"createdAt"`
}

type ConversationPeer struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
}

type ConversationItem struct {
	ID          string           `json:"id"`
	Type        string           `json:"type"`
	PostID      string           `json:"postId,omitempty"`
	OtherUser   ConversationPeer `json:"otherUser"`
	LastMessage *ChatMessage     `json:"lastMessage,omitempty"`
	UnreadCount int64            `json:"unreadCount"`
	UpdatedAt   time.Time        `json:"updatedAt"`
}

type CreateDMPayload struct {
	PeerUserID string `json:"peerUserId"`
	PostID     string `json:"postId,omitempty"`
}

type RegisterDeviceTokenPayload struct {
	Platform string `json:"platform"`
	Token    string `json:"token"`
}

type WSSendPayload struct {
	Type           string `json:"type"`
	ConversationID string `json:"conversationId"`
	ClientID       string `json:"clientId"`
	Body           string `json:"body"`
}

type WSMessagePayload struct {
	Type    string      `json:"type"`
	Message ChatMessage `json:"message"`
}

type WSAckPayload struct {
	Type     string      `json:"type"`
	ClientID string      `json:"clientId"`
	Message  ChatMessage `json:"message"`
}

type WSErrorPayload struct {
	Type     string `json:"type"`
	ClientID string `json:"clientId,omitempty"`
	Error    string `json:"error"`
}
