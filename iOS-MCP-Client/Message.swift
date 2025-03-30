import Foundation

enum MessageSender {
    case user
    case assistant
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let sender: MessageSender
    let timestamp: Date
    
    init(content: String, sender: MessageSender, timestamp: Date = Date()) {
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
    }
} 