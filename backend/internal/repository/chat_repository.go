package repository

import (
	"metachat/internal/database"
	"metachat/internal/models"

	"github.com/google/uuid"
)

type ChatRepository struct{}

func NewChatRepository() *ChatRepository {
	return &ChatRepository{}
}

func (r *ChatRepository) Create(chat *models.Chat) error {
	if chat.ID == uuid.Nil {
		chat.ID = uuid.New()
	}
	return database.DB.Create(chat).Error
}

func (r *ChatRepository) GetByID(id uuid.UUID) (*models.Chat, error) {
	var chat models.Chat
	err := database.DB.Preload("Users").First(&chat, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &chat, nil
}

func (r *ChatRepository) Update(chat *models.Chat) error {
	return database.DB.Save(chat).Error
}

func (r *ChatRepository) Delete(id uuid.UUID) error {
	return database.DB.Delete(&models.Chat{}, "id = ?", id).Error
}

func (r *ChatRepository) List(limit, offset int) ([]models.Chat, error) {
	var chats []models.Chat
	err := database.DB.Preload("Users").Limit(limit).Offset(offset).Find(&chats).Error
	return chats, err
}

func (r *ChatRepository) AddUserToChat(chatID uuid.UUID, userID uint) error {
	var chat models.Chat
	if err := database.DB.First(&chat, "id = ?", chatID).Error; err != nil {
		return err
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		return err
	}

	return database.DB.Model(&chat).Association("Users").Append(&user)
}

func (r *ChatRepository) RemoveUserFromChat(chatID uuid.UUID, userID uint) error {
	var chat models.Chat
	if err := database.DB.First(&chat, "id = ?", chatID).Error; err != nil {
		return err
	}

	var user models.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		return err
	}

	return database.DB.Model(&chat).Association("Users").Delete(&user)
}

func (r *ChatRepository) GetChatUsers(chatID uuid.UUID) ([]models.User, error) {
	var chat models.Chat
	if err := database.DB.Preload("Users").First(&chat, "id = ?", chatID).Error; err != nil {
		return nil, err
	}
	return chat.Users, nil
}

func (r *ChatRepository) ListByUserID(userID uint, limit, offset int) ([]models.Chat, error) {
	type result struct {
		ChatID uuid.UUID `gorm:"column:chat_id"`
	}
	var results []result
	
	err := database.DB.Table("chat_users").
		Select("chat_id").
		Where("user_id = ?", userID).
		Limit(limit).
		Offset(offset).
		Scan(&results).Error
	if err != nil {
		return nil, err
	}

	if len(results) == 0 {
		return []models.Chat{}, nil
	}

	var chatIDs []uuid.UUID
	for _, r := range results {
		chatIDs = append(chatIDs, r.ChatID)
	}

	var chats []models.Chat
	err = database.DB.Preload("Users").
		Where("id IN ?", chatIDs).
		Find(&chats).Error
	return chats, err
}

func (r *ChatRepository) IsUserInChat(chatID uuid.UUID, userID uint) (bool, error) {
	var count int64
	err := database.DB.Table("chat_users").
		Where("chat_id = ? AND user_id = ?", chatID, userID).
		Count(&count).Error
	return count > 0, err
}

