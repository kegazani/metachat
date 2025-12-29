package repository

import (
	"metachat/internal/database"
	"metachat/internal/models"
)

type DiaryRepository struct{}

func NewDiaryRepository() *DiaryRepository {
	return &DiaryRepository{}
}

func (r *DiaryRepository) Create(diary *models.Diary) error {
	return database.DB.Create(diary).Error
}

func (r *DiaryRepository) GetByUserID(userID uint) (*models.Diary, error) {
	var diary models.Diary
	err := database.DB.Where("user_id = ?", userID).First(&diary).Error
	if err != nil {
		return nil, err
	}
	return &diary, nil
}

func (r *DiaryRepository) GetByID(id uint) (*models.Diary, error) {
	var diary models.Diary
	err := database.DB.First(&diary, id).Error
	if err != nil {
		return nil, err
	}
	return &diary, nil
}

func (r *DiaryRepository) Update(diary *models.Diary) error {
	return database.DB.Save(diary).Error
}

