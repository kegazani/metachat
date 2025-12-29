package handlers

import (
	"encoding/json"
	"log"

	"metachat/internal/models"
	"metachat/internal/repository"
)

type KafkaMessageHandler struct {
	userRepo *repository.UserRepository
}

func NewKafkaMessageHandler() *KafkaMessageHandler {
	return &KafkaMessageHandler{
		userRepo: repository.NewUserRepository(),
	}
}

func (h *KafkaMessageHandler) HandleMessage(topic string, key string, value []byte) error {
	log.Printf("Received message from topic %s, key: %s", topic, key)

	switch topic {
	case "events":
		return h.handleEventMessage(key, value)
	default:
		log.Printf("Unknown topic: %s", topic)
		return nil
	}
}

func (h *KafkaMessageHandler) handleEventMessage(key string, value []byte) error {
	var event struct {
		Type string          `json:"type"`
		Data json.RawMessage `json:"data"`
	}

	if err := json.Unmarshal(value, &event); err != nil {
		return err
	}

	switch event.Type {
	case "user.created":
		return h.handleUserCreated(event.Data)
	default:
		log.Printf("Unknown event type: %s", event.Type)
		return nil
	}
}

func (h *KafkaMessageHandler) handleUserCreated(data json.RawMessage) error {
	var user models.User
	if err := json.Unmarshal(data, &user); err != nil {
		return err
	}

	if err := h.userRepo.Create(&user); err != nil {
		return err
	}

	log.Printf("User created from Kafka event: %d", user.ID)
	return nil
}

