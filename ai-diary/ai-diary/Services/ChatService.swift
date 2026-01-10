import Foundation

class ChatService {
    private let authStore: AuthStore
    
    init(authStore: AuthStore) {
        self.authStore = authStore
    }
    
    private func performRequest(query: String, variables: [String: Any]) async throws -> [String: Any] {
        let url = AppConfig.graphQLURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        let session = ApolloClientService.shared.apollo
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let errors = json?["errors"] as? [[String: Any]],
           let errorMessage = errors.first?["message"] as? String {
            throw ServiceError.serverError(errorMessage)
        }
        
        return json ?? [:]
    }
    
    func fetchChats(limit: Int = 100, offset: Int = 0) async throws -> [Chat] {
        let query = """
        query Chats($limit: Int, $offset: Int) {
          chats(limit: $limit, offset: $offset) {
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
        """
        
        let variables: [String: Any] = [
            "limit": limit,
            "offset": offset
        ]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let chatsArray = data["chats"] as? [[String: Any]] else {
            throw ServiceError.invalidResponse
        }
        
        return chatsArray.map { chatDict in
            let id = chatDict["id"] as? String ?? ""
            let name = chatDict["name"] as? String ?? ""
            
            let usersArray = chatDict["users"] as? [[String: Any]] ?? []
            let users = usersArray.map { userDict in
                User(
                    id: userDict["id"] as? String ?? "",
                    name: userDict["name"] as? String ?? "",
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
            
            return Chat(
                id: id,
                name: name,
                users: users,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
    
    func fetchChat(id: String) async throws -> Chat {
        let query = """
        query Chat($id: ID!) {
          chat(id: $id) {
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
        """
        
        let variables: [String: Any] = ["id": id]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let chatDict = data["chat"] as? [String: Any] else {
            throw ServiceError.invalidResponse
        }
        
        let chatId = chatDict["id"] as? String ?? ""
        let name = chatDict["name"] as? String ?? ""
        
        let usersArray = chatDict["users"] as? [[String: Any]] ?? []
        let users = usersArray.map { userDict in
            User(
                id: userDict["id"] as? String ?? "",
                name: userDict["name"] as? String ?? "",
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        return Chat(
            id: chatId,
            name: name,
            users: users,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func createChat(name: String, userIds: [String]) async throws -> Chat {
        let query = """
        mutation CreateChat($input: CreateChatInput!) {
          createChat(input: $input) {
            id
            name
            users {
              id
              name
            }
            createdAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "name": name,
                "userIds": userIds
            ]
        ]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let chatDict = data["createChat"] as? [String: Any] else {
            throw ServiceError.invalidResponse
        }
        
        let id = chatDict["id"] as? String ?? ""
        let chatName = chatDict["name"] as? String ?? ""
        
        let usersArray = chatDict["users"] as? [[String: Any]] ?? []
        let users = usersArray.map { userDict in
            User(
                id: userDict["id"] as? String ?? "",
                name: userDict["name"] as? String ?? "",
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        return Chat(
            id: id,
            name: chatName,
            users: users,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func deleteChat(id: String) async throws {
        let query = """
        mutation DeleteChat($id: ID!) {
          deleteChat(id: $id)
        }
        """
        
        let variables: [String: Any] = ["id": id]
        
        _ = try await performRequest(query: query, variables: variables)
    }
}

enum ServiceError: Error {
    case invalidResponse
    case serverError(String)
}

