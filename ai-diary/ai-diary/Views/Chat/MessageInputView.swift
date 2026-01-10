import SwiftUI

struct MessageInputView: View {
    let onSend: (String) -> Void
    
    @State private var messageText = ""
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .foregroundColor(Color(white: 0.9))
                .lineLimit(1...5)
            
            Button(action: {
                let text = messageText
                messageText = ""
                onSend(text)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? Color.white.opacity(0.3) : .blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
}

