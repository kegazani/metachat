import Foundation
import HealthKit
import Combine

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var currentHeartRate: Double?
    @Published var currentSDNN: Double?
    @Published var isAuthorized = false
    @Published var lastUpdate: Date?
    @Published var heartRateTimestamp: Date?
    @Published var sdnnTimestamp: Date?
    
    private var heartRateObserver: HKObserverQuery?
    private var sdnnObserver: HKObserverQuery?
    private var refreshTask: Task<Void, Never>?
    
    private let heartRateAnchorKey = "healthKit_heartRate_anchor"
    private let sdnnAnchorKey = "healthKit_sdnn_anchor"
    private var lastSentTimestamp: Date?
    
    var onNewDataDetected: (() -> Void)?
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let typesToRead: Set<HKObjectType> = [heartRateType, sdnnType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.enableBackgroundDelivery()
                    self?.setupObservers()
                    self?.fetchLatestValues()
                    self?.startPeriodicRefresh()
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func enableBackgroundDelivery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery for heart rate: \(error.localizedDescription)")
            }
        }
        
        healthStore.enableBackgroundDelivery(for: sdnnType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery for SDNN: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupObservers() {
        setupHeartRateObserver()
        setupSDNNObserver()
    }
    
    private func setupHeartRateObserver() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let observer = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("Heart rate observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            print("Heart rate observer triggered - fetching new data")
            self?.fetchLatestHeartRate()
            completionHandler()
        }
        
        heartRateObserver = observer
        healthStore.execute(observer)
    }
    
    private func setupSDNNObserver() {
        guard let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        let observer = HKObserverQuery(sampleType: sdnnType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("SDNN observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            print("SDNN observer triggered - fetching new data")
            self?.fetchLatestSDNN()
            completionHandler()
        }
        
        sdnnObserver = observer
        healthStore.execute(observer)
    }
    
    func fetchLatestValues() {
        fetchLatestHeartRate()
        fetchLatestSDNN()
    }
    
    func fetchLatestValuesAsync(since lastSentDate: Date? = nil) async -> (heartRate: Double?, sdnn: Double?, timestamp: Date?) {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var heartRateCompleted = false
            var sdnnCompleted = false
            var fetchedHeartRate: Double?
            var fetchedSDNN: Double?
            var latestTimestamp: Date?
            var didResume = false
            
            let checkCompletion = {
                lock.lock()
                let shouldResume = heartRateCompleted && sdnnCompleted && !didResume
                if shouldResume {
                    didResume = true
                }
                let hr = fetchedHeartRate
                let sd = fetchedSDNN
                let ts = latestTimestamp
                lock.unlock()
                
                if shouldResume {
                    continuation.resume(returning: (hr, sd, ts))
                }
            }
            
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
                  let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
                continuation.resume(returning: (nil, nil, nil))
                return
            }
            
            let heartRateSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let heartRateQuery = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [heartRateSortDescriptor]) { query, samples, error in
                if let error = error {
                    print("Heart rate query error: \(error.localizedDescription)")
                    lock.lock()
                    heartRateCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    lock.lock()
                    heartRateCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                let sampleEndDate = sample.endDate
                
                if let lastSent = lastSentDate, sampleEndDate <= lastSent {
                    lock.lock()
                    heartRateCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                DispatchQueue.main.async {
                    lock.lock()
                    fetchedHeartRate = heartRate
                    if latestTimestamp == nil || sampleEndDate > latestTimestamp! {
                        latestTimestamp = sampleEndDate
                    }
                    heartRateCompleted = true
                    lock.unlock()
                    
                    self.currentHeartRate = heartRate
                    self.lastUpdate = Date()
                    checkCompletion()
                }
            }
            
            let sdnnSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let sdnnQuery = HKSampleQuery(sampleType: sdnnType, predicate: nil, limit: 1, sortDescriptors: [sdnnSortDescriptor]) { query, samples, error in
                if let error = error {
                    print("SDNN query error: \(error.localizedDescription)")
                    lock.lock()
                    sdnnCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    lock.lock()
                    sdnnCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                let sdnnUnit = HKUnit.secondUnit(with: .milli)
                let sdnn = sample.quantity.doubleValue(for: sdnnUnit)
                let sampleEndDate = sample.endDate
                
                if let lastSent = lastSentDate, sampleEndDate <= lastSent {
                    lock.lock()
                    sdnnCompleted = true
                    lock.unlock()
                    checkCompletion()
                    return
                }
                
                DispatchQueue.main.async {
                    lock.lock()
                    fetchedSDNN = sdnn
                    if latestTimestamp == nil || sampleEndDate > latestTimestamp! {
                        latestTimestamp = sampleEndDate
                    }
                    sdnnCompleted = true
                    lock.unlock()
                    
                    self.currentSDNN = sdnn
                    self.lastUpdate = Date()
                    checkCompletion()
                }
            }
            
            healthStore.execute(heartRateQuery)
            healthStore.execute(sdnnQuery)
        }
    }
    
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .minute, value: -30, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            if let error = error {
                print("Error fetching heart rate: \(error.localizedDescription)")
                return
            }
            
            guard let self = self else { return }
            
            if let sample = samples?.first as? HKQuantitySample {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
                let sampleDate = sample.endDate
                
                print("Fetched heart rate: \(heartRate) at \(sampleDate)")
                
                DispatchQueue.main.async {
                    let oldValue = self.currentHeartRate
                    let oldTimestamp = self.heartRateTimestamp
                    
                    self.currentHeartRate = heartRate
                    self.heartRateTimestamp = sampleDate
                    self.lastUpdate = Date()
                    
                    if oldValue != heartRate || oldTimestamp != sampleDate {
                        print("Heart rate changed: \(oldValue ?? 0) -> \(heartRate), timestamp: \(sampleDate)")
                        self.onNewDataDetected?()
                    } else {
                        print("Heart rate unchanged: \(heartRate), sample from: \(sampleDate)")
                    }
                }
            } else {
                print("No heart rate samples found in last 30 minutes, trying statistics query to trigger sync")
                self.triggerHealthKitSync(for: heartRateType) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.fetchLatestHeartRate()
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func triggerHealthKitSync(for sampleType: HKQuantityType, completion: (() -> Void)? = nil) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        
        let statisticsQuery = HKStatisticsQuery(
            quantityType: sampleType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate),
            options: [.mostRecent]
        ) { query, statistics, error in
            if let error = error {
                print("Statistics query error: \(error.localizedDescription)")
                completion?()
                return
            }
            
            print("Statistics query completed - sync triggered with Apple Watch")
            completion?()
        }
        
        healthStore.execute(statisticsQuery)
    }
    
    private func fetchLatestSDNN() {
        guard let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sdnnType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            if let error = error {
                print("Error fetching SDNN: \(error.localizedDescription)")
                return
            }
            
            guard let self = self else { return }
            
            if let sample = samples?.first as? HKQuantitySample {
                let sdnnUnit = HKUnit.secondUnit(with: .milli)
                let sdnn = sample.quantity.doubleValue(for: sdnnUnit)
                let sampleDate = sample.endDate
                
                DispatchQueue.main.async {
                    let oldValue = self.currentSDNN
                    let oldTimestamp = self.sdnnTimestamp
                    
                    self.currentSDNN = sdnn
                    self.sdnnTimestamp = sampleDate
                    self.lastUpdate = Date()
                    
                    if oldValue != sdnn || oldTimestamp != sampleDate {
                        print("SDNN changed: \(oldValue ?? 0) -> \(sdnn), timestamp: \(sampleDate)")
                        self.onNewDataDetected?()
                    } else {
                        print("SDNN unchanged: \(sdnn), sample from: \(sampleDate)")
                    }
                }
            } else {
                print("No SDNN samples found in last 24 hours")
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateRMSSD(from sdnn: Double?) -> Double? {
        guard let sdnn = sdnn else { return nil }
        let rmssd = 0.8 * sdnn
        return max(5.0, min(150.0, rmssd))
    }
    
    func calculatePNN50(from rmssd: Double?) -> Double? {
        guard let rmssd = rmssd, rmssd > 0 else { return 0.0 }
        let pnn50 = 100.0 * Darwin.erfc(50.0 / (rmssd * sqrt(2.0)))
        return max(0.0, min(100.0, pnn50))
    }
    
    func estimateSDNN(from heartRate: Double?) -> Double? {
        guard let heartRate = heartRate, heartRate > 0 else { return nil }
        let meanRR = 60000.0 / heartRate
        let sdnn = 0.05 * meanRR
        return max(10.0, min(200.0, sdnn))
    }
    
    func getCalculatedHRVMetrics() -> (sdnn: Double?, rmssd: Double?, pnn50: Double?) {
        let sdnn = currentSDNN ?? estimateSDNN(from: currentHeartRate)
        let rmssd = calculateRMSSD(from: sdnn)
        let pnn50 = calculatePNN50(from: rmssd)
        return (sdnn, rmssd, pnn50)
    }
    
    func getCurrentHealthData(timestamp: Date? = nil) -> HealthData {
        let metrics = getCalculatedHRVMetrics()
        return HealthData(
            id: nil,
            userId: nil,
            heartRate: currentHeartRate,
            sdnn: metrics.sdnn,
            rmssd: metrics.rmssd,
            pnn50: metrics.pnn50,
            emotion: nil,
            emotionLabel: nil,
            emotionConfidence: nil,
            timestamp: timestamp ?? Date(),
            createdAt: nil
        )
    }
    
    func setLastSentTimestamp(_ date: Date) {
        lastSentTimestamp = date
    }
    
    func getLastSentTimestamp() -> Date? {
        return lastSentTimestamp
    }
    
    func manualRefresh() {
        print("Manual refresh triggered - forcing sync with Apple Watch")
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            fetchLatestValues()
            return
        }
        
        triggerHealthKitSync(for: heartRateType) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.fetchLatestValues()
            }
        }
    }
    
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    guard let self = self else { break }
                    print("Periodic refresh triggered at \(Date())")
                    self.fetchLatestValues()
                } catch {
                    break
                }
            }
        }
    }
    
    func refreshOnAppBecomeActive() {
        print("App became active - refreshing health data")
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            fetchLatestValues()
            return
        }
        
        triggerHealthKitSync(for: heartRateType) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fetchLatestValues()
            }
        }
    }
    
    deinit {
        refreshTask?.cancel()
        if let observer = heartRateObserver {
            healthStore.stop(observer)
        }
        if let observer = sdnnObserver {
            healthStore.stop(observer)
        }
    }
}

