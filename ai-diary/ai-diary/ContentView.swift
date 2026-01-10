import SwiftUI

struct ContentView: View {
    @StateObject private var authStore = AuthStore()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if authStore.isAuthenticated {
                MainView()
                    .environmentObject(authStore)
                    .onAppear {
                        print("MainView appeared")
                        SyncManagerService.shared.initialize(authStore: authStore)
                    }
                    .onChange(of: authStore.token) { _ in
                        if authStore.isAuthenticated {
                            SyncManagerService.shared.initialize(authStore: authStore)
                        } else {
                            SyncManagerService.shared.stop()
                        }
                    }
            } else {
                LoginView(authService: AuthService(apollo: ApolloClientService.shared.apollo, authStore: authStore))
                    .environmentObject(authStore)
                    .onAppear {
                        print("LoginView appeared, isAuthenticated: \(authStore.isAuthenticated)")
                        SyncManagerService.shared.stop()
                    }
            }
        }
    }
}
