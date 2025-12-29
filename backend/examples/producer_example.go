package main

import (
	"encoding/json"
	"log"

	"metachat/config"
	"metachat/internal/kafka"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	producer, err := kafka.NewProducer(cfg)
	if err != nil {
		log.Fatalf("Failed to create producer: %v", err)
	}
	defer producer.Close()

	event := map[string]interface{}{
		"type": "user.created",
		"data": map[string]interface{}{
			"email":    "user@example.com",
			"username": "testuser",
			"name":     "Test User",
		},
	}

	eventJSON, err := json.Marshal(event)
	if err != nil {
		log.Fatalf("Failed to marshal event: %v", err)
	}

	if err := producer.SendMessage("events", "user-123", eventJSON); err != nil {
		log.Fatalf("Failed to send message: %v", err)
	}

	log.Println("Message sent successfully")
}

