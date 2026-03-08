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
        print("[SyncManagerService] initialize called")
        print("[SyncManagerService] Token present: \(authStore.token != nil)")
        print("[SyncManagerService] UserId: \(authStore.userId ?? "nil")")
        
        guard self.authStore == nil || self.authStore?.token != authStore.token else {
            print("[SyncManagerService] Already initialized with same token, skipping")
            return
        }
        
        self.authStore = authStore
        
        print("[SyncManagerService] Creating HealthKitService...")
        let healthKit = HealthKitService()
        print("[SyncManagerService] Creating HealthDataService...")
        let healthData = HealthDataService(authStore: authStore)
        print("[SyncManagerService] Creating HealthDataSyncManager...")
        let sync = HealthDataSyncManager(
            healthKitService: healthKit,
            healthDataService: healthData
        )
        
        self.healthKitService = healthKit
        self.healthDataService = healthData
        self.syncManager = sync
        
        healthKit.onNewDataDetected = { [weak sync] in
            print("[SyncManagerService] New health data detected! Triggering sync...")
            Task { @MainActor in
                await sync?.sendHealthData()
            }
        }
        
        sync.onHealthDataSent = { [weak self] in
            print("[SyncManagerService] Health data was sent successfully!")
            DispatchQueue.main.async {
                self?.healthDataSent.toggle()
            }
        }
        
        print("[SyncManagerService] Scheduling background task...")
        sync.scheduleBackgroundTask()
        print("[SyncManagerService] Starting foreground sync...")
        sync.startForegroundSync()
        print("[SyncManagerService] Initialization complete!")
    }
    
    func stop() {
        healthKitService?.onNewDataDetected = nil
        syncManager?.stopForegroundSync()
        syncManager = nil
        healthKitService = nil
        healthDataService = nil
    }
}

