import Foundation

class MessageService {
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
    
    func fetchChatHistories(chatId: String, limit: Int = 100) async throws -> [ChatHistory] {
        let query = """
        query ChatHistories($chatId: ID!, $limit: Int) {
          chatHistories(chatId: $chatId, limit: $limit) {
            id
            chatId
            userId
            messageText
            type
            emotion
            emotionLabel
            emotionConfidence
            createdAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "chatId": chatId,
            "limit": limit
        ]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let historiesArray = data["chatHistories"] as? [[String: Any]] else {
            throw ServiceError.invalidResponse
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return historiesArray.compactMap { historyDict in
            guard let id = historyDict["id"] as? String,
                  let chatId = historyDict["chatId"] as? String,
                  let userId = historyDict["userId"] as? String,
                  let messageText = historyDict["messageText"] as? String,
                  let type = historyDict["type"] as? String else {
                return nil
            }
            
            let createdAtString = historyDict["createdAt"] as? String ?? ""
            let createdAt = formatter.date(from: createdAtString) ?? Date()
            
            let emotion = historyDict["emotion"] as? Int
            let emotionLabel = historyDict["emotionLabel"] as? String
            let emotionConfidence = historyDict["emotionConfidence"] as? Double
            
            return ChatHistory(
                id: id,
                chatId: chatId,
                userId: userId,
                messageText: messageText,
                type: type,
                emotion: emotion,
                emotionLabel: emotionLabel,
                emotionConfidence: emotionConfidence,
                createdAt: createdAt
            )
        }
    }
    
    func createChatHistory(chatId: String, userId: String, messageText: String, type: String? = nil) async throws -> ChatHistory {
        let query = """
        mutation CreateChatHistory($input: CreateChatHistoryInput!) {
          createChatHistory(input: $input) {
            id
            chatId
            userId
            messageText
            type
            emotion
            emotionLabel
            emotionConfidence
            createdAt
          }
        }
        """
        
        var input: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
            "messageText": messageText
        ]
        
        if let type = type {
            input["type"] = type
        }
        
        let variables: [String: Any] = ["input": input]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let historyDict = data["createChatHistory"] as? [String: Any],
              let id = historyDict["id"] as? String,
              let chatId = historyDict["chatId"] as? String,
              let userId = historyDict["userId"] as? String,
              let messageText = historyDict["messageText"] as? String,
              let type = historyDict["type"] as? String else {
            throw ServiceError.invalidResponse
        }
        
        let createdAtString = historyDict["createdAt"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt = formatter.date(from: createdAtString) ?? Date()
        
        let emotion = historyDict["emotion"] as? Int
        let emotionLabel = historyDict["emotionLabel"] as? String
        let emotionConfidence = historyDict["emotionConfidence"] as? Double
        
        return ChatHistory(
            id: id,
            chatId: chatId,
            userId: userId,
            messageText: messageText,
            type: type,
            emotion: emotion,
            emotionLabel: emotionLabel,
            emotionConfidence: emotionConfidence,
            createdAt: createdAt
        )
    }
    
    func deleteChatHistory(id: String) async throws {
        let query = """
        mutation DeleteChatHistory($id: ID!) {
          deleteChatHistory(id: $id)
        }
        """
        
        let variables: [String: Any] = ["id": id]
        
        _ = try await performRequest(query: query, variables: variables)
    }
}

