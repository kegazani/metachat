import Foundation

struct ChatHistory: Identifiable, Codable {
    let id: String
    let chatId: String
    let userId: String
    let messageText: String
    let type: String
    let emotion: Int?
    let emotionLabel: String?
    let emotionConfidence: Double?
    let createdAt: Date
}

