import Foundation

struct Chat: Identifiable, Codable {
    let id: String
    let name: String
    let users: [User]
    let createdAt: Date
    let updatedAt: Date
}

