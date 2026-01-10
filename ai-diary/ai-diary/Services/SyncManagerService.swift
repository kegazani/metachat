import Foundation
import UIKit
import Combine

class SyncManagerService: ObservableObject {
    static let shared = SyncManagerService()
    
    @Published private(set) var healthKitService: HealthKitService?
    @Published var healthDataSent = false
    private var healthDataService: HealthDataService?
    private var syncManager: HealthDataSyncManager?
    private var authStore: AuthStore?
    
    private init() {}
    
    func initialize(authStore: AuthStore) {
        guard self.authStore == nil || self.authStore?.token != authStore.token else {
            return
        }
        
        self.authStore = authStore
        
        let healthKit = HealthKitService()
        let healthData = HealthDataService(authStore: authStore)
        let sync = HealthDataSyncManager(
            healthKitService: healthKit,
            healthDataService: healthData
        )
        
        self.healthKitService = healthKit
        self.healthDataService = healthData
        self.syncManager = sync
        
        healthKit.onNewDataDetected = { [weak sync] in
            Task { @MainActor in
                await sync?.sendHealthData()
            }
        }
        
        sync.onHealthDataSent = { [weak self] in
            DispatchQueue.main.async {
                self?.healthDataSent.toggle()
            }
        }
        
        sync.scheduleBackgroundTask()
        sync.startForegroundSync()
    }
    
    func stop() {
        healthKitService?.onNewDataDetected = nil
        syncManager?.stopForegroundSync()
        syncManager = nil
        healthKitService = nil
        healthDataService = nil
    }
}

