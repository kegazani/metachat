package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"metachat/config"
	"metachat/internal/database"
	"metachat/internal/graphql"
	"metachat/internal/handlers"
	"metachat/internal/kafka"
	"metachat/internal/models"
	"metachat/internal/repository"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	if err := database.InitPostgres(cfg); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.ClosePostgres()

	if err := database.InitCassandra(cfg); err != nil {
		log.Fatalf("Failed to initialize Cassandra: %v", err)
	}
	defer database.CloseCassandra()

	if err := database.Migrate(&models.User{}, &models.Chat{}, &models.Diary{}); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	userRepo := repository.NewUserRepository()
	chatRepo := repository.NewChatRepository()
	chatHistoryRepo := repository.NewChatHistoryRepository()
	diaryRepo := repository.NewDiaryRepository()
	resolver := graphql.NewResolverWithRepos(userRepo, chatRepo, chatHistoryRepo, diaryRepo)

	graphqlHandler := graphql.NewGraphQLHandler(resolver)
	playgroundHandler := graphql.NewPlaygroundHandler()

	http.Handle("/graphql", graphqlHandler)
	http.Handle("/playground", playgroundHandler)

	go func() {
		addr := fmt.Sprintf(":%s", cfg.App.Port)
		log.Printf("GraphQL server starting on http://localhost%s/graphql", addr)
		log.Printf("GraphQL playground available at http://localhost%s/playground", addr)
		if err := http.ListenAndServe(addr, nil); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	producer, err := kafka.NewProducer(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize Kafka producer: %v", err)
	}
	defer producer.Close()

	messageHandler := handlers.NewKafkaMessageHandler()
	consumer, err := kafka.NewConsumer(cfg, messageHandler)
	if err != nil {
		log.Fatalf("Failed to initialize Kafka consumer: %v", err)
	}
	defer consumer.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	if err := consumer.Start(ctx); err != nil {
		log.Fatalf("Failed to start consumer: %v", err)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	log.Println("Server started successfully")
	log.Println("Press Ctrl+C to shutdown")

	select {
	case <-sigChan:
		log.Println("Shutting down...")
		cancel()
	case <-ctx.Done():
		log.Println("Context cancelled")
	}
}
