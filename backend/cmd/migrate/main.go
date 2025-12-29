package main

import (
	"log"
	"time"

	"metachat/config"
	"metachat/internal/database"
	"metachat/internal/models"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	maxRetries := 10
	retryDelay := 2 * time.Second

	var dbErr error
	for i := 0; i < maxRetries; i++ {
		if dbErr = database.InitPostgres(cfg); dbErr == nil {
			break
		}
		log.Printf("Failed to connect to database (attempt %d/%d): %v", i+1, maxRetries, dbErr)
		if i < maxRetries-1 {
			time.Sleep(retryDelay)
		}
	}

	if dbErr != nil {
		log.Fatalf("Failed to initialize database after %d attempts: %v", maxRetries, dbErr)
	}
	defer database.ClosePostgres()

	if err := database.Migrate(&models.User{}, &models.Chat{}, &models.Diary{}); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	log.Println("Migrations completed successfully")
}
