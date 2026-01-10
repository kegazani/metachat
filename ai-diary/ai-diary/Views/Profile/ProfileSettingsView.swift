import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var currentUser: User?
    @State private var isLoading = false
    @State private var error: String?
    
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var passwordError: String?
    @State private var passwordSuccess: String?
    
    private var userService: UserService {
        UserService(authStore: authStore)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading && currentUser == nil {
                    ProgressView()
                        .tint(.white)
                        .padding()
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if let user = currentUser {
                    AppCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("User Information")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(white: 0.7))
                                
                                Text(user.name)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(white: 0.9))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("User ID")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(white: 0.7))
                                
                                Text(user.id)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(white: 0.6))
                            }
                        }
                    }
                    .padding()
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Change Password")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            AppTextField(
                                label: "Current Password",
                                placeholder: "Enter current password",
                                text: $oldPassword,
                                isSecure: true
                            )
                            
                            AppTextField(
                                label: "New Password",
                                placeholder: "Enter new password",
                                text: $newPassword,
                                isSecure: true
                            )
                            
                            AppTextField(
                                label: "Confirm New Password",
                                placeholder: "Confirm new password",
                                text: $confirmPassword,
                                isSecure: true
                            )
                            
                            if let passwordError = passwordError {
                                Text(passwordError)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            
                            if let passwordSuccess = passwordSuccess {
                                Text(passwordSuccess)
                                    .font(.system(size: 14))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            
                            AppButton("Change Password") {
                                Task {
                                    await changePassword()
                                }
                            }
                            .disabled(isChangingPassword || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                        }
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .task {
            await loadCurrentUser()
        }
    }
    
    private func loadCurrentUser() async {
        guard let userId = authStore.userId else { return }
        
        isLoading = true
        error = nil
        
        do {
            let users = try await userService.fetchUsers()
            await MainActor.run {
                self.currentUser = users.first { $0.id == userId }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func changePassword() async {
        guard !oldPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            return
        }
        
        guard newPassword == confirmPassword else {
            await MainActor.run {
                passwordError = "New passwords do not match"
                passwordSuccess = nil
            }
            return
        }
        
        guard let userId = authStore.userId else {
            await MainActor.run {
                passwordError = "User ID not found"
                passwordSuccess = nil
            }
            return
        }
        
        isChangingPassword = true
        passwordError = nil
        passwordSuccess = nil
        
        do {
            _ = try await userService.updateUser(id: userId, name: nil, password: newPassword)
            await MainActor.run {
                passwordSuccess = "Password changed successfully"
                passwordError = nil
                oldPassword = ""
                newPassword = ""
                confirmPassword = ""
                isChangingPassword = false
            }
        } catch {
            await MainActor.run {
                if let serviceError = error as? ServiceError {
                    switch serviceError {
                    case .invalidResponse:
                        passwordError = "Invalid response"
                    case .serverError(let message):
                        passwordError = message
                    }
                } else {
                    passwordError = error.localizedDescription
                }
                passwordSuccess = nil
                isChangingPassword = false
            }
        }
    }
}

