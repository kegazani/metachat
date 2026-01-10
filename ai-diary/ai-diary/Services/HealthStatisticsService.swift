import Foundation

struct HealthDataPoint: Identifiable {
    let id: String
    let heartRate: Double?
    let sdnn: Double?
    let timestamp: Date
}

struct HealthStatistics {
    let heartRateAverage: Double?
    let heartRateMin: Double?
    let heartRateMax: Double?
    let sdnnAverage: Double?
    let sdnnMin: Double?
    let sdnnMax: Double?
    let dataPoints: [HealthDataPoint]
}

class HealthStatisticsService {
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
    
    func fetchHealthData(userId: String, startDate: Date?, endDate: Date?, limit: Int = 1000) async throws -> [HealthDataPoint] {
        let query = """
        query HealthData($userId: ID!, $startDate: Time, $endDate: Time, $limit: Int, $offset: Int) {
          healthData(userId: $userId, startDate: $startDate, endDate: $endDate, limit: $limit, offset: $offset) {
            id
            userId
            heartRate
            sdnn
            timestamp
            createdAt
          }
        }
        """
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var variables: [String: Any] = [
            "userId": userId,
            "limit": limit,
            "offset": 0
        ]
        
        if let startDate = startDate {
            variables["startDate"] = formatter.string(from: startDate)
        }
        
        if let endDate = endDate {
            variables["endDate"] = formatter.string(from: endDate)
        }
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let healthDataArray = data["healthData"] as? [[String: Any]] else {
            throw ServiceError.invalidResponse
        }
        
        return healthDataArray.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let timestampString = dict["timestamp"] as? String,
                  let timestamp = formatter.date(from: timestampString) else {
                return nil
            }
            
            let heartRate = dict["heartRate"] as? Double
            let sdnn = dict["sdnn"] as? Double
            
            return HealthDataPoint(
                id: id,
                heartRate: heartRate,
                sdnn: sdnn,
                timestamp: timestamp
            )
        }
    }
    
    func calculateStatistics(from dataPoints: [HealthDataPoint]) -> HealthStatistics {
        let heartRates = dataPoints.compactMap { $0.heartRate }
        let sdnnValues = dataPoints.compactMap { $0.sdnn }
        
        let heartRateAverage = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        let heartRateMin = heartRates.min()
        let heartRateMax = heartRates.max()
        
        let sdnnAverage = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)
        let sdnnMin = sdnnValues.min()
        let sdnnMax = sdnnValues.max()
        
        return HealthStatistics(
            heartRateAverage: heartRateAverage,
            heartRateMin: heartRateMin,
            heartRateMax: heartRateMax,
            sdnnAverage: sdnnAverage,
            sdnnMin: sdnnMin,
            sdnnMax: sdnnMax,
            dataPoints: dataPoints
        )
    }
    
    func getDateRange(for period: StatisticsPeriod) -> (startDate: Date, endDate: Date) {
        let endDate = Date()
        let calendar = Calendar.current
        var startDate: Date
        
        switch period {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
        
        return (startDate, endDate)
    }
}

enum StatisticsPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "Year"
}

