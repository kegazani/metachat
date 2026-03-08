package repository

import (
	"metachat/internal/database"
	"metachat/internal/models"
	"sort"
	"time"

	"github.com/gocql/gocql"
	"github.com/google/uuid"
)

type HealthDataRepository struct{}

func NewHealthDataRepository() *HealthDataRepository {
	return &HealthDataRepository{}
}

func (r *HealthDataRepository) Create(healthData *models.HealthData) error {
	if healthData.ID == uuid.Nil {
		healthData.ID = uuid.New()
	}
	if healthData.CreatedAt == 0 {
		healthData.CreatedAt = time.Now().Unix()
	}

	query := `INSERT INTO health_data (id, user_id, timestamp, heart_rate, sdnn, rmssd, pnn50, emotion, emotion_label, emotion_confidence, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	return database.CassandraSession.Query(query,
		uuidToGocqlUUID(healthData.ID),
		healthData.UserID,
		healthData.Timestamp,
		healthData.HeartRate,
		healthData.SDNN,
		healthData.RMSSD,
		healthData.PNN50,
		healthData.Emotion,
		healthData.EmotionLabel,
		healthData.EmotionConfidence,
		healthData.CreatedAt,
	).Exec()
}

func (r *HealthDataRepository) GetByID(id uuid.UUID) (*models.HealthData, error) {
	var healthData models.HealthData
	var gocqlID gocql.UUID
	var emotionLabel *string
	var emotionConfidence *float64
	query := `SELECT id, user_id, timestamp, heart_rate, sdnn, rmssd, pnn50, emotion, emotion_label, emotion_confidence, created_at FROM health_data WHERE id = ? LIMIT 1`

	iter := database.CassandraSession.Query(query, uuidToGocqlUUID(id)).Iter()

	if !iter.Scan(&gocqlID, &healthData.UserID, &healthData.Timestamp, &healthData.HeartRate, &healthData.SDNN, &healthData.RMSSD, &healthData.PNN50, &healthData.Emotion, &emotionLabel, &emotionConfidence, &healthData.CreatedAt) {
		iter.Close()
		return nil, gocql.ErrNotFound
	}

	healthData.ID, _ = uuid.FromBytes(gocqlID.Bytes())
	healthData.EmotionLabel = emotionLabel
	healthData.EmotionConfidence = emotionConfidence

	if err := iter.Close(); err != nil {
		return nil, err
	}

	return &healthData, nil
}

func (r *HealthDataRepository) GetByUserID(userID uint, limit, offset int) ([]models.HealthData, error) {
	var healthDataList []models.HealthData
	query := `SELECT id, user_id, timestamp, heart_rate, sdnn, rmssd, pnn50, emotion, emotion_label, emotion_confidence, created_at FROM health_data WHERE user_id = ?`

	iter := database.CassandraSession.Query(query, userID).Iter()

	var healthData models.HealthData
	var gocqlID gocql.UUID
	var emotionLabel *string
	var emotionConfidence *float64
	for iter.Scan(&gocqlID, &healthData.UserID, &healthData.Timestamp, &healthData.HeartRate, &healthData.SDNN, &healthData.RMSSD, &healthData.PNN50, &healthData.Emotion, &emotionLabel, &emotionConfidence, &healthData.CreatedAt) {
		healthData.ID, _ = uuid.FromBytes(gocqlID.Bytes())
		healthData.EmotionLabel = emotionLabel
		healthData.EmotionConfidence = emotionConfidence
		healthDataList = append(healthDataList, healthData)
	}

	if err := iter.Close(); err != nil {
		return nil, err
	}

	sort.Slice(healthDataList, func(i, j int) bool {
		return healthDataList[i].Timestamp > healthDataList[j].Timestamp
	})

	if offset > 0 && offset < len(healthDataList) {
		healthDataList = healthDataList[offset:]
	}

	if limit > 0 && limit < len(healthDataList) {
		healthDataList = healthDataList[:limit]
	}

	return healthDataList, nil
}

func (r *HealthDataRepository) Update(healthData *models.HealthData) error {
	query := `UPDATE health_data SET heart_rate = ?, sdnn = ?, rmssd = ?, pnn50 = ?, emotion = ?, emotion_label = ?, emotion_confidence = ? WHERE id = ?`
	return database.CassandraSession.Query(query,
		healthData.HeartRate,
		healthData.SDNN,
		healthData.RMSSD,
		healthData.PNN50,
		healthData.Emotion,
		healthData.EmotionLabel,
		healthData.EmotionConfidence,
		uuidToGocqlUUID(healthData.ID),
	).Exec()
}

func (r *HealthDataRepository) GetByUserIDAndDateRange(userID uint, startDate, endDate *time.Time, limit, offset int) ([]models.HealthData, error) {
	var healthDataList []models.HealthData
	var startTimestamp, endTimestamp *int64

	if startDate != nil {
		ts := startDate.Unix()
		startTimestamp = &ts
	}
	if endDate != nil {
		ts := endDate.Unix()
		endTimestamp = &ts
	}

	query := `SELECT id, user_id, timestamp, heart_rate, sdnn, rmssd, pnn50, emotion, emotion_label, emotion_confidence, created_at FROM health_data WHERE user_id = ?`

	iter := database.CassandraSession.Query(query, userID).Iter()

	var healthData models.HealthData
	var gocqlID gocql.UUID
	var emotionLabel *string
	var emotionConfidence *float64
	for iter.Scan(&gocqlID, &healthData.UserID, &healthData.Timestamp, &healthData.HeartRate, &healthData.SDNN, &healthData.RMSSD, &healthData.PNN50, &healthData.Emotion, &emotionLabel, &emotionConfidence, &healthData.CreatedAt) {
		healthData.ID, _ = uuid.FromBytes(gocqlID.Bytes())
		healthData.EmotionLabel = emotionLabel
		healthData.EmotionConfidence = emotionConfidence

		if startTimestamp != nil && healthData.Timestamp < *startTimestamp {
			continue
		}
		if endTimestamp != nil && healthData.Timestamp > *endTimestamp {
			continue
		}

		healthDataList = append(healthDataList, healthData)
	}

	if err := iter.Close(); err != nil {
		return nil, err
	}

	sort.Slice(healthDataList, func(i, j int) bool {
		return healthDataList[i].Timestamp > healthDataList[j].Timestamp
	})

	if offset > 0 && offset < len(healthDataList) {
		healthDataList = healthDataList[offset:]
	}

	if limit > 0 && limit < len(healthDataList) {
		healthDataList = healthDataList[:limit]
	}

	return healthDataList, nil
}
