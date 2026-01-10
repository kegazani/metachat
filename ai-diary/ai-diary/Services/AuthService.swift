import Foundation

class AuthService {
    private let apollo: URLSession
    private let authStore: AuthStore
    
    init(apollo: URLSession, authStore: AuthStore) {
        self.apollo = apollo
        self.authStore = authStore
    }
    
    func login(name: String, password: String) async throws -> String {
        let url = AppConfig.graphQLURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query = """
        mutation Login($input: LoginInput!) {
          login(input: $input)
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "name": name,
                "password": password
            ]
        ]
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        let (data, response) = try await apollo.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let dataDict = json?["data"] as? [String: Any],
              let token = dataDict["login"] as? String else {
            if let errors = json?["errors"] as? [[String: Any]],
               let errorMessage = errors.first?["message"] as? String {
                throw AuthError.serverError(errorMessage)
            }
            throw AuthError.invalidResponse
        }
        
        return token
    }
    
    func createUser(name: String, password: String) async throws {
        let url = AppConfig.graphQLURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query = """
        mutation CreateUser($input: CreateUserInput!) {
          createUser(input: $input) {
            id
            name
            createdAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "name": name,
                "password": password
            ]
        ]
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        let (data, response) = try await apollo.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let errors = json?["errors"] as? [[String: Any]],
           let errorMessage = errors.first?["message"] as? String {
            throw AuthError.serverError(errorMessage)
        }
    }
}

enum AuthError: Error {
    case invalidResponse
    case serverError(String)
}

