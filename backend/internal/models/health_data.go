package models

import (
	"github.com/google/uuid"
)

type HealthData struct {
	ID                uuid.UUID `json:"id"`
	UserID            uint      `json:"user_id"`
	HeartRate         *float64  `json:"heart_rate"`
	SDNN              *float64  `json:"sdnn"`
	RMSSD             *float64  `json:"rmssd"`
	PNN50             *float64  `json:"pnn50"`
	Emotion           *int      `json:"emotion"`
	EmotionLabel      *string   `json:"emotion_label"`
	EmotionConfidence *float64  `json:"emotion_confidence"`
	Timestamp         int64     `json:"timestamp"`
	CreatedAt         int64     `json:"created_at"`
}
