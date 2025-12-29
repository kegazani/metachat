package database

import (
	"fmt"
	"log"

	"metachat/config"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func InitPostgres(cfg *config.Config) error {
	var err error

	dsn := cfg.Postgres.DSN()

	var logLevel logger.LogLevel
	if cfg.App.Env == "development" {
		logLevel = logger.Info
	} else {
		logLevel = logger.Error
	}

	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	})

	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	sqlDB, err := DB.DB()
	if err != nil {
		return fmt.Errorf("failed to get database instance: %w", err)
	}

	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	log.Println("Successfully connected to PostgreSQL")

	return nil
}

func ClosePostgres() error {
	if DB != nil {
		sqlDB, err := DB.DB()
		if err != nil {
			return err
		}
		return sqlDB.Close()
	}
	return nil
}

func Migrate(models ...interface{}) error {
	if DB == nil {
		return fmt.Errorf("database connection is not initialized")
	}
	return DB.AutoMigrate(models...)
}

