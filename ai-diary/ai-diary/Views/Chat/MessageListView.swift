import SwiftUI

struct MessageListView: View {
    let messages: [ChatHistory]
    let currentUserId: String
    let isDiaryChat: Bool
    let onDelete: (String) -> Void
    let onDiaryClick: ((ChatHistory) -> Void)?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if messages.isEmpty {
                    Text("No messages yet. Start the conversation!")
                        .foregroundColor(Color(white: 0.6))
                        .padding()
                } else {
                    ForEach(messages) { message in
                        MessageItemView(
                            message: message,
                            isOwn: message.userId == currentUserId,
                            isDiaryChat: isDiaryChat,
                            onDelete: {
                                onDelete(message.id)
                            },
                            onDiaryClick: isDiaryChat ? {
                                onDiaryClick?(message)
                            } : nil
                        )
                    }
                }
            }
            .padding()
        }
    }
}

