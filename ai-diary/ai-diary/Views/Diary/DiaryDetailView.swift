import SwiftUI

struct DiaryDetailView: View {
    let entry: ChatHistory
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(formatDate(entry.createdAt))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(white: 0.9))
                                
                                Text(entry.messageText)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(white: 0.9))
                                    .lineSpacing(4)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Детали записи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

