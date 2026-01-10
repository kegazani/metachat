package models

import (
	"github.com/google/uuid"
)

type ChatHistory struct {
	ID                uuid.UUID `json:"id"`
	ChatID            uuid.UUID `json:"chat_id"`
	UserID            uint      `json:"user_id"`
	MessageText       string    `json:"message_text"`
	Type              string    `json:"type"`
	Emotion           *int      `json:"emotion"`
	EmotionLabel      *string   `json:"emotion_label"`
	EmotionConfidence *float64  `json:"emotion_confidence"`
	CreatedAt         int64     `json:"created_at"`
}

