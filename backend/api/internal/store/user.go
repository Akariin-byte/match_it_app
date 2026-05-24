// 用户数据访问层（GORM），负责游客查找/创建与手机绑定
package store

import (
	"errors"
	"fmt"
	"strings"

	"matchit/backend/api/internal/model"

	"github.com/google/uuid"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrPhoneAlreadyBound = errors.New("phone already bound")
	ErrNotGuestUser      = errors.New("user is not a guest")
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
	if !db.Migrator().HasTable(&model.User{}) {
		if err := db.AutoMigrate(&model.User{}); err != nil {
			return nil, fmt.Errorf("auto migrate users: %w", err)
		}
	}
	return &UserStore{db: db}, nil
}

func (s *UserStore) DB() *gorm.DB { return s.db }

// FindOrCreateGuestUser 按 device_id 查找或创建游客；username 为空时默认为「游客」
func (s *UserStore) FindOrCreateGuestUser(deviceID, username string) (*model.User, error) {
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" {
		return nil, fmt.Errorf("device_id is required")
	}
	username = normalizeUsername(username)

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

func normalizeUsername(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "游客"
	}
	return name
}

// maybeUpdateUsername 仅当当前为默认「游客」时才更新昵称
func (s *UserStore) maybeUpdateUsername(user *model.User, username string) (*model.User, error) {
	username = normalizeUsername(username)
	if username == "游客" || user.Username == username {
		return user, nil
	}
	if user.Username == "" || user.Username == "游客" {
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
		if username != "" && username != "游客" {
			user.Username = username
		}
		return tx.Save(&user).Error
	})
	if err != nil {
		return nil, err
	}
	return &user, nil
}
