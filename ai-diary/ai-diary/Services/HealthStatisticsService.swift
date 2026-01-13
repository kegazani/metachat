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
            let startDateString = formatter.string(from: startDate)
            variables["startDate"] = startDateString
            print("📅 HealthData query - startDate: \(startDateString)")
        }
        
        if let endDate = endDate {
            let endDateString = formatter.string(from: endDate)
            variables["endDate"] = endDateString
            print("📅 HealthData query - endDate: \(endDateString)")
        }
        
        print("🔍 HealthData query - userId: \(userId), limit: \(limit)")
        
        let json = try await performRequest(query: query, variables: variables)
        
        print("📦 HealthData response received")
        
        if let errors = json["errors"] as? [[String: Any]] {
            for error in errors {
                if let message = error["message"] as? String {
                    print("❌ HealthData GraphQL error: \(message)")
                }
            }
            if let errorMessage = errors.first?["message"] as? String {
                throw ServiceError.serverError(errorMessage)
            }
        }
        
        guard let data = json["data"] as? [String: Any] else {
            print("❌ HealthData: No 'data' field in response")
            print("📦 Response: \(json)")
            throw ServiceError.invalidResponse
        }
        
        guard let healthDataArray = data["healthData"] as? [[String: Any]] else {
            print("❌ HealthData: No 'healthData' array in response")
            print("📦 Data: \(data)")
            throw ServiceError.invalidResponse
        }
        
        print("✅ HealthData: Found \(healthDataArray.count) records")
        
        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]
        
        return healthDataArray.compactMap { dict in
            guard let id = dict["id"] as? String else {
                print("⚠️ HealthData: Missing id in record")
                return nil
            }
            
            guard let timestampString = dict["timestamp"] as? String else {
                print("⚠️ HealthData: Missing timestamp in record id=\(id)")
                return nil
            }
            
            var timestamp: Date?
            timestamp = formatter.date(from: timestampString)
            if timestamp == nil {
                timestamp = formatterWithoutFractional.date(from: timestampString)
            }
            if timestamp == nil {
                let rfc3339Formatter = DateFormatter()
                rfc3339Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                timestamp = rfc3339Formatter.date(from: timestampString)
            }
            
            guard let timestamp = timestamp else {
                print("⚠️ HealthData: Failed to parse timestamp '\(timestampString)' for id=\(id)")
                return nil
            }
            
            let heartRate = dict["heartRate"] as? Double
            let sdnn = dict["sdnn"] as? Double
            
            if heartRate != nil || sdnn != nil {
                print("📊 HealthData point: id=\(id), heartRate=\(heartRate ?? 0), sdnn=\(sdnn ?? 0), timestamp=\(timestamp)")
            }
            
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

