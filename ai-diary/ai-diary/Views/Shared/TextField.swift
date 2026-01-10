import SwiftUI

struct AppTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let error: String?
    
    init(
        label: String? = nil,
        placeholder: String = "",
        text: Binding<String>,
        isSecure: Bool = false,
        error: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.error = error
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.9))
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(Color(white: 0.9))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            
            if let error = error {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
}

