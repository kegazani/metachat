import Foundation

struct HealthData: Codable {
    let id: String?
    let userId: String?
    let heartRate: Double?
    let sdnn: Double?
    let rmssd: Double?
    let pnn50: Double?
    let emotion: Int?
    let emotionLabel: String?
    let emotionConfidence: Double?
    let timestamp: Date
    let createdAt: Date?
}

