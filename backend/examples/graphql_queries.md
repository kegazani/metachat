# GraphQL Query Examples

## Запуск приложения

1. Убедитесь, что PostgreSQL и Cassandra запущены
2. Настройте `.env` файл с параметрами подключения
3. Запустите миграции: `make migrate`
4. Запустите сервер: `make run`
5. Откройте GraphQL Playground: http://localhost:8080/playground

## Примеры запросов (Queries)

### Получить пользователя по ID
```graphql
query {
  user(id: "1") {
    id
    name
    createdAt
    updatedAt
  }
}
```

### Получить список пользователей
```graphql
query {
  users(limit: 10, offset: 0) {
    id
    name
    createdAt
    updatedAt
  }
}
```

### Получить чат по ID
```graphql
query {
  chat(id: "550e8400-e29b-41d4-a716-446655440000") {
    id
    name
    users {
      id
      name
    }
    createdAt
    updatedAt
  }
}
```

### Получить список чатов
```graphql
query {
  chats(limit: 10, offset: 0) {
    id
    name
    users {
      id
      name
    }
    createdAt
  }
}
```

### Получить историю сообщения по ID
```graphql
query {
  chatHistory(id: "550e8400-e29b-41d4-a716-446655440001") {
    id
    chatId
    userId
    messageText
    createdAt
  }
}
```

### Получить историю сообщений чата
```graphql
query {
  chatHistories(chatId: "550e8400-e29b-41d4-a716-446655440000", limit: 50) {
    id
    chatId
    userId
    messageText
    createdAt
  }
}
```

## Примеры мутаций (Mutations)

### Создать пользователя
```graphql
mutation {
  createUser(input: {
    name: "Иван Иванов"
    password: "securepassword123"
  }) {
    id
    name
    createdAt
  }
}
```

### Обновить пользователя
```graphql
mutation {
  updateUser(input: {
    id: "1"
    name: "Иван Петров"
  }) {
    id
    name
    updatedAt
  }
}
```

### Изменить пароль пользователя
```graphql
mutation {
  updateUser(input: {
    id: "1"
    password: "newpassword456"
  }) {
    id
    name
  }
}
```

### Удалить пользователя
```graphql
mutation {
  deleteUser(id: "1")
}
```

### Создать чат
```graphql
mutation {
  createChat(input: {
    name: "Общий чат"
    userIds: ["1", "2", "3"]
  }) {
    id
    name
    users {
      id
      name
    }
    createdAt
  }
}
```

### Обновить чат
```graphql
mutation {
  updateChat(input: {
    id: "550e8400-e29b-41d4-a716-446655440000"
    name: "Обновленное название"
  }) {
    id
    name
    updatedAt
  }
}
```

### Удалить чат
```graphql
mutation {
  deleteChat(id: "550e8400-e29b-41d4-a716-446655440000")
}
```

### Добавить пользователя в чат
```graphql
mutation {
  addUserToChat(chatId: "550e8400-e29b-41d4-a716-446655440000", userId: "4") {
    id
    name
    users {
      id
      name
    }
  }
}
```

### Удалить пользователя из чата
```graphql
mutation {
  removeUserFromChat(chatId: "550e8400-e29b-41d4-a716-446655440000", userId: "4") {
    id
    name
    users {
      id
      name
    }
  }
}
```

### Создать сообщение в истории чата
```graphql
mutation {
  createChatHistory(input: {
    chatId: "550e8400-e29b-41d4-a716-446655440000"
    userId: "1"
    messageText: "Привет! Как дела?"
  }) {
    id
    chatId
    userId
    messageText
    createdAt
  }
}
```

### Удалить сообщение из истории
```graphql
mutation {
  deleteChatHistory(id: "550e8400-e29b-41d4-a716-446655440001")
}
```

## Полный пример работы с приложением

### Шаг 1: Создать пользователей
```graphql
mutation {
  user1: createUser(input: {
    name: "Алиса"
    password: "password1"
  }) {
    id
    name
  }
  
  user2: createUser(input: {
    name: "Боб"
    password: "password2"
  }) {
    id
    name
  }
}
```

### Шаг 2: Создать чат с пользователями
```graphql
mutation {
  createChat(input: {
    name: "Чат Алисы и Боба"
    userIds: ["1", "2"]
  }) {
    id
    name
    users {
      id
      name
    }
  }
}
```

### Шаг 3: Отправить сообщения
```graphql
mutation {
  msg1: createChatHistory(input: {
    chatId: "550e8400-e29b-41d4-a716-446655440000"
    userId: "1"
    messageText: "Привет, Боб!"
  }) {
    id
    messageText
    createdAt
  }
  
  msg2: createChatHistory(input: {
    chatId: "550e8400-e29b-41d4-a716-446655440000"
    userId: "2"
    messageText: "Привет, Алиса! Как дела?"
  }) {
    id
    messageText
    createdAt
  }
}
```

### Шаг 4: Получить историю чата
```graphql
query {
  chatHistories(chatId: "550e8400-e29b-41d4-a716-446655440000", limit: 100) {
    id
    userId
    messageText
    createdAt
  }
}
```

