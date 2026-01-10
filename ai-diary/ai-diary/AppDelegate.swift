import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    private static var isBackgroundTaskRegistered = false
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        guard !Self.isBackgroundTaskRegistered else {
            return true
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.metachat.healthDataSync", using: nil) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
        Self.isBackgroundTaskRegistered = true
        return true
    }
    
    private func handleBackgroundSync(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task { @MainActor in
            let authStore = AuthStore()
            
            guard authStore.token != nil else {
                task.setTaskCompleted(success: false)
                return
            }
            
            let healthKitService = HealthKitService()
            let healthDataService = HealthDataService(authStore: authStore)
            let syncManager = HealthDataSyncManager(
                healthKitService: healthKitService,
                healthDataService: healthDataService
            )
            
            await syncManager.sendHealthData()
            syncManager.scheduleBackgroundTask()
            task.setTaskCompleted(success: true)
        }
    }
}

