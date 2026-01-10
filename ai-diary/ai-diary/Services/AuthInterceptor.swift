import Foundation

class AuthInterceptor {
    private let authStore: AuthStore
    
    init(authStore: AuthStore) {
        self.authStore = authStore
    }
    
    func addAuthHeader(to request: inout URLRequest) {
        if let token = authStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

