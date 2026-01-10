package graph

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"time"

	"github.com/99designs/gqlgen/graphql"
	"github.com/vektah/gqlparser/v2/ast"
)

func (ec *executionContext) unmarshalInputJSON(ctx context.Context, v any) (map[string]any, error) {
	if v == nil {
		return nil, nil
	}
	if m, ok := v.(map[string]any); ok {
		return m, nil
	}
	if m2, ok := v.(map[string]interface{}); ok {
		result := make(map[string]any, len(m2))
		for k, val := range m2 {
			result[k] = val
		}
		return result, nil
	}
	return nil, fmt.Errorf("JSON must be a map[string]any or map[string]interface{}")
}

func (ec *executionContext) _JSON(ctx context.Context, sel ast.SelectionSet, v map[string]any) graphql.Marshaler {
	if v == nil {
		return graphql.Null
	}
	return graphql.WriterFunc(func(w io.Writer) {
		data, err := json.Marshal(v)
		if err != nil {
			w.Write([]byte("null"))
			return
		}
		w.Write(data)
	})
}

func (ec *executionContext) unmarshalInputTime(ctx context.Context, v any) (time.Time, error) {
	return graphql.UnmarshalTime(v)
}

func (ec *executionContext) _Time(ctx context.Context, sel ast.SelectionSet, v *time.Time) graphql.Marshaler {
	if v == nil {
		return graphql.Null
	}
	return graphql.MarshalTime(*v)
}
