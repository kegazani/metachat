import SwiftUI

struct MainView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var selectedTab: NavigationBar.Tab = .chats
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TabView(selection: $selectedTab) {
                        ChatsListView(navigationPath: $navigationPath)
                            .tag(NavigationBar.Tab.chats)
                        
                        ProfileView()
                            .tag(NavigationBar.Tab.profile)
                        
                        HealthView()
                            .tag(NavigationBar.Tab.health)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    NavigationBar(selectedTab: $selectedTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { chatId in
                if chatId == "diary" {
                    DiaryView()
                } else {
                    ChatView(chatId: chatId)
                }
            }
        }
    }
}

