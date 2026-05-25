// 短信验证码：Redis / 内存缓存 + Mock 发送（开发环境）
package sms

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strconv"
	"strings"
	"time"

	"matchit/backend/api/internal/cache"
)

var (
	ErrCodeExpired     = errors.New("verification code expired or not sent")
	ErrCodeInvalid     = errors.New("invalid verification code")
	ErrTooManyRequests = errors.New("please wait before requesting another code")
	ErrTooManyFailures = errors.New("too many failed attempts, try again later")
)

const DevBypassCode = "000000"

type Scene string

const (
	SceneBind  Scene = "bind"
	SceneLogin Scene = "login"
)

func (s Scene) Valid() bool {
	return s == SceneBind || s == SceneLogin
}

type Service struct {
	kv             cache.Store
	mock           bool
	codeTTL        time.Duration
	resendCooldown time.Duration
	maxVerifyFail  int
}

func NewService(kv cache.Store, mock bool, codeTTL, resendCooldown time.Duration, maxVerifyFail int) *Service {
	return &Service{
		kv:             kv,
		mock:           mock,
		codeTTL:        codeTTL,
		resendCooldown: resendCooldown,
		maxVerifyFail:  maxVerifyFail,
	}
}

func codeKey(scene Scene, phone string) string {
	return fmt.Sprintf("sms:code:%s:%s", scene, phone)
}

func cooldownKey(phone string) string {
	return fmt.Sprintf("sms:cooldown:%s", phone)
}

func failKey(phone string) string {
	return fmt.Sprintf("sms:fail:%s", phone)
}

func (s *Service) SendCode(ctx context.Context, phone string, scene Scene) error {
	phone = strings.TrimSpace(phone)
	if !scene.Valid() {
		return fmt.Errorf("invalid scene")
	}

	if s.resendCooldown > 0 {
		if n, err := s.kv.Exists(ctx, cooldownKey(phone)); err != nil {
			return err
		} else if n > 0 {
			return ErrTooManyRequests
		}
	}

	code, err := generateCode()
	if err != nil {
		return err
	}

	if err := s.kv.Set(ctx, codeKey(scene, phone), code, s.codeTTL); err != nil {
		return err
	}
	if s.resendCooldown > 0 {
		if err := s.kv.Set(ctx, cooldownKey(phone), "1", s.resendCooldown); err != nil {
			return err
		}
	}
	_ = s.kv.Del(ctx, failKey(phone))

	if s.mock {
		log.Printf("[SMS MOCK] phone=%s scene=%s code=%s (dev bypass: %s)", maskPhone(phone), scene, code, DevBypassCode)
	} else {
		log.Printf("[SMS] sent to %s scene=%s", maskPhone(phone), scene)
	}
	return nil
}

func (s *Service) VerifyAuthCode(ctx context.Context, phone, inputCode string) error {
	if err := s.verifyAndConsumeScene(ctx, phone, SceneBind, inputCode); err == nil {
		return nil
	} else if !errors.Is(err, ErrCodeExpired) && !errors.Is(err, ErrCodeInvalid) {
		return err
	}
	return s.verifyAndConsumeScene(ctx, phone, SceneLogin, inputCode)
}

func (s *Service) VerifyAndConsume(ctx context.Context, phone string, scene Scene, inputCode string) error {
	return s.verifyAndConsumeScene(ctx, phone, scene, inputCode)
}

func (s *Service) verifyAndConsumeScene(ctx context.Context, phone string, scene Scene, inputCode string) error {
	phone = strings.TrimSpace(phone)
	inputCode = strings.TrimSpace(inputCode)
	if inputCode == "" {
		return ErrCodeInvalid
	}

	if blocked, err := s.kv.Get(ctx, failKey(phone)); err == nil {
		if n, convErr := strconv.ParseInt(blocked, 10, 64); convErr == nil && int(n) >= s.maxVerifyFail {
			return ErrTooManyFailures
		}
	} else if err != nil && !cache.IsNotFound(err) {
		return err
	}

	stored, err := s.kv.Get(ctx, codeKey(scene, phone))
	if cache.IsNotFound(err) {
		if s.mock && inputCode == DevBypassCode {
			return nil
		}
		return ErrCodeExpired
	}
	if err != nil {
		return err
	}

	if inputCode != stored && !(s.mock && inputCode == DevBypassCode) {
		if err := s.recordFailure(ctx, phone); err != nil {
			return err
		}
		return ErrCodeInvalid
	}

	_ = s.kv.Del(ctx, codeKey(scene, phone))
	_ = s.kv.Del(ctx, failKey(phone))
	return nil
}

func (s *Service) recordFailure(ctx context.Context, phone string) error {
	key := failKey(phone)
	n, err := s.kv.Incr(ctx, key)
	if err != nil {
		return err
	}
	if n == 1 {
		_ = s.kv.Expire(ctx, key, 15*time.Minute)
	}
	if int(n) >= s.maxVerifyFail {
		_ = s.kv.Expire(ctx, key, 15*time.Minute)
		return ErrTooManyFailures
	}
	return nil
}

func generateCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func maskPhone(phone string) string {
	if len(phone) < 7 {
		return "***"
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}
