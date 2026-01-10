package graph

import (
	"metachat/internal/repository"
	"metachat/internal/services"
)

type Resolver struct {
	UserRepo        *repository.UserRepository
	ChatRepo        *repository.ChatRepository
	ChatHistoryRepo *repository.ChatHistoryRepository
	DiaryRepo       *repository.DiaryRepository
	HealthDataRepo  *repository.HealthDataRepository
	AIService       *services.AIService
}
