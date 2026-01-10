import SwiftUI

struct AppModal<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String?
    let content: Content
    
    init(isPresented: Binding<Bool>, title: String? = nil, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                VStack(spacing: 0) {
                    if let title = title {
                        HStack {
                            Text(title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(white: 0.9))
                            
                            Spacer()
                            
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color.clear)
                    }
                    
                    content
                        .padding()
                }
                .frame(maxWidth: 600)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding()
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .transition(.opacity)
        }
    }
}

