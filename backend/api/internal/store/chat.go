package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"matchit/backend/api/internal/model"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrNotConversationMember = errors.New("not a conversation member")
	ErrInvalidMessage        = errors.New("invalid message")
)

func normalizeDMUsers(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

// GetOrCreateDM 获取或创建两人私信会话
func (p *Postgres) GetOrCreateDM(
	ctx context.Context,
	userID, peerUserID, postID string,
) (string, error) {
	if userID == "" || peerUserID == "" || userID == peerUserID {
		return "", fmt.Errorf("invalid dm users")
	}
	userA, userB := normalizeDMUsers(userID, peerUserID)

	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	var convID string
	err = tx.QueryRow(ctx,
		`SELECT conversation_id::text FROM dm_pairs WHERE user_a = $1::uuid AND user_b = $2::uuid`,
		userA, userB,
	).Scan(&convID)
	if err == nil {
		if err := tx.Commit(ctx); err != nil {
			return "", err
		}
		return convID, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}

	var postRef any
	if strings.TrimSpace(postID) != "" {
		postRef = postID
	}
	err = tx.QueryRow(ctx, `
INSERT INTO conversations (type, post_id)
VALUES ('dm', $1)
RETURNING id::text`, postRef).Scan(&convID)
	if err != nil {
		return "", err
	}

	for _, uid := range []string{userA, userB} {
		_, err = tx.Exec(ctx, `
INSERT INTO conversation_members (conversation_id, user_id)
VALUES ($1::uuid, $2::uuid)
ON CONFLICT DO NOTHING`, convID, uid)
		if err != nil {
			return "", err
		}
	}

	_, err = tx.Exec(ctx, `
INSERT INTO dm_pairs (user_a, user_b, conversation_id)
VALUES ($1::uuid, $2::uuid, $3::uuid)`,
		userA, userB, convID)
	if err != nil {
		return "", err
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return convID, nil
}

func (p *Postgres) IsConversationMember(
	ctx context.Context,
	conversationID, userID string,
) (bool, error) {
	var n int
	err := p.pool.QueryRow(ctx, `
SELECT 1 FROM conversation_members
WHERE conversation_id = $1::uuid AND user_id = $2::uuid`,
		conversationID, userID,
	).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func (p *Postgres) InsertChatMessage(
	ctx context.Context,
	conversationID, senderID, clientID, body string,
) (model.ChatMessage, error) {
	body = strings.TrimSpace(body)
	if body == "" || len(body) > 4000 {
		return model.ChatMessage{}, ErrInvalidMessage
	}
	if _, err := uuid.Parse(clientID); err != nil {
		return model.ChatMessage{}, ErrInvalidMessage
	}

	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return model.ChatMessage{}, err
	}
	defer tx.Rollback(ctx)

	member, err := p.isConversationMemberTx(ctx, tx, conversationID, senderID)
	if err != nil {
		return model.ChatMessage{}, err
	}
	if !member {
		return model.ChatMessage{}, ErrNotConversationMember
	}

	var msg model.ChatMessage
	err = tx.QueryRow(ctx, `
WITH bumped AS (
  UPDATE conversations
  SET last_seq = last_seq + 1, updated_at = now()
  WHERE id = $1::uuid
  RETURNING last_seq
)
INSERT INTO messages (conversation_id, sender_id, client_id, seq, body)
SELECT $1::uuid, $2::uuid, $3::uuid, bumped.last_seq, $4
FROM bumped
RETURNING id::text, conversation_id::text, sender_id::text, client_id::text,
          seq, body, created_at`,
		conversationID, senderID, clientID, body,
	).Scan(
		&msg.ID,
		&msg.ConversationID,
		&msg.SenderID,
		&msg.ClientID,
		&msg.Seq,
		&msg.Body,
		&msg.CreatedAt,
	)
	if err != nil {
		return model.ChatMessage{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return model.ChatMessage{}, err
	}
	return msg, nil
}

func (p *Postgres) isConversationMemberTx(
	ctx context.Context,
	tx pgx.Tx,
	conversationID, userID string,
) (bool, error) {
	var n int
	err := tx.QueryRow(ctx, `
SELECT 1 FROM conversation_members
WHERE conversation_id = $1::uuid AND user_id = $2::uuid`,
		conversationID, userID,
	).Scan(&n)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func (p *Postgres) ListConversationMessages(
	ctx context.Context,
	conversationID, userID string,
	beforeSeq int64,
	limit int,
) ([]model.ChatMessage, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	member, err := p.IsConversationMember(ctx, conversationID, userID)
	if err != nil {
		return nil, err
	}
	if !member {
		return nil, ErrNotConversationMember
	}

	var rows pgx.Rows
	var err2 error
	if beforeSeq > 0 {
		rows, err2 = p.pool.Query(ctx, `
SELECT id::text, conversation_id::text, sender_id::text, client_id::text,
       seq, body, created_at
FROM messages
WHERE conversation_id = $1::uuid AND seq < $2
ORDER BY seq DESC
LIMIT $3`, conversationID, beforeSeq, limit)
	} else {
		rows, err2 = p.pool.Query(ctx, `
SELECT id::text, conversation_id::text, sender_id::text, client_id::text,
       seq, body, created_at
FROM messages
WHERE conversation_id = $1::uuid
ORDER BY seq DESC
LIMIT $2`, conversationID, limit)
	}
	if err2 != nil {
		return nil, err2
	}
	defer rows.Close()

	var out []model.ChatMessage
	for rows.Next() {
		var m model.ChatMessage
		if err := rows.Scan(
			&m.ID, &m.ConversationID, &m.SenderID, &m.ClientID,
			&m.Seq, &m.Body, &m.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out, rows.Err()
}

func (p *Postgres) ListConversations(
	ctx context.Context,
	userID string,
) ([]model.ConversationItem, error) {
	const q = `
SELECT c.id::text, c.type, COALESCE(c.post_id, ''), c.updated_at,
       ou.id::text,
       COALESCE(NULLIF(TRIM(ou.username), ''), '用户'),
       COALESCE(lm.id::text, ''),
       COALESCE(lm.sender_id::text, ''),
       COALESCE(lm.client_id::text, ''),
       COALESCE(lm.seq, 0),
       COALESCE(lm.body, ''),
       lm.created_at,
       GREATEST(COALESCE(c.last_seq, 0) - cm.last_read_seq, 0)
FROM conversation_members cm
JOIN conversations c ON c.id = cm.conversation_id
JOIN conversation_members om
  ON om.conversation_id = c.id AND om.user_id <> cm.user_id
JOIN users ou ON ou.id = om.user_id
LEFT JOIN LATERAL (
  SELECT m.id, m.sender_id, m.client_id, m.seq, m.body, m.created_at
  FROM messages m
  WHERE m.conversation_id = c.id
  ORDER BY m.seq DESC
  LIMIT 1
) lm ON true
WHERE cm.user_id = $1::uuid
ORDER BY c.updated_at DESC
LIMIT 100`
	rows, err := p.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []model.ConversationItem
	for rows.Next() {
		var item model.ConversationItem
		var lastMsgID, lastSender, lastClient, lastBody string
		var lastSeq int64
		var lastCreated *time.Time
		if err := rows.Scan(
			&item.ID,
			&item.Type,
			&item.PostID,
			&item.UpdatedAt,
			&item.OtherUser.UserID,
			&item.OtherUser.Username,
			&lastMsgID,
			&lastSender,
			&lastClient,
			&lastSeq,
			&lastBody,
			&lastCreated,
			&item.UnreadCount,
		); err != nil {
			return nil, err
		}
		if lastMsgID != "" && lastCreated != nil {
			item.LastMessage = &model.ChatMessage{
				ID:             lastMsgID,
				ConversationID: item.ID,
				SenderID:       lastSender,
				ClientID:       lastClient,
				Seq:            lastSeq,
				Body:           lastBody,
				CreatedAt:      *lastCreated,
			}
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (p *Postgres) MarkConversationRead(
	ctx context.Context,
	conversationID, userID string,
	seq int64,
) error {
	_, err := p.pool.Exec(ctx, `
UPDATE conversation_members
SET last_read_seq = GREATEST(last_read_seq, $3)
WHERE conversation_id = $1::uuid AND user_id = $2::uuid`,
		conversationID, userID, seq,
	)
	return err
}

func (p *Postgres) ConversationMemberIDs(
	ctx context.Context,
	conversationID string,
) ([]string, error) {
	rows, err := p.pool.Query(ctx, `
SELECT user_id::text FROM conversation_members WHERE conversation_id = $1::uuid`,
		conversationID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (p *Postgres) UpsertDeviceToken(
	ctx context.Context,
	userID, platform, token string,
) error {
	platform = strings.TrimSpace(strings.ToLower(platform))
	token = strings.TrimSpace(token)
	if platform == "" || token == "" {
		return fmt.Errorf("invalid device token")
	}
	_, err := p.pool.Exec(ctx, `
INSERT INTO device_tokens (user_id, platform, token, updated_at)
VALUES ($1::uuid, $2, $3, now())
ON CONFLICT (user_id, platform, token)
DO UPDATE SET updated_at = now()`, userID, platform, token)
	return err
}

func (p *Postgres) ListDeviceTokens(ctx context.Context, userID string) ([]string, error) {
	rows, err := p.pool.Query(ctx, `
SELECT token FROM device_tokens WHERE user_id = $1::uuid`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

func (p *Postgres) GetUsername(ctx context.Context, userID string) (string, error) {
	var name string
	err := p.pool.QueryRow(ctx, `
SELECT COALESCE(NULLIF(TRIM(username), ''), '用户') FROM users WHERE id = $1::uuid`,
		userID,
	).Scan(&name)
	return name, err
}
