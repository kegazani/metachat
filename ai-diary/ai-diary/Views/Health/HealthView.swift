import SwiftUI
import Combine

class HealthViewObserver: ObservableObject {
    @Published var currentHeartRate: Double?
    @Published var currentSDNN: Double?
    @Published var isAuthorized = false
    @Published var lastUpdate: Date?
    @Published var heartRateTimestamp: Date?
    @Published var sdnnTimestamp: Date?
    @Published var latestEmotion: Int?
    @Published var latestEmotionLabel: String?
    @Published var latestEmotionConfidence: Double?
    
    private var cancellables = Set<AnyCancellable>()
    private weak var currentService: HealthKitService?
    
    func subscribe(to service: HealthKitService?) {
        guard service !== currentService else { return }
        
        cancellables.removeAll()
        currentService = service
        
        guard let service = service else {
            currentHeartRate = nil
            currentSDNN = nil
            isAuthorized = false
            lastUpdate = nil
            heartRateTimestamp = nil
            sdnnTimestamp = nil
            return
        }
        
        currentHeartRate = service.currentHeartRate
        currentSDNN = service.currentSDNN
        isAuthorized = service.isAuthorized
        lastUpdate = service.lastUpdate
        heartRateTimestamp = service.heartRateTimestamp
        sdnnTimestamp = service.sdnnTimestamp
        
        service.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentHeartRate = value
            }
            .store(in: &cancellables)
        
        service.$currentSDNN
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentSDNN = value
            }
            .store(in: &cancellables)
        
        service.$isAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isAuthorized = value
            }
            .store(in: &cancellables)
        
        service.$lastUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.lastUpdate = value
            }
            .store(in: &cancellables)
        
        service.$heartRateTimestamp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.heartRateTimestamp = value
            }
            .store(in: &cancellables)
        
        service.$sdnnTimestamp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.sdnnTimestamp = value
            }
            .store(in: &cancellables)
    }
    
    func refresh() {
        currentService?.manualRefresh()
    }
}

struct HealthView: View {
    @ObservedObject private var syncManager = SyncManagerService.shared
    @EnvironmentObject var authStore: AuthStore
    @StateObject private var observer = HealthViewObserver()
    @State private var healthDataService: HealthDataService?
    
    private var healthKitService: HealthKitService? {
        syncManager.healthKitService
    }
    
    private func getEmotionIcon(emotionId: Int?) -> String {
        guard let emotionId = emotionId else { return "face.smiling" }
        switch emotionId {
        case 1:
            return "face.smiling.fill"
        case 2:
            return "exclamationmark.triangle.fill"
        case 3:
            return "face.smiling.inverse"
        case 4:
            return "leaf.fill"
        default:
            return "face.smiling"
        }
    }
    
    private func getEmotionColor(emotionId: Int?) -> Color {
        guard let emotionId = emotionId else { return Color(white: 0.7) }
        switch emotionId {
        case 1:
            return .green
        case 2:
            return .red
        case 3:
            return .yellow
        case 4:
            return .blue
        default:
            return Color(white: 0.7)
        }
    }
    
    private func fetchLatestEmotion() {
        guard let service = healthDataService,
              let userId = authStore.userId else {
            print("⚠️ Cannot fetch emotion: service or userId is nil")
            return
        }
        
        Task {
            do {
                print("🔄 Fetching latest emotion for user: \(userId)")
                if let latestHealthData = try await service.fetchLatestHealthData(userId: userId) {
                    await MainActor.run {
                        observer.latestEmotion = latestHealthData.emotion
                        observer.latestEmotionLabel = latestHealthData.emotionLabel
                        observer.latestEmotionConfidence = latestHealthData.emotionConfidence
                        
                        if let emotionLabel = latestHealthData.emotionLabel {
                            print("✅ Emotion updated: \(emotionLabel) (confidence: \(latestHealthData.emotionConfidence ?? 0))")
                        } else {
                            print("⚠️ Emotion label is nil in latest health data")
                        }
                    }
                } else {
                    print("⚠️ No health data found for user: \(userId)")
                }
            } catch {
                print("❌ Failed to fetch latest emotion: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Heart Rate")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let heartRate = observer.currentHeartRate {
                            Text("\(Int(heartRate))")
                                .font(.system(size: 72, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("--")
                                .font(.system(size: 72, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        Text("BPM")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if let ts = observer.heartRateTimestamp {
                            Text("Measured: \(ts, style: .relative) ago")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        if let emotionLabel = observer.latestEmotionLabel {
                            HStack(spacing: 8) {
                                Image(systemName: getEmotionIcon(emotionId: observer.latestEmotion))
                                    .font(.system(size: 14))
                                    .foregroundColor(getEmotionColor(emotionId: observer.latestEmotion))
                                Text(emotionLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(getEmotionColor(emotionId: observer.latestEmotion))
                                if let confidence = observer.latestEmotionConfidence {
                                    Text("(\(Int(confidence * 100))%)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    VStack(spacing: 16) {
                        Text("SDNN")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let sdnn = observer.currentSDNN {
                            Text(String(format: "%.1f", sdnn))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("--")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        Text("ms")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if let ts = observer.sdnnTimestamp {
                            Text("Measured: \(ts, style: .relative) ago")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        Text("Updates during sleep or Breathe sessions")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    Button(action: {
                        observer.refresh()
                        fetchLatestEmotion()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Data")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(observer.isAuthorized ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(observer.isAuthorized ? "HealthKit Connected" : "HealthKit Not Authorized")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        if let lastUpdate = observer.lastUpdate {
                            HStack {
                                Text("Last update: \(lastUpdate, style: .time)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    
                    if !observer.isAuthorized {
                        Button(action: {
                            healthKitService?.requestAuthorization()
                        }) {
                            Text("Authorize HealthKit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            healthDataService = HealthDataService(authStore: authStore)
            observer.subscribe(to: healthKitService)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                fetchLatestEmotion()
            }
        }
        .onReceive(syncManager.$healthKitService) { service in
            observer.subscribe(to: service)
        }
        .onReceive(syncManager.$healthDataSent) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                fetchLatestEmotion()
            }
        }
        .onChange(of: observer.currentHeartRate) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                fetchLatestEmotion()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                fetchLatestEmotion()
            }
        }
    }
}

