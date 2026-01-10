import Foundation
import Combine

class AuthStore: ObservableObject {
    @Published var token: String? {
        didSet {
            if let token = token {
                UserDefaults.standard.set(token, forKey: AppConfig.tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AppConfig.tokenKey)
            }
        }
    }
    
    @Published var userId: String?
    
    var isAuthenticated: Bool {
        token != nil
    }
    
    init() {
        self.token = UserDefaults.standard.string(forKey: AppConfig.tokenKey)
        if let token = token {
            self.userId = JWTDecoder.getUserId(from: token)
        }
    }
    
    func login(_ newToken: String) {
        token = newToken
        userId = JWTDecoder.getUserId(from: newToken)
    }
    
    func logout() {
        token = nil
        userId = nil
    }
}

