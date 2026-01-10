import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var isLogin = true
    @State private var name = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 100)
                    
                    VStack(spacing: 16) {
                        Text("MetaChat")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Color(white: 0.9))
                        
                        Text(isLogin ? "Sign in to continue" : "Create your account")
                            .font(.system(size: 20))
                            .foregroundColor(Color(white: 0.7))
                    }
                    .padding(.bottom, 32)
                    
                    AppCard {
                        VStack(spacing: 20) {
                            AppTextField(
                                label: "Username",
                                placeholder: "Enter your username",
                                text: $name
                            )
                            
                            AppTextField(
                                label: "Password",
                                placeholder: "Enter your password",
                                text: $password,
                                isSecure: true
                            )
                            
                            if let error = error {
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            AppButton(isLogin ? "Login" : "Register") {
                                Task {
                                    await handleSubmit()
                                }
                            }
                            .disabled(isLoading)
                            
                            Button(action: {
                                isLogin.toggle()
                                error = nil
                            }) {
                                Text(isLogin ? "Don't have an account? Register" : "Already have an account? Login")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                        .frame(minHeight: 100)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func handleSubmit() async {
        guard !name.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            if isLogin {
                let token = try await authService.login(name: name, password: password)
                await MainActor.run {
                    authStore.login(token)
                }
            } else {
                try await authService.createUser(name: name, password: password)
                await MainActor.run {
                    isLogin = true
                    error = nil
                }
            }
        } catch let authError as AuthError {
            await MainActor.run {
                switch authError {
                case .invalidResponse:
                    error = "Invalid response from server"
                case .serverError(let message):
                    error = message
                }
            }
        } catch {
            await MainActor.run {
                self.error = "An error occurred"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

