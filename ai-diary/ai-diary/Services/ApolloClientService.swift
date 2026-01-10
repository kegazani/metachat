import Foundation

class ApolloClientService {
    static let shared = ApolloClientService()
    
    private(set) var apollo: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.apollo = URLSession(configuration: configuration)
    }
}

