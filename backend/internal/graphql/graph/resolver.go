package graph

import "metachat/internal/repository"

type Resolver struct {
	UserRepo        *repository.UserRepository
	ChatRepo        *repository.ChatRepository
	ChatHistoryRepo *repository.ChatHistoryRepository
	DiaryRepo       *repository.DiaryRepository
}
