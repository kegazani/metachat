package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	App       AppConfig
	Postgres  PostgresConfig
	Kafka     KafkaConfig
	Cassandra CassandraConfig
}

type AppConfig struct {
	Port string
	Env  string
}

type PostgresConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

type KafkaConfig struct {
	Brokers        []string
	Version        string
	ConsumerGroup  string
	Topics         []string
}

type CassandraConfig struct {
	Hosts    []string
	Keyspace string
	Username string
	Password string
}

func Load() (*Config, error) {
	_ = godotenv.Load()

	config := &Config{
		App: AppConfig{
			Port: getEnv("APP_PORT", "8080"),
			Env:  getEnv("APP_ENV", "development"),
		},
		Postgres: PostgresConfig{
			Host:     getEnv("POSTGRES_HOST", "localhost"),
			Port:     getEnv("POSTGRES_PORT", "5432"),
			User:     getEnv("POSTGRES_USER", "postgres"),
			Password: getEnv("POSTGRES_PASSWORD", "postgres"),
			DBName:   getEnv("POSTGRES_DB", "metachat"),
			SSLMode:  getEnv("POSTGRES_SSLMODE", "disable"),
		},
		Kafka: KafkaConfig{
			Brokers:       parseStringSlice(getEnv("KAFKA_BROKERS", "localhost:9092")),
			Version:       getEnv("KAFKA_VERSION", "2.6.0"),
			ConsumerGroup: getEnv("KAFKA_CONSUMER_GROUP", "metachat-group"),
			Topics:        parseStringSlice(getEnv("KAFKA_TOPICS", "events")),
		},
		Cassandra: CassandraConfig{
			Hosts:    parseStringSlice(getEnv("CASSANDRA_HOSTS", "localhost:9042")),
			Keyspace: getEnv("CASSANDRA_KEYSPACE", "metachat"),
			Username: getEnv("CASSANDRA_USERNAME", ""),
			Password: getEnv("CASSANDRA_PASSWORD", ""),
		},
	}

	return config, nil
}

func (c *PostgresConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseStringSlice(value string) []string {
	if value == "" {
		return []string{}
	}
	result := []string{}
	current := ""
	for _, char := range value {
		if char == ',' {
			if current != "" {
				result = append(result, current)
				current = ""
			}
		} else {
			current += string(char)
		}
	}
	if current != "" {
		result = append(result, current)
	}
	return result
}

