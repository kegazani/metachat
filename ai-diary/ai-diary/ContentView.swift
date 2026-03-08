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
                        print("[ContentView] MainView appeared, token: \(authStore.token?.prefix(20) ?? "nil")...")
                        print("[ContentView] Initializing SyncManagerService...")
                        SyncManagerService.shared.initialize(authStore: authStore)
                    }
                    .onChange(of: authStore.token) { newToken in
                        print("[ContentView] Token changed: \(newToken != nil)")
                        if authStore.isAuthenticated {
                            print("[ContentView] Re-initializing sync after token change")
                            SyncManagerService.shared.initialize(authStore: authStore)
                        } else {
                            print("[ContentView] Stopping sync - user logged out")
                            SyncManagerService.shared.stop()
                        }
                    }
            } else {
                LoginView(authService: AuthService(apollo: ApolloClientService.shared.apollo, authStore: authStore))
                    .environmentObject(authStore)
                    .onAppear {
                        print("[ContentView] LoginView appeared, isAuthenticated: \(authStore.isAuthenticated)")
                        SyncManagerService.shared.stop()
                    }
            }
        }
        .onAppear {
            print("[ContentView] Initial state - isAuthenticated: \(authStore.isAuthenticated), userId: \(authStore.userId ?? "nil")")
        }
    }
}
