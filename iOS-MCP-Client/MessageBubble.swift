import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 5) {
                Text(message.content)
                    .padding(10)
                    .background(message.sender == .user ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(message.sender == .user ? .white : .black)
                    .cornerRadius(16)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(message.sender == .user ? .leading : .trailing, 30)
            
            if message.sender == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
} 