import SwiftUI

struct CreateChatView: View {
    @EnvironmentObject var authStore: AuthStore
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    
    @State private var chatName = ""
    @State private var error: String?
    @State private var isLoading = false
    
    private var chatService: ChatService {
        ChatService(authStore: authStore)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    AppTextField(
                        label: "Chat Name",
                        placeholder: "Enter chat name",
                        text: $chatName
                    )
                    
                    if let error = error {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    
                    AppButton("Create") {
                        Task {
                            await createChat()
                        }
                    }
                    .disabled(isLoading || chatName.isEmpty)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func createChat() async {
        guard let userId = authStore.userId else { return }
        
        isLoading = true
        error = nil
        
        do {
            _ = try await chatService.createChat(name: chatName, userIds: [userId])
            await MainActor.run {
                isPresented = false
                onSuccess()
            }
        } catch {
            await MainActor.run {
                if let serviceError = error as? ServiceError {
                    switch serviceError {
                    case .invalidResponse:
                        self.error = "Invalid response"
                    case .serverError(let message):
                        self.error = message
                    }
                } else {
                    self.error = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}

