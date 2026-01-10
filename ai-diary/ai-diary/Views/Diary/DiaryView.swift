import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var authStore: AuthStore
    
    @State private var diaryChatId: String?
    @State private var messages: [ChatHistory] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var isCreating = false
    @State private var selectedEntry: ChatHistory?
    
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
            
            if isLoading && diaryChatId == nil {
                ProgressView()
                    .tint(.white)
            } else if diaryChatId == nil {
                VStack(spacing: 20) {
                    Text("Дневник не найден. Создайте дневник для начала работы.")
                        .foregroundColor(Color(white: 0.6))
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    AppButton("Создать дневник") {
                        Task {
                            await createDiaryChat()
                        }
                    }
                    .disabled(authStore.userId == nil || isCreating)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        AppCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Новая запись")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(white: 0.9))
                                
                                MessageInputView { text in
                                    Task {
                                        await createEntry(text)
                                    }
                                }
                            }
                        }
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Предыдущие записи")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            if diaryEntries.isEmpty {
                                AppCard {
                                    Text("Пока нет записей. Создайте первую запись в дневнике!")
                                        .foregroundColor(Color(white: 0.6))
                                        .multilineTextAlignment(.center)
                                        .padding()
                                }
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(diaryEntries) { entry in
                                        DiaryEntryView(entry: entry) {
                                            selectedEntry = entry
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .task {
            await loadDiaryChat()
            if diaryChatId != nil {
                await loadMessages()
                startPolling()
            }
        }
        .sheet(item: $selectedEntry) { entry in
            DiaryDetailView(entry: entry)
        }
        .navigationTitle("Дневник")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var diaryEntries: [ChatHistory] {
        messages.filter { $0.type == "diary" }
    }
    
    private func loadDiaryChat() async {
        do {
            let chats = try await chatService.fetchChats()
            if let diaryChat = chats.first(where: { $0.name == "Дневник" }) {
                await MainActor.run {
                    self.diaryChatId = diaryChat.id
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func createDiaryChat() async {
        guard let userId = authStore.userId else { return }
        
        isCreating = true
        
        do {
            let chat = try await chatService.createChat(name: "Дневник", userIds: [userId])
            await MainActor.run {
                self.diaryChatId = chat.id
                self.isCreating = false
            }
            await loadMessages()
            startPolling()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isCreating = false
            }
        }
    }
    
    private func loadMessages() async {
        guard let diaryChatId = diaryChatId else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedMessages = try await messageService.fetchChatHistories(chatId: diaryChatId)
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
    
    private func createEntry(_ text: String) async {
        guard let diaryChatId = diaryChatId,
              let userId = authStore.userId,
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        do {
            _ = try await messageService.createChatHistory(
                chatId: diaryChatId,
                userId: userId,
                messageText: text,
                type: "diary"
            )
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

