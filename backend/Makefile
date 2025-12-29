.PHONY: run build test clean migrate generate docker-up docker-down docker-build docker-logs

run:
	go run cmd/server/main.go

build:
	go build -o bin/server cmd/server/main.go

test:
	go test ./...

clean:
	rm -rf bin/

migrate:
	go run cmd/migrate/main.go

generate:
	cd internal/graphql && go run github.com/99designs/gqlgen generate

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

docker-build:
	docker-compose build

docker-logs:
	docker-compose logs -f app

docker-restart:
	docker-compose restart app

docker-clean:
	docker-compose down -v

