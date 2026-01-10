import Foundation

struct AppConfig {
    private static let defaultHost = "169.254.187.55"
    private static let defaultPort = "8080"
    
    static var graphQLURL: URL {
        let host = ProcessInfo.processInfo.environment["GRAPHQL_HOST"] ?? defaultHost
        let port = ProcessInfo.processInfo.environment["GRAPHQL_PORT"] ?? defaultPort
        let urlString = "http://\(host):\(port)/graphql"
        guard let url = URL(string: urlString) else {
            print("Warning: Invalid GraphQL URL: \(urlString), using default")
            return URL(string: "http://\(defaultHost):\(defaultPort)/graphql")!
        }
        return url
    }
    
    static let tokenKey = "auth_token"
}

