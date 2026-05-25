// 用户数据访问层（GORM），负责游客查找/创建与手机绑定
package store

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"strings"
	"time"

	"matchit/backend/api/internal/model"

	"github.com/google/uuid"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	ErrUserNotFound         = errors.New("user not found")
	ErrPhoneAlreadyBound    = errors.New("phone already bound")
	ErrNotGuestUser         = errors.New("user is not a guest")
	ErrPhoneNotRegistered   = errors.New("phone not registered")
	ErrAccountNotRegistered = errors.New("account not registered")
)

// UserStore 用户表 GORM 仓储
type UserStore struct {
	db *gorm.DB
}

// NewUserStore 连接 Postgres 并确保 users 表存在
func NewUserStore(databaseURL string) (*UserStore, error) {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("gorm open: %w", err)
	}
	if err := ensureUserSchema(db); err != nil {
		return nil, err
	}
	return &UserStore{db: db}, nil
}

func ensureUserSchema(db *gorm.DB) error {
	if !db.Migrator().HasTable(&model.User{}) {
		return db.AutoMigrate(&model.User{})
	}
	// 已有表由 init.sql 创建，仅增量补列，避免 GORM 重命名 unique 约束失败
	stmts := []string{
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(512) DEFAULT ''`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'active'`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ`,
	}
	for _, stmt := range stmts {
		if err := db.Exec(stmt).Error; err != nil {
			return fmt.Errorf("user schema: %w", err)
		}
	}
	return nil
}

func (s *UserStore) DB() *gorm.DB { return s.db }

// FindOrCreateGuestUser 按 device_id 查找或创建游客；username 为空时默认为「游客」
func (s *UserStore) FindOrCreateGuestUser(deviceID, username string) (*model.User, error) {
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" {
		return nil, fmt.Errorf("device_id is required")
	}
	username = normalizeGuestBrowseName(username)

	var user model.User
	err := s.db.Where("device_id = ?", deviceID).First(&user).Error
	if err == nil {
		// 已存在：若仍是默认昵称且本次传了名字，则补全
		return s.maybeUpdateUsername(&user, username)
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	user = model.User{
		DeviceID: deviceID,
		IsGuest:  true,
		Username: username,
	}
	// 并发安全：device_id 冲突时不重复插入
	if err := s.db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "device_id"}},
		DoNothing: true,
	}).Create(&user).Error; err != nil {
		return nil, err
	}

	if err := s.db.Where("device_id = ?", deviceID).First(&user).Error; err != nil {
		return nil, err
	}
	return s.maybeUpdateUsername(&user, username)
}

func normalizeGuestBrowseName(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "游客"
	}
	return name
}

var guestRandomNamePattern = regexp.MustCompile(`^游客\d{6}$`)

func defaultGuestRandomName() string {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return fmt.Sprintf("游客%06d", time.Now().UnixNano()%1000000)
	}
	return fmt.Sprintf("游客%06d", n.Int64())
}

// normalizeRegisterName 注册时昵称：空则随机游客名
func normalizeRegisterName(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return defaultGuestRandomName()
	}
	return name
}

func isReplaceableGuestName(name string) bool {
	name = strings.TrimSpace(name)
	if name == "" || name == "游客" {
		return true
	}
	return guestRandomNamePattern.MatchString(name)
}

// maybeUpdateUsername 仅当当前为默认游客昵称时才更新
func (s *UserStore) maybeUpdateUsername(user *model.User, username string) (*model.User, error) {
	username = strings.TrimSpace(username)
	if username == "" || username == "游客" || user.Username == username {
		return user, nil
	}
	if isReplaceableGuestName(user.Username) {
		user.Username = username
		if err := s.db.Model(user).Update("username", username).Error; err != nil {
			return nil, err
		}
	}
	return user, nil
}

// GetUserByID 按 UUID 查询用户
func (s *UserStore) GetUserByID(id string) (*model.User, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrUserNotFound
	}
	var user model.User
	if err := s.db.First(&user, "id = ?", uid).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

// BindPhone 游客绑定手机号，升级为正式用户（is_guest=false）
func (s *UserStore) BindPhone(userID, phone, username string) (*model.User, error) {
	return s.bindPhone(userID, phone, username)
}

func (s *UserStore) bindPhone(userID, phone, username string) (*model.User, error) {
	username = strings.TrimSpace(username)
	var user model.User
	err := s.db.Transaction(func(tx *gorm.DB) error {
		uid, err := uuid.Parse(userID)
		if err != nil {
			return ErrUserNotFound
		}
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&user, "id = ?", uid).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrUserNotFound
			}
			return err
		}
		if !user.IsGuest {
			return ErrNotGuestUser
		}

		var existing model.User
		if err := tx.Where("phone = ?", phone).First(&existing).Error; err == nil && existing.ID != user.ID {
			return ErrPhoneAlreadyBound
		} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		user.Phone = &phone
		user.IsGuest = false
		now := time.Now().UTC()
		user.PhoneVerifiedAt = &now
		user.LastLoginAt = &now
		user.Username = normalizeRegisterName(username)
		return tx.Save(&user).Error
	})
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByPhone 按手机号查找用户
func (s *UserStore) FindByPhone(phone string) (*model.User, error) {
	phone = strings.TrimSpace(phone)
	var user model.User
	if err := s.db.Where("phone = ?", phone).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrPhoneNotRegistered
		}
		return nil, err
	}
	return &user, nil
}

// RegisterByPhone 欢迎页/手机号直注册：游客则升级，同设备已有正式号则建新账号
func (s *UserStore) RegisterByPhone(deviceID, phone, username string) (*model.User, error) {
	deviceID = strings.TrimSpace(deviceID)
	phone = strings.TrimSpace(phone)
	if deviceID == "" || phone == "" {
		return nil, fmt.Errorf("device_id and phone are required")
	}

	var byPhone model.User
	if err := s.db.Where("phone = ?", phone).First(&byPhone).Error; err == nil {
		return nil, ErrPhoneAlreadyBound
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	var existing model.User
	if err := s.db.Where("device_id = ?", deviceID).First(&existing).Error; err == nil {
		if existing.IsGuest {
			return s.bindPhone(existing.ID.String(), phone, username)
		}
		// 同浏览器已登过别的号，允许再注册（独立 device_id 后缀）
		deviceID = deviceID + "__" + phone
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	now := time.Now().UTC()
	user := model.User{
		DeviceID:        deviceID,
		IsGuest:         false,
		Username:        normalizeRegisterName(username),
		Phone:           &phone,
		PhoneVerifiedAt: &now,
		LastLoginAt:     &now,
		Status:          "active",
	}
	if err := s.db.Select("device_id", "is_guest", "username", "phone", "phone_verified_at", "last_login_at", "status").
		Create(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

// TouchLastLogin 更新最后登录时间
func (s *UserStore) TouchLastLogin(userID string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return ErrUserNotFound
	}
	now := time.Now().UTC()
	return s.db.Model(&model.User{}).Where("id = ?", uid).Update("last_login_at", now).Error
}
