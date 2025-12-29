# GraphQL Query Examples

## Query Examples

### Get User by ID
```graphql
query {
  user(id: "1") {
    id
    email
    username
    name
    createdAt
    updatedAt
  }
}
```

### Get Users List
```graphql
query {
  users(limit: 10, offset: 0) {
    id
    email
    username
    name
    createdAt
  }
}
```

## Mutation Examples

### Create User
```graphql
mutation {
  createUser(
    input: {
      email: "user@example.com"
      username: "testuser"
      name: "Test User"
    }
  ) {
    id
    email
    username
    name
    createdAt
  }
}
```

### Update User
```graphql
mutation {
  updateUser(
    input: {
      id: "1"
      name: "Updated Name"
      email: "newemail@example.com"
    }
  ) {
    id
    email
    username
    name
  }
}
```

### Delete User
```graphql
mutation {
  deleteUser(id: "1")
}
```

## Setup Instructions

1. Install dependencies:
```bash
go mod tidy
```

2. Generate GraphQL code:
```bash
make generate
# or
cd internal/graphql && go run github.com/99designs/gqlgen generate
```

3. Run the server:
```bash
make run
```

4. Access GraphQL playground:
- GraphQL endpoint: http://localhost:8080/graphql
- Playground: http://localhost:8080/playground

