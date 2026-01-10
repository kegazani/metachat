import Foundation

struct Diary: Identifiable {
    let id: String
    let userId: String
    let chatId: String
    let data: [String: Any]
    let createdAt: Date
    let updatedAt: Date
}

