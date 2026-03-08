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
        print("[HealthDataSyncManager] startForegroundSync called")
        stopForegroundSync()
        
        Task { @MainActor in
            print("[HealthDataSyncManager] Initial forceSendHealthData call (bypassing timestamp check)")
            await forceSendHealthData()
        }
        
        syncTask = Task {
            while !Task.isCancelled {
                do {
                    print("[HealthDataSyncManager] Waiting 15 seconds for next sync...")
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    print("[HealthDataSyncManager] Timer fired, calling forceSendHealthData")
                    await forceSendHealthData()
                } catch {
                    print("[HealthDataSyncManager] Foreground sync error: \(error.localizedDescription)")
                }
            }
        }
        print("[HealthDataSyncManager] Foreground sync task created")
    }
    
    @MainActor
    func forceSendHealthData() async {
        print("[HealthDataSyncManager] ===== FORCE SEND START =====")
        
        guard !isSending else {
            print("[HealthDataSyncManager] Already sending, skipping")
            return
        }
        
        isSending = true
        defer {
            isSending = false
            print("[HealthDataSyncManager] ===== FORCE SEND END =====")
        }
        
        print("[HealthDataSyncManager] HealthKit authorized: \(healthKitService.isAuthorized)")
        print("[HealthDataSyncManager] Current HR: \(String(describing: healthKitService.currentHeartRate))")
        
        var heartRate = healthKitService.currentHeartRate
        var sdnn = healthKitService.currentSDNN
        
        if heartRate == nil {
            print("[HealthDataSyncManager] No HR from HealthKit, fetching async...")
            let result = await healthKitService.fetchLatestValuesAsync(since: nil)
            heartRate = result.heartRate
            sdnn = result.sdnn
            print("[HealthDataSyncManager] Async fetch result - HR: \(String(describing: heartRate)), SDNN: \(String(describing: sdnn))")
        }
        
        guard let hr = heartRate else {
            print("[HealthDataSyncManager] SKIP: Still no heart rate available")
            print("[HealthDataSyncManager] Trying to send test data with HR=65...")
            await sendTestData()
            return
        }
        
        let finalSDNN = sdnn ?? healthKitService.estimateSDNN(from: hr)
        let rmssd = healthKitService.calculateRMSSD(from: finalSDNN)
        let pnn50 = healthKitService.calculatePNN50(from: rmssd)
        
        print("[HealthDataSyncManager] Sending - HR: \(hr), SDNN: \(String(describing: finalSDNN)), RMSSD: \(String(describing: rmssd)), PNN50: \(String(describing: pnn50))")
        
        do {
            let created = try await healthDataService.sendHealthData(
                heartRate: hr,
                sdnn: finalSDNN,
                rmssd: rmssd,
                pnn50: pnn50
            )
            print("[HealthDataSyncManager] SUCCESS! Created ID: \(created.id ?? "?"), emotion: \(created.emotionLabel ?? "nil")")
            onHealthDataSent?()
        } catch {
            print("[HealthDataSyncManager] SEND FAILED: \(error)")
        }
    }
    
    @MainActor
    private func sendTestData() async {
        print("[HealthDataSyncManager] Sending TEST data (HR=65) to verify connection...")
        do {
            let created = try await healthDataService.sendHealthData(
                heartRate: 65.0,
                sdnn: 45.0,
                rmssd: 36.0,
                pnn50: 20.0
            )
            print("[HealthDataSyncManager] TEST SUCCESS! ID: \(created.id ?? "?"), emotion: \(created.emotionLabel ?? "nil")")
        } catch {
            print("[HealthDataSyncManager] TEST FAILED: \(error)")
        }
    }
    
    func stopForegroundSync() {
        syncTask?.cancel()
        syncTask = nil
    }
    
    @MainActor
    func sendHealthData() async {
        print("[HealthDataSyncManager] ===== sendHealthData START =====")
        
        guard !isSending else {
            print("[HealthDataSyncManager] Already sending health data, skipping")
            return
        }
        
        isSending = true
        defer { 
            isSending = false 
            print("[HealthDataSyncManager] ===== sendHealthData END =====")
        }
        
        let lastSent = lastSentTimestamp ?? healthKitService.getLastSentTimestamp()
        print("[HealthDataSyncManager] Last sent timestamp: \(String(describing: lastSent))")
        print("[HealthDataSyncManager] HealthKit authorized: \(healthKitService.isAuthorized)")
        print("[HealthDataSyncManager] Current HR from HealthKit: \(String(describing: healthKitService.currentHeartRate))")
        
        print("[HealthDataSyncManager] Fetching latest values from HealthKit...")
        let result = await healthKitService.fetchLatestValuesAsync(since: lastSent)
        
        print("[HealthDataSyncManager] Fetch result - heartRate: \(String(describing: result.heartRate)), sdnn: \(String(describing: result.sdnn)), timestamp: \(String(describing: result.timestamp))")
        
        if let hr = result.heartRate {
            print("[HealthDataSyncManager] HeartRate value: \(hr)")
        } else {
            print("[HealthDataSyncManager] WARNING: HeartRate is nil from HealthKit!")
        }
        
        guard result.heartRate != nil || result.sdnn != nil else {
            print("[HealthDataSyncManager] SKIP: No health data values available")
            return
        }
        
        guard let timestamp = result.timestamp else {
            print("[HealthDataSyncManager] SKIP: No timestamp in result")
            return
        }
        
        if let lastSent = lastSent, timestamp <= lastSent {
            print("[HealthDataSyncManager] SKIP: Data not newer - current: \(timestamp), lastSent: \(lastSent)")
            return
        }
        
        print("[HealthDataSyncManager] Data is valid and new, preparing to send...")
        
        let sdnn = result.sdnn ?? healthKitService.estimateSDNN(from: result.heartRate)
        let rmssd = healthKitService.calculateRMSSD(from: sdnn)
        let pnn50 = healthKitService.calculatePNN50(from: rmssd)
        
        print("Calculated HRV metrics - SDNN: \(String(describing: sdnn)), RMSSD: \(String(describing: rmssd)), PNN50: \(String(describing: pnn50))")
        print("[HealthDataSyncManager] About to send - heartRate: \(String(describing: result.heartRate)), sdnn: \(String(describing: sdnn)), rmssd: \(String(describing: rmssd)), pnn50: \(String(describing: pnn50))")
        
        do {
            print("[HealthDataSyncManager] Calling sendHealthData...")
            let createdHealthData = try await healthDataService.sendHealthData(
                heartRate: result.heartRate,
                sdnn: sdnn,
                rmssd: rmssd,
                pnn50: pnn50
            )
            lastSentTimestamp = timestamp
            healthKitService.setLastSentTimestamp(timestamp)
            if let emotionLabel = createdHealthData.emotionLabel {
                print("[HealthDataSyncManager] SUCCESS: Health data sent at \(Date()), timestamp: \(timestamp), emotion: \(emotionLabel)")
            } else {
                print("[HealthDataSyncManager] SUCCESS: Health data sent at \(Date()), timestamp: \(timestamp)")
            }
            onHealthDataSent?()
        } catch let urlError as URLError {
            print("[HealthDataSyncManager] NETWORK ERROR: code=\(urlError.code.rawValue), \(urlError.localizedDescription)")
            print("[HealthDataSyncManager] Failed URL: \(urlError.failureURLString ?? "unknown")")
        } catch {
            print("[HealthDataSyncManager] FAILED: \(type(of: error)) - \(error.localizedDescription)")
            print("[HealthDataSyncManager] Full error: \(error)")
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

