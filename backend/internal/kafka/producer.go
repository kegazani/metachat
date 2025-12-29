package kafka

import (
	"fmt"
	"log"

	"metachat/config"
	"github.com/IBM/sarama"
)

type Producer struct {
	producer sarama.SyncProducer
	config   *config.Config
}

func NewProducer(cfg *config.Config) (*Producer, error) {
	saramaConfig := sarama.NewConfig()
	saramaConfig.Producer.Return.Successes = true
	saramaConfig.Producer.RequiredAcks = sarama.WaitForAll
	saramaConfig.Producer.Retry.Max = 5

	version, err := sarama.ParseKafkaVersion(cfg.Kafka.Version)
	if err != nil {
		return nil, fmt.Errorf("error parsing kafka version: %w", err)
	}
	saramaConfig.Version = version

	producer, err := sarama.NewSyncProducer(cfg.Kafka.Brokers, saramaConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create kafka producer: %w", err)
	}

	log.Println("Kafka producer initialized successfully")

	return &Producer{
		producer: producer,
		config:   cfg,
	}, nil
}

func (p *Producer) SendMessage(topic string, key string, value []byte) error {
	msg := &sarama.ProducerMessage{
		Topic: topic,
		Key:   sarama.StringEncoder(key),
		Value: sarama.ByteEncoder(value),
	}

	partition, offset, err := p.producer.SendMessage(msg)
	if err != nil {
		return fmt.Errorf("failed to send message: %w", err)
	}

	log.Printf("Message sent to topic %s, partition %d, offset %d", topic, partition, offset)
	return nil
}

func (p *Producer) Close() error {
	if p.producer != nil {
		return p.producer.Close()
	}
	return nil
}

