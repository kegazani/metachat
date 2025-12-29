package repository

import (
	"metachat/internal/database"
	"metachat/internal/models"
	"time"

	"github.com/gocql/gocql"
	"github.com/google/uuid"
)

type ChatHistoryRepository struct{}

func NewChatHistoryRepository() *ChatHistoryRepository {
	return &ChatHistoryRepository{}
}

func uuidToGocqlUUID(u uuid.UUID) gocql.UUID {
	var result gocql.UUID
	copy(result[:], u[:])
	return result
}

func (r *ChatHistoryRepository) Create(history *models.ChatHistory) error {
	if history.ID == uuid.Nil {
		history.ID = uuid.New()
	}
	if history.CreatedAt == 0 {
		history.CreatedAt = time.Now().Unix()
	}
	if history.Type == "" {
		history.Type = "normal"
	}

	query := `INSERT INTO chat_history (id, chat_id, user_id, message_text, type, created_at) VALUES (?, ?, ?, ?, ?, ?)`
	return database.CassandraSession.Query(query, uuidToGocqlUUID(history.ID), uuidToGocqlUUID(history.ChatID), history.UserID, history.MessageText, history.Type, history.CreatedAt).Exec()
}

func (r *ChatHistoryRepository) GetByID(id uuid.UUID) (*models.ChatHistory, error) {
	var history models.ChatHistory
	var gocqlID, gocqlChatID gocql.UUID
	query := `SELECT id, chat_id, user_id, message_text, type, created_at FROM chat_history WHERE id = ? LIMIT 1`

	iter := database.CassandraSession.Query(query, uuidToGocqlUUID(id)).Iter()

	if !iter.Scan(&gocqlID, &gocqlChatID, &history.UserID, &history.MessageText, &history.Type, &history.CreatedAt) {
		iter.Close()
		return nil, gocql.ErrNotFound
	}

	history.ID, _ = uuid.FromBytes(gocqlID.Bytes())
	history.ChatID, _ = uuid.FromBytes(gocqlChatID.Bytes())
	if history.Type == "" {
		history.Type = "normal"
	}

	if err := iter.Close(); err != nil {
		return nil, err
	}

	return &history, nil
}

func (r *ChatHistoryRepository) GetByChatID(chatID uuid.UUID, limit int) ([]models.ChatHistory, error) {
	var histories []models.ChatHistory
	query := `SELECT id, chat_id, user_id, message_text, type, created_at FROM chat_history WHERE chat_id = ? LIMIT ?`

	iter := database.CassandraSession.Query(query, uuidToGocqlUUID(chatID), limit).Iter()

	var history models.ChatHistory
	var gocqlID, gocqlChatID gocql.UUID
	for iter.Scan(&gocqlID, &gocqlChatID, &history.UserID, &history.MessageText, &history.Type, &history.CreatedAt) {
		history.ID, _ = uuid.FromBytes(gocqlID.Bytes())
		history.ChatID, _ = uuid.FromBytes(gocqlChatID.Bytes())
		if history.Type == "" {
			history.Type = "normal"
		}
		histories = append(histories, history)
	}

	if err := iter.Close(); err != nil {
		return nil, err
	}

	return histories, nil
}

func (r *ChatHistoryRepository) GetByChatIDAndType(chatID uuid.UUID, messageType string, limit int) ([]models.ChatHistory, error) {
	var histories []models.ChatHistory
	query := `SELECT id, chat_id, user_id, message_text, type, created_at FROM chat_history WHERE chat_id = ? AND type = ? LIMIT ?`

	iter := database.CassandraSession.Query(query, uuidToGocqlUUID(chatID), messageType, limit).Iter()

	var history models.ChatHistory
	var gocqlID, gocqlChatID gocql.UUID
	for iter.Scan(&gocqlID, &gocqlChatID, &history.UserID, &history.MessageText, &history.Type, &history.CreatedAt) {
		history.ID, _ = uuid.FromBytes(gocqlID.Bytes())
		history.ChatID, _ = uuid.FromBytes(gocqlChatID.Bytes())
		if history.Type == "" {
			history.Type = "normal"
		}
		histories = append(histories, history)
	}

	if err := iter.Close(); err != nil {
		return nil, err
	}

	return histories, nil
}

func (r *ChatHistoryRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM chat_history WHERE id = ?`
	return database.CassandraSession.Query(query, uuidToGocqlUUID(id)).Exec()
}
