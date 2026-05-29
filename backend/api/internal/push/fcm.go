package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// FCM Firebase Cloud Messaging（HTTP v1）
type FCM struct {
	projectID string
	enabled   bool
	ts        oauth2.TokenSource
	client    *http.Client
}

func NewFCMFromEnv() *FCM {
	raw := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_JSON"))
	if raw == "" {
		path := strings.TrimSpace(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"))
		if path != "" {
			b, err := os.ReadFile(path)
			if err == nil {
				raw = string(b)
			}
		}
	}
	if raw == "" {
		log.Printf("fcm: disabled (set FCM_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS)")
		return &FCM{enabled: false}
	}

	jwtConfig, err := google.JWTConfigFromJSON(
		[]byte(raw),
		"https://www.googleapis.com/auth/firebase.messaging",
	)
	if err != nil {
		log.Printf("fcm: jwt config: %v", err)
		return &FCM{enabled: false}
	}

	var meta struct {
		ProjectID string `json:"project_id"`
	}
	_ = json.Unmarshal([]byte(raw), &meta)

	log.Printf("fcm: enabled project=%s", meta.ProjectID)
	return &FCM{
		projectID: meta.ProjectID,
		enabled:   meta.ProjectID != "",
		ts:        jwtConfig.TokenSource(context.Background()),
		client:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (f *FCM) Enabled() bool {
	return f != nil && f.enabled
}

func (f *FCM) Send(ctx context.Context, token, title, body string, data map[string]string) error {
	if f == nil || !f.enabled {
		return nil
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return nil
	}

	accessToken, err := f.ts.Token()
	if err != nil {
		return err
	}

	payload := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
			"data": data,
			"android": map[string]any{
				"priority": "HIGH",
			},
		},
	}
	bodyBytes, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", f.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := f.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("fcm status %d: %s", resp.StatusCode, string(b))
	}
	return nil
}

func NotifyTokens(
	ctx context.Context,
	fcm *FCM,
	tokens []string,
	title, body string,
	data map[string]string,
) {
	if fcm == nil || !fcm.Enabled() {
		return
	}
	for _, t := range tokens {
		if err := fcm.Send(ctx, t, title, body, data); err != nil {
			log.Printf("fcm send: %v", err)
		}
	}
}
