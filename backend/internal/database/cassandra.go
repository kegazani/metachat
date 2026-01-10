package database

import (
	"fmt"
	"log"

	"metachat/config"
	"github.com/gocql/gocql"
)

var CassandraSession *gocql.Session

func InitCassandra(cfg *config.Config) error {
	cluster := gocql.NewCluster(cfg.Cassandra.Hosts...)
	cluster.Keyspace = cfg.Cassandra.Keyspace
	
	if cfg.Cassandra.Username != "" {
		cluster.Authenticator = gocql.PasswordAuthenticator{
			Username: cfg.Cassandra.Username,
			Password: cfg.Cassandra.Password,
		}
	}

	cluster.Consistency = gocql.Quorum

	session, err := cluster.CreateSession()
	if err != nil {
		return fmt.Errorf("failed to create Cassandra session: %w", err)
	}

	CassandraSession = session

	if err := createKeyspaceIfNotExists(cfg); err != nil {
		return fmt.Errorf("failed to create keyspace: %w", err)
	}

	if err := createChatHistoryTable(cfg); err != nil {
		return fmt.Errorf("failed to create chat_history table: %w", err)
	}

	if err := createHealthDataTable(cfg); err != nil {
		return fmt.Errorf("failed to create health_data table: %w", err)
	}

	log.Println("Successfully connected to Cassandra")
	return nil
}

func createKeyspaceIfNotExists(cfg *config.Config) error {
	cluster := gocql.NewCluster(cfg.Cassandra.Hosts...)
	
	if cfg.Cassandra.Username != "" {
		cluster.Authenticator = gocql.PasswordAuthenticator{
			Username: cfg.Cassandra.Username,
			Password: cfg.Cassandra.Password,
		}
	}

	session, err := cluster.CreateSession()
	if err != nil {
		return err
	}
	defer session.Close()

	createKeyspaceQuery := fmt.Sprintf(
		"CREATE KEYSPACE IF NOT EXISTS %s WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}",
		cfg.Cassandra.Keyspace,
	)

	if err := session.Query(createKeyspaceQuery).Exec(); err != nil {
		return fmt.Errorf("failed to create keyspace: %w", err)
	}

	cluster.Keyspace = cfg.Cassandra.Keyspace
	newSession, err := cluster.CreateSession()
	if err != nil {
		return err
	}
	CassandraSession.Close()
	CassandraSession = newSession

	return nil
}

func createChatHistoryTable(cfg *config.Config) error {
	createTableQuery := `
		CREATE TABLE IF NOT EXISTS chat_history (
			id UUID PRIMARY KEY,
			chat_id UUID,
			user_id INT,
			message_text TEXT,
			type TEXT,
			created_at BIGINT
		)
	`

	if err := CassandraSession.Query(createTableQuery).Exec(); err != nil {
		return fmt.Errorf("failed to create chat_history table: %w", err)
	}

	alterTableQuery := `ALTER TABLE chat_history ADD IF NOT EXISTS type TEXT`

	if err := CassandraSession.Query(alterTableQuery).Exec(); err != nil {
		log.Printf("Warning: failed to add type column (may already exist): %v", err)
	}

	alterTableQuery2 := `ALTER TABLE chat_history ADD IF NOT EXISTS emotion INT`
	if err := CassandraSession.Query(alterTableQuery2).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion column (may already exist): %v", err)
	}

	alterTableQuery3 := `ALTER TABLE chat_history ADD IF NOT EXISTS emotion_label TEXT`
	if err := CassandraSession.Query(alterTableQuery3).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion_label column (may already exist): %v", err)
	}

	alterTableQuery4 := `ALTER TABLE chat_history ADD IF NOT EXISTS emotion_confidence DOUBLE`
	if err := CassandraSession.Query(alterTableQuery4).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion_confidence column (may already exist): %v", err)
	}

	createIndexQuery := `CREATE INDEX IF NOT EXISTS ON chat_history (chat_id)`

	if err := CassandraSession.Query(createIndexQuery).Exec(); err != nil {
		return fmt.Errorf("failed to create index on chat_id: %w", err)
	}

	return nil
}

func createHealthDataTable(cfg *config.Config) error {
	createTableQuery := `
		CREATE TABLE IF NOT EXISTS health_data (
			id UUID PRIMARY KEY,
			user_id INT,
			timestamp BIGINT,
			heart_rate DOUBLE,
			sdnn DOUBLE,
			rmssd DOUBLE,
			pnn50 DOUBLE,
			created_at BIGINT
		)
	`

	if err := CassandraSession.Query(createTableQuery).Exec(); err != nil {
		return fmt.Errorf("failed to create health_data table: %w", err)
	}

	alterTableQuery := `ALTER TABLE health_data ADD IF NOT EXISTS emotion INT`

	if err := CassandraSession.Query(alterTableQuery).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion column (may already exist): %v", err)
	}

	alterTableQuery2 := `ALTER TABLE health_data ADD IF NOT EXISTS emotion_label TEXT`
	if err := CassandraSession.Query(alterTableQuery2).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion_label column (may already exist): %v", err)
	}

	alterTableQuery3 := `ALTER TABLE health_data ADD IF NOT EXISTS emotion_confidence DOUBLE`
	if err := CassandraSession.Query(alterTableQuery3).Exec(); err != nil {
		log.Printf("Warning: failed to add emotion_confidence column (may already exist): %v", err)
	}

	createIndexQuery := `CREATE INDEX IF NOT EXISTS ON health_data (user_id)`

	if err := CassandraSession.Query(createIndexQuery).Exec(); err != nil {
		return fmt.Errorf("failed to create index on user_id: %w", err)
	}

	return nil
}

func CloseCassandra() error {
	if CassandraSession != nil {
		CassandraSession.Close()
	}
	return nil
}

