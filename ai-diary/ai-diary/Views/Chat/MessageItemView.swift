import SwiftUI

struct MessageItemView: View {
    let message: ChatHistory
    let isOwn: Bool
    let isDiaryChat: Bool
    let onDelete: () -> Void
    let onDiaryClick: (() -> Void)?
    
    var body: some View {
        HStack {
            if isOwn {
                Spacer()
            }
            
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                Text(message.messageText)
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.9))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isOwn ? Color(white: 0.2) : Color(white: 0.15))
                    )
                
                if let emotionLabel = message.emotionLabel {
                    HStack(spacing: 4) {
                        Image(systemName: getEmotionIcon(emotionId: message.emotion))
                            .font(.system(size: 12))
                            .foregroundColor(getEmotionColor(emotionId: message.emotion))
                        Text(emotionLabel)
                            .font(.system(size: 11))
                            .foregroundColor(getEmotionColor(emotionId: message.emotion))
                        if let confidence = message.emotionConfidence {
                            Text("(\(Int(confidence * 100))%)")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                HStack(spacing: 8) {
                    Text(formatDate(message.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                    
                    if isOwn {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                    
                    if isDiaryChat, let onDiaryClick = onDiaryClick {
                        Button(action: onDiaryClick) {
                            Text("View Details")
                                .font(.system(size: 12))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                    }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isOwn ? .trailing : .leading)
            
            if !isOwn {
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
}

