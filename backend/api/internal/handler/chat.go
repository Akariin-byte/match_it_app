package handler

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"matchit/backend/api/internal/middleware"
	"matchit/backend/api/internal/model"
	"matchit/backend/api/internal/push"
	"matchit/backend/api/internal/store"
	"matchit/backend/api/internal/ws"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var chatUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func (a *API) listConversations(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	items, err := a.db.ListConversations(c.Request.Context(), userID)
	if err != nil {
		log.Printf("list conversations user=%s: %v", userID, err)
		JSONError(c, http.StatusInternalServerError, "failed to list conversations")
		return
	}
	if items == nil {
		items = []model.ConversationItem{}
	}
	JSONOK(c, gin.H{"data": items, "total": len(items)})
}

func (a *API) createOrGetDM(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	var req model.CreateDMPayload
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}
	peer := strings.TrimSpace(req.PeerUserID)
	if peer == "" {
		JSONError(c, http.StatusBadRequest, "peerUserId is required")
		return
	}
	convID, err := a.db.GetOrCreateDM(c.Request.Context(), userID, peer, req.PostID)
	if err != nil {
		log.Printf("create dm user=%s peer=%s: %v", userID, peer, err)
		JSONError(c, http.StatusInternalServerError, "failed to create conversation")
		return
	}
	JSONOK(c, gin.H{"conversationId": convID})
}

func (a *API) listConversationMessages(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	convID := strings.TrimSpace(c.Param("id"))
	beforeSeq, _ := strconv.ParseInt(c.Query("before_seq"), 10, 64)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))

	msgs, err := a.db.ListConversationMessages(c.Request.Context(), convID, userID, beforeSeq, limit)
	if err != nil {
		if errors.Is(err, store.ErrNotConversationMember) {
			JSONError(c, http.StatusForbidden, "not a member")
			return
		}
		log.Printf("list messages conv=%s user=%s: %v", convID, userID, err)
		JSONError(c, http.StatusInternalServerError, "failed to list messages")
		return
	}
	if msgs == nil {
		msgs = []model.ChatMessage{}
	}
	JSONOK(c, gin.H{"data": msgs, "total": len(msgs)})
}

func (a *API) markConversationRead(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	convID := strings.TrimSpace(c.Param("id"))
	var body struct {
		Seq int64 `json:"seq"`
	}
	_ = c.ShouldBindJSON(&body)
	if body.Seq <= 0 {
		JSONError(c, http.StatusBadRequest, "seq is required")
		return
	}
	if err := a.db.MarkConversationRead(c.Request.Context(), convID, userID, body.Seq); err != nil {
		JSONError(c, http.StatusInternalServerError, "failed to mark read")
		return
	}
	JSONOK(c, gin.H{"ok": true})
}

func (a *API) registerDeviceToken(c *gin.Context) {
	userID, ok := middleware.GetUserID(c)
	if !ok {
		JSONError(c, http.StatusUnauthorized, "authentication required")
		return
	}
	var req model.RegisterDeviceTokenPayload
	if err := c.ShouldBindJSON(&req); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid json body")
		return
	}
	if err := a.db.UpsertDeviceToken(c.Request.Context(), userID, req.Platform, req.Token); err != nil {
		JSONError(c, http.StatusBadRequest, "invalid token")
		return
	}
	JSONOK(c, gin.H{"ok": true})
}

func (a *API) chatWebSocketEntry(c *gin.Context) {
	token := strings.TrimSpace(c.GetHeader("Authorization"))
	if strings.HasPrefix(strings.ToLower(token), "bearer ") {
		token = strings.TrimSpace(token[7:])
	}
	if token == "" {
		token = strings.TrimSpace(c.Query("token"))
	}
	if token == "" {
		c.AbortWithStatus(http.StatusUnauthorized)
		return
	}

	if a.denylist != nil {
		denied, err := a.denylist.IsDenied(c.Request.Context(), token)
		if err != nil || denied {
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}
	}

	claims, err := a.jwt.Parse(token)
	if err != nil {
		c.AbortWithStatus(http.StatusUnauthorized)
		return
	}
	if claims.IsGuest {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "registered_account_required"})
		return
	}

	conn, err := chatUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("ws upgrade: %v", err)
		return
	}

	client := ws.NewClient(claims.UserID, conn, a.hub)
	client.Start(func(data []byte) {
		a.handleWSMessage(claims.UserID, data)
	})
}

func (a *API) handleWSMessage(senderID string, data []byte) {
	var envelope struct {
		Type           string `json:"type"`
		ConversationID string `json:"conversationId"`
		ClientID       string `json:"clientId"`
		Body           string `json:"body"`
	}
	if err := json.Unmarshal(data, &envelope); err != nil {
		return
	}
	if envelope.Type != "send" {
		return
	}
	if envelope.ClientID == "" {
		envelope.ClientID = uuid.NewString()
	}

	ctx := context.Background()
	msg, err := a.db.InsertChatMessage(ctx, envelope.ConversationID, senderID, envelope.ClientID, envelope.Body)
	if err != nil {
		a.hub.SendToUser(senderID, model.WSErrorPayload{
			Type:     "error",
			ClientID: envelope.ClientID,
			Error:    err.Error(),
		})
		return
	}

	a.dispatchChatMessage(ctx, msg)
}

func (a *API) dispatchChatMessage(ctx context.Context, msg model.ChatMessage) {
	payload := model.WSMessagePayload{Type: "message", Message: msg}
	ack := model.WSAckPayload{Type: "ack", ClientID: msg.ClientID, Message: msg}

	memberIDs, err := a.db.ConversationMemberIDs(ctx, msg.ConversationID)
	if err != nil {
		return
	}

	a.hub.SendToUser(msg.SenderID, ack)
	for _, uid := range memberIDs {
		if uid == msg.SenderID {
			continue
		}
		if a.hub.IsOnline(uid) {
			a.hub.SendToUser(uid, payload)
		} else {
			a.sendChatPush(ctx, uid, msg)
		}
	}
}

func (a *API) sendChatPush(ctx context.Context, recipientID string, msg model.ChatMessage) {
	if a.fcm == nil || !a.fcm.Enabled() {
		return
	}
	tokens, err := a.db.ListDeviceTokens(ctx, recipientID)
	if err != nil || len(tokens) == 0 {
		return
	}
	senderName, _ := a.db.GetUsername(ctx, msg.SenderID)
	if senderName == "" {
		senderName = "新消息"
	}
	preview := msg.Body
	if len([]rune(preview)) > 80 {
		preview = string([]rune(preview)[:80]) + "…"
	}
	push.NotifyTokens(ctx, a.fcm, tokens, senderName, preview, map[string]string{
		"type":           "chat_message",
		"conversationId": msg.ConversationID,
	})
}

// EnsureDMOnApprove 申请通过后自动建私信并发送欢迎语
func (a *API) EnsureDMOnApprove(ctx context.Context, hostUserID, applicantUserID, postID string) {
	if hostUserID == "" || applicantUserID == "" || hostUserID == applicantUserID {
		return
	}
	convID, err := a.db.GetOrCreateDM(ctx, hostUserID, applicantUserID, postID)
	if err != nil {
		log.Printf("approve dm create host=%s applicant=%s: %v", hostUserID, applicantUserID, err)
		return
	}
	clientID := uuid.NewString()
	body := "你们已通过组局申请，可以在这里沟通啦～"
	msg, err := a.db.InsertChatMessage(ctx, convID, hostUserID, clientID, body)
	if err != nil {
		log.Printf("approve dm welcome msg: %v", err)
		return
	}
	a.dispatchChatMessage(ctx, msg)
}
