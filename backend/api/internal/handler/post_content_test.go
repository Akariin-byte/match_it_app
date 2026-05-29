package handler

import (
	"strings"
	"testing"

	"matchit/backend/api/internal/model"
)

func TestDeriveTitle(t *testing.T) {
	t.Parallel()
	if got := DeriveTitle("", maxPostTitleRunes); got != "" {
		t.Fatalf("empty: %q", got)
	}
	if got := DeriveTitle("  周六 #桌游  ", maxPostTitleRunes); got != "周六 #桌游" {
		t.Fatalf("trim: %q", got)
	}
	if got := DeriveTitle("第一行\n第二行", maxPostTitleRunes); got != "第一行 第二行" {
		t.Fatalf("newline: %q", got)
	}
	long := strings.Repeat("测", 80)
	got := DeriveTitle(long, maxPostTitleRunes)
	if len([]rune(got)) != maxPostTitleRunes+1 {
		t.Fatalf("truncate len = %d, want %d: %q", len([]rune(got)), maxPostTitleRunes+1, got)
	}
	if !strings.HasSuffix(got, "…") {
		t.Fatalf("expected ellipsis suffix: %q", got)
	}
}

func TestValidateCreatePayload(t *testing.T) {
	t.Parallel()
	if err := validateCreatePayload(model.CreatePostPayload{}); err == nil {
		t.Fatal("expected content required")
	}
	if err := validateCreatePayload(model.CreatePostPayload{
		Content: "hello",
		Area:    "BoardGames",
	}); err != nil {
		t.Fatalf("valid payload: %v", err)
	}
}

func TestMergeTags(t *testing.T) {
	t.Parallel()
	got := mergeTags([]string{"桌游"}, "周末 #阿瓦隆 #桌游")
	if len(got) != 2 {
		t.Fatalf("tags = %v", got)
	}
}
