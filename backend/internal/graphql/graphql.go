package graphql

import (
	"context"
	"log"
	"net/http"
	"strings"

	"metachat/internal/graphql/graph"
	"metachat/internal/repository"
	"metachat/internal/services"
	"metachat/pkg/ctxkeys"
	"metachat/pkg/utils"

	"github.com/99designs/gqlgen/graphql"
	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/handler/extension"
	"github.com/99designs/gqlgen/graphql/handler/lru"
	"github.com/99designs/gqlgen/graphql/handler/transport"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/vektah/gqlparser/v2/ast"
)


func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "3600")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func NewResolverWithRepos(userRepo *repository.UserRepository, chatRepo *repository.ChatRepository, chatHistoryRepo *repository.ChatHistoryRepository, diaryRepo *repository.DiaryRepository, healthDataRepo *repository.HealthDataRepository, aiService *services.AIService) *graph.Resolver {
	return &graph.Resolver{
		UserRepo:        userRepo,
		ChatRepo:        chatRepo,
		ChatHistoryRepo: chatHistoryRepo,
		DiaryRepo:       diaryRepo,
		HealthDataRepo:  healthDataRepo,
		AIService:       aiService,
	}
}

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		log.Printf("[authMiddleware] Auth header present: %v", authHeader != "")
		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && parts[0] == "Bearer" {
				token := parts[1]
				claims, err := utils.ValidateToken(token)
				if err != nil {
					log.Printf("[authMiddleware] Token validation failed: %v", err)
				} else {
					log.Printf("[authMiddleware] Token valid, setting userID: %d in context", claims.UserID)
					ctx := context.WithValue(r.Context(), ctxkeys.UserIDKey, claims.UserID)
					r = r.WithContext(ctx)
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}

func NewGraphQLHandler(resolver *graph.Resolver) http.Handler {
	srv := handler.New(graph.NewExecutableSchema(graph.Config{Resolvers: resolver}))

	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})

	srv.SetQueryCache(lru.New[*ast.QueryDocument](1000))

	srv.Use(extension.Introspection{})

	srv.AroundOperations(func(ctx context.Context, next graphql.OperationHandler) graphql.ResponseHandler {
		opCtx := graphql.GetOperationContext(ctx)
		if opCtx != nil {
			authHeader := opCtx.Headers.Get("Authorization")
			log.Printf("[GraphQL AroundOperations] Auth header present: %v", authHeader != "")
			if authHeader != "" {
				parts := strings.Split(authHeader, " ")
				if len(parts) == 2 && parts[0] == "Bearer" {
					token := parts[1]
					claims, err := utils.ValidateToken(token)
					if err != nil {
						log.Printf("[GraphQL AroundOperations] Token validation failed: %v", err)
					} else {
						log.Printf("[GraphQL AroundOperations] Token valid, userID: %d", claims.UserID)
						ctx = context.WithValue(ctx, ctxkeys.UserIDKey, claims.UserID)
					}
				} else {
					log.Printf("[GraphQL AroundOperations] Invalid auth header format")
				}
			}
		} else {
			log.Printf("[GraphQL AroundOperations] opCtx is nil")
		}
		return next(ctx)
	})

	return corsMiddleware(authMiddleware(srv))
}

func NewPlaygroundHandler() http.Handler {
	return corsMiddleware(playground.Handler("GraphQL playground", "/graphql"))
}

