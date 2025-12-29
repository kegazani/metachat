# MetaChat

Приложение для чата с поддержкой GraphQL API.

## Запуск

### Требования

- Go 1.24+
- PostgreSQL
- Cassandra
- Kafka (опционально)

### Настройка

1. Создайте файл `.env` в корне проекта:

```env
APP_PORT=8080
APP_ENV=development

POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=metachat
POSTGRES_SSLMODE=disable

CASSANDRA_HOSTS=localhost:9042
CASSANDRA_KEYSPACE=metachat
CASSANDRA_USERNAME=
CASSANDRA_PASSWORD=

KAFKA_BROKERS=localhost:9092
KAFKA_VERSION=2.6.0
KAFKA_CONSUMER_GROUP=metachat-group
KAFKA_TOPICS=events
```

2. Установите зависимости:

```bash
go mod tidy
```

3. Запустите миграции:

```bash
make migrate
```

4. Запустите сервер:

```bash
make run
```

### GraphQL API

После запуска сервера доступны:

- **GraphQL Endpoint**: http://localhost:8080/graphql
- **GraphiQL UI**: http://localhost:8080/graphql (встроенный интерфейс)
- **Playground**: http://localhost:8080/playground (альтернативный интерфейс)

### Примеры запросов

См. файл [examples/graphql_queries.md](examples/graphql_queries.md) для примеров всех доступных запросов и мутаций.

## Структура проекта

```
metachat/
├── cmd/
│   ├── migrate/     # Миграции базы данных
│   └── server/       # Основной сервер
├── config/           # Конфигурация
├── internal/
│   ├── database/     # Подключения к БД (PostgreSQL, Cassandra)
│   ├── graphql/      # GraphQL схема и резолверы
│   ├── handlers/     # HTTP handlers
│   ├── kafka/        # Kafka producer/consumer
│   ├── models/       # Модели данных
│   └── repository/   # Репозитории для работы с БД
├── examples/         # Примеры использования
└── pkg/             # Утилиты
```

## Модели данных

### User (PostgreSQL)
- ID (uint)
- Name (string)
- Password (string, хэшированный)

### Chat (PostgreSQL)
- ID (UUID)
- Name (string)
- Users (many-to-many связь)

### ChatHistory (Cassandra)
- ID (UUID)
- ChatID (UUID)
- UserID (uint)
- MessageText (string)
- CreatedAt (timestamp)

## Команды

- `make run` - запустить сервер
- `make migrate` - выполнить миграции
- `make build` - собрать бинарник
- `make test` - запустить тесты
- `make clean` - очистить бинарники

