import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var authStore: AuthStore
    @Binding var navigationPath: NavigationPath
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCreateChat = false
    
    private var chatService: ChatService {
        ChatService(authStore: authStore)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoading && chats.isEmpty {
                ProgressView()
                    .tint(.white)
            } else if let error = error {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    AppButton("Retry") {
                        Task {
                            await loadChats()
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if let diaryChat = diaryChat {
                            NavigationLink(value: "diary") {
                                AppCard {
                                    HStack {
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(diaryChat.name)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(Color(white: 0.9))
                                            
                                            Text("Pinned")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue.opacity(0.8))
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(regularChats) { chat in
                                NavigationLink(value: chat.id) {
                                    AppCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(chat.name)
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(Color(white: 0.9))
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    Task {
                                                        await deleteChat(chat.id)
                                                    }
                                                }) {
                                                    Text("×")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.red.opacity(0.8))
                                                }
                                            }
                                            
                                            Text("\(chat.users.count) \(chat.users.count == 1 ? "participant" : "participants")")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(white: 0.6))
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(chat.users.prefix(3)) { user in
                                                        Text(user.name)
                                                            .font(.system(size: 12))
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.white.opacity(0.1))
                                                            .cornerRadius(4)
                                                            .foregroundColor(Color(white: 0.9))
                                                    }
                                                    if chat.users.count > 3 {
                                                        Text("+\(chat.users.count - 3) more")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(Color(white: 0.6))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showCreateChat = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.2))
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showCreateChat) {
            CreateChatView(isPresented: $showCreateChat) {
                Task {
                    await loadChats()
                }
            }
        }
        .task {
            await loadChats()
        }
    }
    
    private var diaryChat: Chat? {
        chats.first { $0.name == "Дневник" }
    }
    
    private var regularChats: [Chat] {
        chats.filter { $0.name != "Дневник" }
    }
    
    private func loadChats() async {
        isLoading = true
        error = nil
        
        do {
            let fetchedChats = try await chatService.fetchChats()
            await MainActor.run {
                self.chats = fetchedChats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func deleteChat(_ id: String) async {
        do {
            try await chatService.deleteChat(id: id)
            await loadChats()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

