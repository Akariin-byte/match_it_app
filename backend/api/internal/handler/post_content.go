package handler

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"matchit/backend/api/internal/model"
)

const (
	maxPostContentRunes = 500
	maxPostTitleRunes   = 60
	defaultMaxPeople    = 4
	defaultHardcore     = 50
)

var hashtagRE = regexp.MustCompile(`#[^\s#]+`)

// DeriveTitle 从正文生成列表摘要（用户无需单独写标题）
func DeriveTitle(content string, maxRunes int) string {
	s := strings.TrimSpace(content)
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.Join(strings.Fields(s), " ")
	if maxRunes <= 0 {
		return s
	}
	if utf8.RuneCountInString(s) <= maxRunes {
		return s
	}
	runes := []rune(s)
	return string(runes[:maxRunes]) + "…"
}

func normalizePostContent(content string) string {
	return strings.TrimSpace(content)
}

func parseHashtagsFromContent(content string) []string {
	seen := make(map[string]struct{})
	var out []string
	for _, m := range hashtagRE.FindAllString(content, -1) {
		tag := strings.TrimSpace(strings.TrimPrefix(m, "#"))
		if tag == "" {
			continue
		}
		if _, ok := seen[tag]; ok {
			continue
		}
		seen[tag] = struct{}{}
		out = append(out, tag)
	}
	return out
}

func mergeTags(explicit []string, content string) []string {
	seen := make(map[string]struct{})
	var out []string
	add := func(raw string) {
		tag := strings.TrimSpace(strings.TrimPrefix(raw, "#"))
		if tag == "" {
			return
		}
		if _, ok := seen[tag]; ok {
			return
		}
		seen[tag] = struct{}{}
		out = append(out, tag)
	}
	for _, t := range explicit {
		add(t)
	}
	for _, t := range parseHashtagsFromContent(content) {
		add(t)
	}
	return out
}

func validateCreatePayload(p model.CreatePostPayload) error {
	content := normalizePostContent(p.Content)
	n := utf8.RuneCountInString(content)
	if n == 0 {
		return errors.New("content is required")
	}
	if n > maxPostContentRunes {
		return fmt.Errorf("content must be at most %d characters", maxPostContentRunes)
	}
	if strings.TrimSpace(p.Area) == "" {
		return errors.New("area is required")
	}
	maxPeople := p.MaxPeople
	if maxPeople <= 0 {
		maxPeople = defaultMaxPeople
	}
	if maxPeople < 1 || maxPeople > 20 {
		return errors.New("maxPeople must be between 1 and 20")
	}
	cost := strings.ToLower(strings.TrimSpace(p.CostType))
	switch cost {
	case "", "free", "aa", "negotiate":
	case "fixed":
		if p.Amount == nil || *p.Amount <= 0 {
			return errors.New("amount must be > 0 when costType is fixed")
		}
	default:
		return errors.New("invalid costType")
	}
	return nil
}

func buildPostFromPayload(p model.CreatePostPayload, hostNickname string, postID string) model.MatchPost {
	content := normalizePostContent(p.Content)
	maxPeople := p.MaxPeople
	if maxPeople <= 0 {
		maxPeople = defaultMaxPeople
	}
	hardcore := defaultHardcore
	if p.HardcoreScore != nil {
		hardcore = *p.HardcoreScore
	}
	tab := strings.TrimSpace(p.Tab)
	if tab == "" {
		tab = "推荐"
	}
	tags := mergeTags(p.Tags, content)
	if len(tags) == 0 {
		tags = []string{strings.TrimSpace(p.Area)}
	}
	eventTime := time.Now().UTC().Add(24 * time.Hour)
	if p.EventDateTime != nil && !p.EventDateTime.IsZero() {
		eventTime = p.EventDateTime.UTC()
	}

	return model.MatchPost{
		ID:               postID,
		Title:            DeriveTitle(content, maxPostTitleRunes),
		Description:      content,
		CurrentMembers:   1,
		MaxMembers:       maxPeople,
		MaxPeople:        maxPeople,
		Area:             strings.TrimSpace(p.Area),
		Tab:              tab,
		HardcoreScore:    hardcore,
		HostFaceTraits:   tags,
		InteractionCount: 0,
		LastActiveTime:   time.Now().UTC(),
		MatchScore:       0,
		HostNickname:     hostNickname,
		HostCreditScore:  80,
		EventDateTime:    eventTime,
		EventLocation:    strings.TrimSpace(p.EventLocation),
		CostType:         strings.ToLower(strings.TrimSpace(p.CostType)),
		Amount:           p.Amount,
		IsPinned:         false,
		PinPriority:      0,
	}
}
