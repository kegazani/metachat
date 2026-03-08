import Foundation

class HealthDataService {
    private let authStore: AuthStore
    
    init(authStore: AuthStore) {
        self.authStore = authStore
    }
    
    private func performRequest(query: String, variables: [String: Any]) async throws -> [String: Any] {
        let url = AppConfig.graphQLURL
        print("[HealthDataService] Request URL: \(url)")
        print("[HealthDataService] Token present: \(authStore.token != nil)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("[HealthDataService] WARNING: No auth token available!")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        request.timeoutInterval = 30
        
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[HealthDataService] Request body: \(bodyString)")
        }
        
        let session = ApolloClientService.shared.apollo
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[HealthDataService] ERROR: Response is not HTTPURLResponse")
                throw ServiceError.invalidResponse
            }
            
            print("[HealthDataService] Response status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("[HealthDataService] Response body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("[HealthDataService] ERROR: HTTP status \(httpResponse.statusCode)")
                throw ServiceError.invalidResponse
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let errors = json?["errors"] as? [[String: Any]],
               let errorMessage = errors.first?["message"] as? String {
                print("[HealthDataService] GraphQL error: \(errorMessage)")
                throw ServiceError.serverError(errorMessage)
            }
            
            return json ?? [:]
        } catch let urlError as URLError {
            print("[HealthDataService] URLError: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            throw urlError
        } catch {
            print("[HealthDataService] Request error: \(error)")
            throw error
        }
    }
    
    func sendHealthData(heartRate: Double?, sdnn: Double?, rmssd: Double?, pnn50: Double?) async throws -> HealthData {
        print("[HealthDataService] ========== sendHealthData CALLED ==========")
        print("[HealthDataService] Parameters - HR: \(String(describing: heartRate)), SDNN: \(String(describing: sdnn))")
        
        let query = """
        mutation CreateHealthData($input: CreateHealthDataInput!) {
          createHealthData(input: $input) {
            id
            userId
            heartRate
            sdnn
            rmssd
            pnn50
            emotion
            emotionLabel
            emotionConfidence
            timestamp
            createdAt
          }
        }
        """
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var input: [String: Any] = [
            "timestamp": formatter.string(from: Date())
        ]
        
        if let heartRate = heartRate {
            print("[HealthDataService] Adding heartRate to input: \(heartRate)")
            input["heartRate"] = heartRate
        } else {
            print("[HealthDataService] WARNING: heartRate is nil, not adding to input")
        }
        
        if let sdnn = sdnn {
            input["sdnn"] = sdnn
        }
        
        if let rmssd = rmssd {
            input["rmssd"] = rmssd
        }
        
        if let pnn50 = pnn50 {
            input["pnn50"] = pnn50
        }
        
        let variables: [String: Any] = [
            "input": input
        ]
        
        let json = try await performRequest(query: query, variables: variables)
        
        if let errors = json["errors"] as? [[String: Any]] {
            for error in errors {
                if let message = error["message"] as? String {
                    print("❌ GraphQL Error: \(message)")
                }
            }
            throw ServiceError.serverError("GraphQL errors occurred")
        }
        
        guard let data = json["data"] as? [String: Any],
              let healthDataDict = data["createHealthData"] as? [String: Any] else {
            print("❌ Invalid response structure: \(json)")
            throw ServiceError.invalidResponse
        }
        
        print("📊 Created HealthData response: \(healthDataDict)")
        
        return try parseHealthData(from: healthDataDict)
    }
    
    func fetchLatestHealthData(userId: String) async throws -> HealthData? {
        let query = """
        query HealthData($userId: ID!, $limit: Int) {
          healthData(userId: $userId, limit: $limit) {
            id
            userId
            heartRate
            sdnn
            rmssd
            pnn50
            emotion
            emotionLabel
            emotionConfidence
            timestamp
            createdAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "userId": userId,
            "limit": 1
        ]
        
        let json = try await performRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let healthDataArray = data["healthData"] as? [[String: Any]] else {
            print("⚠️ No healthData array in response")
            return nil
        }
        
        guard !healthDataArray.isEmpty, let healthDataDict = healthDataArray.first else {
            print("⚠️ HealthData array is empty")
            return nil
        }
        
        print("📊 HealthData from server: \(healthDataDict)")
        
        do {
            let parsed = try parseHealthData(from: healthDataDict)
            if let emotionLabel = parsed.emotionLabel, let emotion = parsed.emotion {
                print("✅ Parsed HealthData - emotion: \(emotion), label: \(emotionLabel), confidence: \(parsed.emotionConfidence ?? 0)")
            } else {
                print("⚠️ Parsed HealthData - emotion is null, heartRate: \(parsed.heartRate ?? -1). AI service may not be running or heart rate is nil.")
            }
            return parsed
        } catch {
            print("❌ Failed to parse HealthData: \(error)")
            return nil
        }
    }
    
    private func parseHealthData(from dict: [String: Any]) throws -> HealthData {
        guard let id = dict["id"] as? String else {
            print("❌ Missing id in HealthData")
            throw ServiceError.invalidResponse
        }
        
        var timestamp: Date?
        if let timestampString = dict["timestamp"] as? String {
            let formatter1 = ISO8601DateFormatter()
            formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            
            timestamp = formatter1.date(from: timestampString) ?? formatter2.date(from: timestampString)
            
            if timestamp == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                timestamp = dateFormatter.date(from: timestampString)
            }
        }
        
        guard let timestamp = timestamp else {
            print("❌ Failed to parse timestamp: \(dict["timestamp"] ?? "nil")")
            throw ServiceError.invalidResponse
        }
        
        var createdAt: Date? = nil
        if let createdAtString = dict["createdAt"] as? String {
            let formatter1 = ISO8601DateFormatter()
            formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            
            createdAt = formatter1.date(from: createdAtString) ?? formatter2.date(from: createdAtString)
        }
        
        var emotion: Int? = nil
        if let emotionValue = dict["emotion"], !(emotionValue is NSNull) {
            if let emotionInt = emotionValue as? Int {
                emotion = emotionInt
            } else if let emotionDouble = emotionValue as? Double {
                emotion = Int(emotionDouble)
            } else if let emotionString = emotionValue as? String, let emotionInt = Int(emotionString) {
                emotion = emotionInt
            }
        }
        
        var emotionConfidence: Double? = nil
        if let confidenceValue = dict["emotionConfidence"], !(confidenceValue is NSNull) {
            if let confidenceDouble = confidenceValue as? Double {
                emotionConfidence = confidenceDouble
            } else if let confidenceString = confidenceValue as? String, let confidenceDouble = Double(confidenceString) {
                emotionConfidence = confidenceDouble
            }
        }
        
        var emotionLabel: String? = nil
        if let labelValue = dict["emotionLabel"], !(labelValue is NSNull) {
            if let labelString = labelValue as? String {
                emotionLabel = labelString
            }
        }
        
        return HealthData(
            id: id,
            userId: dict["userId"] as? String,
            heartRate: dict["heartRate"] as? Double,
            sdnn: dict["sdnn"] as? Double,
            rmssd: dict["rmssd"] as? Double,
            pnn50: dict["pnn50"] as? Double,
            emotion: emotion,
            emotionLabel: emotionLabel,
            emotionConfidence: emotionConfidence,
            timestamp: timestamp,
            createdAt: createdAt
        )
    }
}

