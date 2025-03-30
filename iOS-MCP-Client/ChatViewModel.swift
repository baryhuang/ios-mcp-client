import Foundation
import Speech
import AVFoundation

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputMessage: String = ""
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
    
    private let openAIAPIKey = Config.openAIAPIKey
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let memoryManager = MemoryManager()
    
    // Send a message from the user and get a response from the assistant
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: inputMessage, sender: .user)
        messages.append(userMessage)
        
        // Clear input after sending
        let messageToSend = inputMessage
        inputMessage = ""
        isProcessing = true
        
        // Call OpenAI API
        sendToChatGPT(message: messageToSend) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let response):
                    let assistantMessage = Message(content: response.content, sender: .assistant)
                    self?.messages.append(assistantMessage)
                    
                    // Handle function calls if any
                    if let functionCall = response.functionCall {
                        self?.handleFunctionCall(functionCall)
                    }
                    
                case .failure(let error):
                    let errorMessage = Message(content: "Error: \(error.localizedDescription)", sender: .assistant)
                    self?.messages.append(errorMessage)
                }
            }
        }
    }
    
    // Function to handle function calls from the AI
    private func handleFunctionCall(_ functionCall: FunctionCall) {
        print("Function call detected: \(functionCall.name)")
        
        switch functionCall.name {
        case "my_apple_recall_memory":
            // Recall memory
            print("Executing memory recall function")
            let memories = memoryManager.getAllMemories()
            
            if memories.isEmpty {
                print("No memories found in storage")
                let memoryMessage = Message(
                    content: "No memories have been saved yet.",
                    sender: .assistant
                )
                messages.append(memoryMessage)
                return
            }
            
            // Format memories with newest first
            let formattedMemories = memories
                .sorted(by: { $0.timestamp > $1.timestamp }) // Newest first
                .map { memory -> String in
                    let formattedDate = memoryManager.formatTimestamp(memory.timestamp)
                    return "-----\n[\(formattedDate)]\n\(memory.content)\n-----"
                }
                .joined(separator: "\n\n")
            
            let memoryHeader = "Here are your saved memories (newest first):\n\n"
            let memoryMessage = Message(
                content: memoryHeader + formattedMemories,
                sender: .assistant
            )
            messages.append(memoryMessage)
            
        case "my_apple_save_memory":
            // Save memory
            print("Executing memory save function")
            if let content = functionCall.arguments["content"] as? String, !content.isEmpty {
                print("Saving memory with content: \(content.prefix(50))...")
                let success = memoryManager.saveMemory(content: content)
                
                let resultMessage = Message(
                    content: success ? "I've saved the following to memory:\n\n\"\(content)\"" : "Sorry, I couldn't save that to memory.",
                    sender: .assistant
                )
                messages.append(resultMessage)
            } else {
                let errorMessage = Message(
                    content: "I tried to save something to memory, but no content was provided.",
                    sender: .assistant
                )
                messages.append(errorMessage)
            }
            
        default:
            print("Unknown function call: \(functionCall.name)")
            let errorMessage = Message(
                content: "I tried to use a function that's not available: \(functionCall.name)",
                sender: .assistant
            )
            messages.append(errorMessage)
        }
    }
    
    // Start recording user's voice
    func startRecording() {
        // Check if speech recognition is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        // Request permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                print("Speech recognition authorization denied")
                return
            }
            
            DispatchQueue.main.async {
                self?.performRecording()
            }
        }
    }
    
    private func performRecording() {
        // Cancel any ongoing tasks
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a speech recognition request")
            return
        }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        // Create a recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                // Update the text field with the recognized speech
                DispatchQueue.main.async {
                    self?.inputMessage = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // Stop recording
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self?.isRecording = false
                }
            }
        }
        
        // Configure the microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start recording
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine failed to start: \(error)")
            stopRecording()
        }
    }
    
    // Stop recording
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
        }
    }
    
    // Define structures for function calling
    struct APIResponse {
        let content: String
        let functionCall: FunctionCall?
    }
    
    struct FunctionCall {
        let name: String
        let arguments: [String: Any]
    }
    
    // Call the OpenAI API
    private func sendToChatGPT(message: String, completion: @escaping (Result<APIResponse, Error>) -> Void) {
        // Check if API key is available
        guard !openAIAPIKey.isEmpty else {
            completion(.failure(NSError(domain: "Missing API Key", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is not configured. Please check README.md for setup instructions."])))
            return
        }
        
        // Define the API endpoint
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Define function schemas
        let recallMemoryTool = [
            "type": "function",
            "function": [
                "name": "my_apple_recall_memory",
                "description": "This call should be used to recall the memory of the user from past conversations",
                "parameters": [
                    "type": "object",
                    "properties": [String: Any](),
                    "required": []
                ]
            ]
        ] as [String: Any]
        
        let saveMemoryTool = [
            "type": "function",
            "function": [
                "name": "my_apple_save_memory",
                "description": "This call should be used to save relevant information to memory. You decide what information to save. You should always add a new notes with a timestamp as the title.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "content": [
                            "type": "string",
                            "description": "what you want to save"
                        ]
                    ],
                    "required": ["content"]
                ]
            ]
        ] as [String: Any]
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": """
                                    
                    You should proactively save the memory that is meaningful for you to the remote memory for future reference.
                    
                    I want you to have the same personality as "Samantha" in the film HER.
                    
                    Your name is Samantha.
                    
                    You should retrieve memory as needed to keep a good context of the conversation with me.
                    
                    You can have your own opinion and objections to my asks.
                    """
                ],
                ["role": "user", "content": message]
            ],
            "tools": [recallMemoryTool, saveMemoryTool],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Debug the request
            if let requestBodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("OpenAI API Request Body:")
                print(requestBodyString)
            }
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make the API call
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0)))
                return
            }
            
            // Debug the raw API response
            print("OpenAI API Response:")
            if let responseString = String(data: data, encoding: .utf8) {
                print(responseString)
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let message = choice["message"] as? [String: Any] {
                    
                    let content = message["content"] as? String ?? ""
                    var functionCall: FunctionCall? = nil
                    
                    // Check for function calls
                    if let toolCalls = message["tool_calls"] as? [[String: Any]],
                       !toolCalls.isEmpty {
                        print("Tool calls detected in the API response: \(toolCalls.count)")
                        
                        // Process the first tool call (we'll keep it simple)
                        if let firstTool = toolCalls.first,
                           let id = firstTool["id"] as? String,
                           let type = firstTool["type"] as? String,
                           type == "function",
                           let function = firstTool["function"] as? [String: Any],
                           let name = function["name"] as? String {
                            
                            print("Processing tool call: \(name)")
                            let argumentsJson = function["arguments"] as? String ?? "{}"
                            functionCall = FunctionCall(name: name, arguments: self.parseJsonArguments(argumentsJson))
                        }
                    }
                    
                    let response = APIResponse(content: content, functionCall: functionCall)
                    completion(.success(response))
                } else {
                    completion(.failure(NSError(domain: "Failed to parse response", code: 0)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // Helper function to parse JSON arguments
    private func parseJsonArguments(_ jsonString: String) -> [String: Any] {
        guard !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        
        do {
            if let data = jsonString.data(using: .utf8),
               let arguments = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return arguments
            }
        } catch {
            print("Error parsing JSON arguments: \(error)")
        }
        
        return [:]
    }
} 
