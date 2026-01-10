import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authStore: AuthStore
    let chatId: String
    
    @State private var chat: Chat?
    @State private var messages: [ChatHistory] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showDiaryDetail: ChatHistory?
    
    private var chatService: ChatService {
        ChatService(authStore: authStore)
    }
    
    private var messageService: MessageService {
        MessageService(authStore: authStore)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let chat = chat {
                    AppCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chat.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            Text("\(chat.users.count) \(chat.users.count == 1 ? "participant" : "participants")")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.6))
                        }
                    }
                    .padding()
                }
                
                if isLoading && messages.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if let error = error {
                    Spacer()
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Spacer()
                } else {
                    MessageListView(
                        messages: messages,
                        currentUserId: authStore.userId ?? "",
                        isDiaryChat: chat?.name == "Дневник",
                        onDelete: { messageId in
                            Task {
                                await deleteMessage(messageId)
                            }
                        },
                        onDiaryClick: { message in
                            showDiaryDetail = message
                        }
                    )
                }
                
                MessageInputView { text in
                    Task {
                        await sendMessage(text)
                    }
                }
            }
        }
        .task {
            await loadChat()
            await loadMessages()
            startPolling()
        }
        .sheet(item: $showDiaryDetail) { message in
            DiaryDetailView(entry: message)
        }
        .navigationTitle(chat?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadChat() async {
        do {
            let fetchedChat = try await chatService.fetchChat(id: chatId)
            await MainActor.run {
                self.chat = fetchedChat
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        error = nil
        
        do {
            let fetchedMessages = try await messageService.fetchChatHistories(chatId: chatId)
            await MainActor.run {
                self.messages = fetchedMessages
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage(_ text: String) async {
        guard let userId = authStore.userId, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let isDiary = chat?.name == "Дневник"
        
        do {
            _ = try await messageService.createChatHistory(
                chatId: chatId,
                userId: userId,
                messageText: text,
                type: isDiary ? "diary" : nil
            )
            await loadMessages()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func deleteMessage(_ id: String) async {
        do {
            try await messageService.deleteChatHistory(id: id)
            await loadMessages()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func startPolling() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await loadMessages()
            }
        }
    }
}

