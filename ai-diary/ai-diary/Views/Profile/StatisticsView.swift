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
        ScrollView {
            VStack(spacing: 24) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedPeriod) { _ in
                    Task {
                        await loadStatistics()
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding()
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if let statistics = statistics {
                    if statistics.dataPoints.isEmpty {
                        Text("No data available for this period")
                            .foregroundColor(Color(white: 0.6))
                            .padding()
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
        .task {
            await loadStatistics()
        }
    }
    
    private func loadStatistics() async {
        guard let userId = authStore.userId else { return }
        
        isLoading = true
        error = nil
        
        do {
            let (startDate, endDate) = statisticsService.getDateRange(for: selectedPeriod)
            let dataPoints = try await statisticsService.fetchHealthData(
                userId: userId,
                startDate: startDate,
                endDate: endDate
            )
            let stats = statisticsService.calculateStatistics(from: dataPoints)
            
            await MainActor.run {
                self.statistics = stats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct HeartRateStatisticsCard: View {
    let statistics: HealthStatistics
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Heart Rate")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(white: 0.9))
                
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
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
    }
}

struct SDNNStatisticsCard: View {
    let statistics: HealthStatistics
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("SDNN")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(white: 0.9))
                
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
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(white: 0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(white: 0.9))
        }
    }
}

