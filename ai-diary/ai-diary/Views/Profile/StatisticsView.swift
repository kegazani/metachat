import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var selectedPeriod: StatisticsPeriod = .day
    @State private var statistics: HealthStatistics?
    @State private var isLoading = false
    @State private var error: String?
    
    private var statisticsService: HealthStatisticsService {
        HealthStatisticsService(authStore: authStore)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedPeriod) { _ in
                            Task {
                                await loadStatistics()
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await loadStatistics()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else if let error = error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red.opacity(0.7))
                            Text("Error: \(error)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else if let statistics = statistics {
                        if statistics.dataPoints.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No data available for this period")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 60)
                        } else {
                            VStack(spacing: 20) {
                                HeartRateStatisticsCard(statistics: statistics)
                                
                                SDNNStatisticsCard(statistics: statistics)
                                
                                if !statistics.dataPoints.isEmpty {
                                    StatisticsChartView(dataPoints: statistics.dataPoints)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .task {
            await loadStatistics()
        }
    }
    
    private func loadStatistics() async {
        guard let userId = authStore.userId else {
            print("❌ StatisticsView: No userId found")
            return
        }
        
        print("🔄 StatisticsView: Loading statistics for period: \(selectedPeriod.rawValue), userId: \(userId)")
        
        isLoading = true
        error = nil
        
        do {
            let (startDate, endDate) = statisticsService.getDateRange(for: selectedPeriod)
            print("📅 StatisticsView: Date range - start: \(startDate), end: \(endDate)")
            
            let dataPoints = try await statisticsService.fetchHealthData(
                userId: userId,
                startDate: startDate,
                endDate: endDate
            )
            
            print("📊 StatisticsView: Received \(dataPoints.count) data points")
            
            let stats = statisticsService.calculateStatistics(from: dataPoints)
            
            await MainActor.run {
                self.statistics = stats
                self.isLoading = false
                print("✅ StatisticsView: Statistics loaded successfully")
                print("   - HeartRate average: \(stats.heartRateAverage ?? 0)")
                print("   - SDNN average: \(stats.sdnnAverage ?? 0)")
                print("   - Total data points: \(stats.dataPoints.count)")
            }
        } catch {
            print("❌ StatisticsView: Error loading statistics: \(error)")
            await MainActor.run {
                if let serviceError = error as? ServiceError {
                    switch serviceError {
                    case .invalidResponse:
                        self.error = "Invalid response from server"
                    case .serverError(let message):
                        self.error = "Server error: \(message)"
                    }
                } else {
                    self.error = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}

struct HeartRateStatisticsCard: View {
    let statistics: HealthStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if let average = statistics.heartRateAverage {
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Average", value: String(format: "%.1f BPM", average))
                    if let min = statistics.heartRateMin {
                        StatRow(label: "Minimum", value: String(format: "%.1f BPM", min))
                    }
                    if let max = statistics.heartRateMax {
                        StatRow(label: "Maximum", value: String(format: "%.1f BPM", max))
                    }
                }
            } else {
                Text("No heart rate data available")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
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
    }
}

struct SDNNStatisticsCard: View {
    let statistics: HealthStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("SDNN")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if let average = statistics.sdnnAverage {
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Average", value: String(format: "%.2f ms", average))
                    if let min = statistics.sdnnMin {
                        StatRow(label: "Minimum", value: String(format: "%.2f ms", min))
                    }
                    if let max = statistics.sdnnMax {
                        StatRow(label: "Maximum", value: String(format: "%.2f ms", max))
                    }
                }
            } else {
                Text("No SDNN data available")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
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
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

