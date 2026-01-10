import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Settings").tag(0)
                    Text("Statistics").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    ProfileSettingsView()
                } else {
                    StatisticsView()
                }
            }
        }
    }
}

