package graphql

import (
	"net/http"

	"metachat/internal/graphql/graph"
	"metachat/internal/repository"

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

func NewResolverWithRepos(userRepo *repository.UserRepository, chatRepo *repository.ChatRepository, chatHistoryRepo *repository.ChatHistoryRepository, diaryRepo *repository.DiaryRepository) *graph.Resolver {
	return &graph.Resolver{
		UserRepo:        userRepo,
		ChatRepo:        chatRepo,
		ChatHistoryRepo: chatHistoryRepo,
		DiaryRepo:       diaryRepo,
	}
}

func NewGraphQLHandler(resolver *graph.Resolver) http.Handler {
	srv := handler.New(graph.NewExecutableSchema(graph.Config{Resolvers: resolver}))

	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})

	srv.SetQueryCache(lru.New[*ast.QueryDocument](1000))

	srv.Use(extension.Introspection{})
	srv.Use(extension.AutomaticPersistedQuery{
		Cache: lru.New[string](100),
	})

	return corsMiddleware(srv)
}

func NewPlaygroundHandler() http.Handler {
	return corsMiddleware(playground.Handler("GraphQL playground", "/graphql"))
}

