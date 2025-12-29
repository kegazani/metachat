package kafka

import (
	"context"
	"fmt"
	"log"

	"metachat/config"
	"github.com/IBM/sarama"
)

type Consumer struct {
	consumer sarama.ConsumerGroup
	config   *config.Config
	handler  MessageHandler
}

type MessageHandler interface {
	HandleMessage(topic string, key string, value []byte) error
}

type ConsumerGroupHandler struct {
	handler MessageHandler
}

func (h *ConsumerGroupHandler) Setup(sarama.ConsumerGroupSession) error {
	return nil
}

func (h *ConsumerGroupHandler) Cleanup(sarama.ConsumerGroupSession) error {
	return nil
}

func (h *ConsumerGroupHandler) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for {
		select {
		case message := <-claim.Messages():
			if message == nil {
				return nil
			}

			if err := h.handler.HandleMessage(
				message.Topic,
				string(message.Key),
				message.Value,
			); err != nil {
				log.Printf("Error handling message: %v", err)
			}

			session.MarkMessage(message, "")

		case <-session.Context().Done():
			return nil
		}
	}
}

func NewConsumer(cfg *config.Config, handler MessageHandler) (*Consumer, error) {
	saramaConfig := sarama.NewConfig()
	saramaConfig.Consumer.Group.Rebalance.Strategy = sarama.NewBalanceStrategyRoundRobin()
	saramaConfig.Consumer.Offsets.Initial = sarama.OffsetOldest

	version, err := sarama.ParseKafkaVersion(cfg.Kafka.Version)
	if err != nil {
		return nil, fmt.Errorf("error parsing kafka version: %w", err)
	}
	saramaConfig.Version = version

	consumer, err := sarama.NewConsumerGroup(cfg.Kafka.Brokers, cfg.Kafka.ConsumerGroup, saramaConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create kafka consumer: %w", err)
	}

	log.Println("Kafka consumer initialized successfully")

	return &Consumer{
		consumer: consumer,
		config:   cfg,
		handler:  handler,
	}, nil
}

func (c *Consumer) Start(ctx context.Context) error {
	handler := &ConsumerGroupHandler{handler: c.handler}

	go func() {
		for {
			select {
			case <-ctx.Done():
				log.Println("Consumer context cancelled")
				return
			default:
				if err := c.consumer.Consume(ctx, c.config.Kafka.Topics, handler); err != nil {
					log.Printf("Error from consumer: %v", err)
					return
				}
			}
		}
	}()

	return nil
}

func (c *Consumer) Close() error {
	if c.consumer != nil {
		return c.consumer.Close()
	}
	return nil
}

