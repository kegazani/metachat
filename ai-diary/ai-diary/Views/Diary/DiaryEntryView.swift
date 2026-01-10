import SwiftUI

struct DiaryEntryView: View {
    let entry: ChatHistory
    let onViewDetails: () -> Void
    
    var body: some View {
        Button(action: onViewDetails) {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(formatDate(entry.createdAt))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.9))
                        
                        Spacer()
                        
                        if let mood = extractMood(from: entry.messageText) {
                            Text(mood)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(moodColor(mood).opacity(0.2))
                                .foregroundColor(moodColor(mood))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(entry.messageText)
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.9))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AppButton("Подробнее", variant: .secondary) {
                        onViewDetails()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func extractMood(from text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("happy") || lowercased.contains("счастлив") {
            return "happy"
        } else if lowercased.contains("sad") || lowercased.contains("грустн") {
            return "sad"
        } else if lowercased.contains("neutral") || lowercased.contains("нейтрал") {
            return "neutral"
        }
        return nil
    }
    
    private func moodColor(_ mood: String) -> Color {
        switch mood {
        case "happy":
            return .green
        case "sad":
            return .blue
        case "neutral":
            return .gray
        default:
            return .yellow
        }
    }
}

