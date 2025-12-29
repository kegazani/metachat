package repository

import (
	"metachat/internal/database"
	"metachat/internal/models"
)

type UserRepository struct{}

func NewUserRepository() *UserRepository {
	return &UserRepository{}
}

func (r *UserRepository) Create(user *models.User) error {
	return database.DB.Create(user).Error
}

func (r *UserRepository) GetByID(id uint) (*models.User, error) {
	var user models.User
	err := database.DB.First(&user, id).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) Update(user *models.User) error {
	return database.DB.Save(user).Error
}

func (r *UserRepository) Delete(id uint) error {
	return database.DB.Delete(&models.User{}, id).Error
}

func (r *UserRepository) List(limit, offset int) ([]models.User, error) {
	var users []models.User
	err := database.DB.Limit(limit).Offset(offset).Find(&users).Error
	return users, err
}

func (r *UserRepository) GetByName(name string) (*models.User, error) {
	var user models.User
	err := database.DB.Where("name = ?", name).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

