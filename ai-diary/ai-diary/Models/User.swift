import Foundation

struct User: Identifiable, Codable {
    let id: String
    let name: String
    let createdAt: Date
    let updatedAt: Date
}

