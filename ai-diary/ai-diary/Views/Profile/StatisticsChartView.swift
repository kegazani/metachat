import SwiftUI

struct StatisticsChartView: View {
    let dataPoints: [HealthDataPoint]
    
    var body: some View {
        VStack(spacing: 20) {
            if !dataPoints.isEmpty {
                let heartRatePoints = dataPoints.filter { $0.heartRate != nil }.sorted { $0.timestamp < $1.timestamp }
                let sdnnPoints = dataPoints.filter { $0.sdnn != nil }.sorted { $0.timestamp < $1.timestamp }
                
                if !heartRatePoints.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Heart Rate Over Time")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            SimpleLineChart(
                                data: heartRatePoints.map { ($0.timestamp, $0.heartRate ?? 0) },
                                color: .red,
                                yAxisLabel: "BPM"
                            )
                            .frame(height: 200)
                        }
                    }
                }
                
                if !sdnnPoints.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SDNN Over Time")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            SimpleLineChart(
                                data: sdnnPoints.map { ($0.timestamp, $0.sdnn ?? 0) },
                                color: .blue,
                                yAxisLabel: "ms"
                            )
                            .frame(height: 200)
                        }
                    }
                }
            }
        }
    }
}

struct SimpleLineChart: View {
    let data: [(Date, Double)]
    let color: Color
    let yAxisLabel: String
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let padding: CGFloat = 40
            
            if !data.isEmpty {
                let minValue = data.map { $0.1 }.min() ?? 0
                let maxValue = data.map { $0.1 }.max() ?? 100
                let valueRange = maxValue - minValue
                let scaleY = valueRange > 0 ? (height - padding * 2) / valueRange : 1.0
                let stepX = data.count > 1 ? (width - padding * 2) / CGFloat(data.count - 1) : 0
                
                ZStack {
                    Path { path in
                        for (index, point) in data.enumerated() {
                            let x = padding + CGFloat(index) * stepX
                            let y = height - padding - CGFloat((point.1 - minValue) * scaleY)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2)
                    
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(
                                x: padding + CGFloat(index) * stepX,
                                y: height - padding - CGFloat((point.1 - minValue) * scaleY)
                            )
                    }
                }
            } else {
                Text("No data available")
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }
}

