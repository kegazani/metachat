import Foundation

class UserService {
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
    
    func fetchUsers(limit: Int = 100, offset: Int = 0) async throws -> [User] {
        let query = """
        query Users($limit: Int, $offset: Int) {
          users(limit: $limit, offset: $offset) {
            id
            name
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
              let usersArray = data["users"] as? [[String: Any]] else {
            throw ServiceError.invalidResponse
        }
        
        return usersArray.map { userDict in
            User(
                id: userDict["id"] as? String ?? "",
                name: userDict["name"] as? String ?? "",
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
    
    func createUser(name: String, password: String) async throws -> User {
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
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let userDict = data["createUser"] as? [String: Any],
              let id = userDict["id"] as? String,
              let name = userDict["name"] as? String else {
            throw ServiceError.invalidResponse
        }
        
        return User(
            id: id,
            name: name,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func updateUser(id: String, name: String?, password: String?) async throws -> User {
        let query = """
        mutation UpdateUser($input: UpdateUserInput!) {
          updateUser(input: $input) {
            id
            name
            updatedAt
          }
        }
        """
        
        var input: [String: Any] = ["id": id]
        if let name = name {
            input["name"] = name
        }
        if let password = password {
            input["password"] = password
        }
        
        let variables: [String: Any] = ["input": input]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let userDict = data["updateUser"] as? [String: Any],
              let userId = userDict["id"] as? String,
              let userName = userDict["name"] as? String else {
            throw ServiceError.invalidResponse
        }
        
        return User(
            id: userId,
            name: userName,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func deleteUser(id: String) async throws {
        let query = """
        mutation DeleteUser($id: ID!) {
          deleteUser(id: $id)
        }
        """
        
        let variables: [String: Any] = ["id": id]
        
        _ = try await performRequest(query: query, variables: variables)
    }
}

