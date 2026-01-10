import SwiftUI

struct NavigationBar: View {
    @EnvironmentObject var authStore: AuthStore
    @Binding var selectedTab: Tab
    
    enum Tab {
        case chats
        case profile
        case health
    }
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                icon: "message.fill",
                isSelected: selectedTab == .chats,
                action: { selectedTab = .chats }
            )
            
            Spacer()
            
            TabButton(
                icon: "person.fill",
                isSelected: selectedTab == .profile,
                action: { selectedTab = .profile }
            )
            
            Spacer()
            
            TabButton(
                icon: "heart.fill",
                isSelected: selectedTab == .health,
                action: { selectedTab = .health }
            )
            
            Spacer()
            
            TabButton(
                icon: "rectangle.portrait.and.arrow.right",
                isSelected: false,
                action: { authStore.logout() }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .safeAreaPadding(.bottom)
    }
}

struct TabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
