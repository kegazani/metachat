import SwiftUI

struct AppButton: View {
    enum Variant {
        case primary
        case secondary
    }
    
    let title: String
    let variant: Variant
    let action: () -> Void
    
    init(_ title: String, variant: Variant = .primary, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(
                    variant == .primary
                        ? Color(white: 0.2)
                        : Color(white: 0.15).opacity(0.5)
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

