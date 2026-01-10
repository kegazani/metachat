import Foundation
import BackgroundTasks

class HealthDataSyncManager {
    private let healthKitService: HealthKitService
    private let healthDataService: HealthDataService
    private var syncTask: Task<Void, Never>?
    private let taskIdentifier = "com.metachat.healthDataSync"
    private var lastSentTimestamp: Date?
    private var isSending = false
    
    var onHealthDataSent: (() -> Void)?
    
    init(healthKitService: HealthKitService, healthDataService: HealthDataService) {
        self.healthKitService = healthKitService
        self.healthDataService = healthDataService
    }
    
    func startForegroundSync() {
        stopForegroundSync()
        
        Task { @MainActor in
            await sendHealthData()
        }
        
        syncTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    await sendHealthData()
                } catch {
                    print("Foreground sync error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopForegroundSync() {
        syncTask?.cancel()
        syncTask = nil
    }
    
    @MainActor
    func sendHealthData() async {
        guard !isSending else {
            print("Already sending health data, skipping")
            return
        }
        
        isSending = true
        defer { isSending = false }
        
        let lastSent = lastSentTimestamp ?? healthKitService.getLastSentTimestamp()
        print("Fetching health data since: \(String(describing: lastSent))")
        
        let result = await healthKitService.fetchLatestValuesAsync(since: lastSent)
        
        print("Fetched data - heartRate: \(String(describing: result.heartRate)), sdnn: \(String(describing: result.sdnn)), timestamp: \(String(describing: result.timestamp))")
        
        guard result.heartRate != nil || result.sdnn != nil else {
            print("No new health data values available to send")
            return
        }
        
        guard let timestamp = result.timestamp else {
            print("No timestamp available for health data")
            return
        }
        
        if let lastSent = lastSent, timestamp <= lastSent {
            print("Data timestamp (\(timestamp)) is not newer than last sent (\(lastSent)), skipping")
            return
        }
        
        do {
            let createdHealthData = try await healthDataService.sendHealthData(
                heartRate: result.heartRate,
                sdnn: result.sdnn,
                rmssd: nil,
                pnn50: nil
            )
            lastSentTimestamp = timestamp
            healthKitService.setLastSentTimestamp(timestamp)
            if let emotionLabel = createdHealthData.emotionLabel {
                print("Health data sent successfully at \(Date()), data timestamp: \(timestamp), emotion: \(emotionLabel)")
            } else {
                print("Health data sent successfully at \(Date()), data timestamp: \(timestamp)")
            }
            onHealthDataSent?()
        } catch {
            print("Failed to send health data: \(error.localizedDescription)")
        }
    }
    
    
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Failed to schedule background task: \(error.localizedDescription)")
        }
    }
    
    deinit {
        stopForegroundSync()
    }
}

