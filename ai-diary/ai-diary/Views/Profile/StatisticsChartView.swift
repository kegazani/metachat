import SwiftUI

struct StatisticsChartView: View {
    let dataPoints: [HealthDataPoint]
    
    var body: some View {
        Group {
            if !dataPoints.isEmpty {
                let heartRatePoints = dataPoints.filter { $0.heartRate != nil }.sorted { $0.timestamp < $1.timestamp }
                let sdnnPoints = dataPoints.filter { $0.sdnn != nil }.sorted { $0.timestamp < $1.timestamp }
                
                VStack(spacing: 20) {
                    if !heartRatePoints.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                Text("Heart Rate Over Time")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            SimpleLineChart(
                                data: heartRatePoints.map { ($0.timestamp, $0.heartRate ?? 0) },
                                color: .red,
                                yAxisLabel: "BPM"
                            )
                            .frame(height: 200)
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
                    
                    if !sdnnPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                Text("SDNN Over Time")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            SimpleLineChart(
                                data: sdnnPoints.map { ($0.timestamp, $0.sdnn ?? 0) },
                                color: .blue,
                                yAxisLabel: "ms"
                            )
                            .frame(height: 200)
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
            } else {
                EmptyView()
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
            let padding: CGFloat = 50
            
            if !data.isEmpty {
                let minValue = data.map { $0.1 }.min() ?? 0
                let maxValue = data.map { $0.1 }.max() ?? 100
                let valueRange = maxValue - minValue > 0 ? maxValue - minValue : 1
                let scaleY = (height - padding * 2) / valueRange
                let stepX = data.count > 1 ? (width - padding * 2) / CGFloat(data.count - 1) : 0
                
                ZStack {
                    Path { path in
                        let yMin = height - padding
                        for (index, point) in data.enumerated() {
                            let x = padding + CGFloat(index) * stepX
                            let y = yMin - CGFloat((point.1 - minValue) * scaleY)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2.5)
                    
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .position(
                                x: padding + CGFloat(index) * stepX,
                                y: height - padding - CGFloat((point.1 - minValue) * scaleY)
                            )
                    }
                    
                    if data.count > 0 {
                        VStack {
                            HStack {
                                Text(String(format: "%.0f", maxValue))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text(String(format: "%.0f", minValue))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                        }
                        .padding(.horizontal, padding)
                        .padding(.vertical, padding / 2)
                        
                        HStack {
                            Spacer()
                            Text(yAxisLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.trailing, padding)
                                .padding(.top, 8)
                        }
                    }
                }
            } else {
                VStack {
                    Text("No data available")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

