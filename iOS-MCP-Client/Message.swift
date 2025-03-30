import Foundation

enum MessageSender {
    case user
    case assistant
    case tool
}

enum MessageType {
    case regular
    case functionCallResult
    case toolResponse(toolCallId: String)
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let sender: MessageSender
    let timestamp: Date
    let isFunctionCallResult: Bool
    let messageType: MessageType
    let toolCallId: String?
    
    // For assistant messages with tool calls
    let hasToolCalls: Bool
    let toolCalls: [[String: Any]]?
    
    init(content: String, 
         sender: MessageSender, 
         timestamp: Date = Date(), 
         isFunctionCallResult: Bool = false,
         messageType: MessageType = .regular,
         toolCallId: String? = nil,
         hasToolCalls: Bool = false,
         toolCalls: [[String: Any]]? = nil) {
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.isFunctionCallResult = isFunctionCallResult
        self.messageType = messageType
        self.toolCallId = toolCallId
        self.hasToolCalls = hasToolCalls
        self.toolCalls = toolCalls
    }
} 