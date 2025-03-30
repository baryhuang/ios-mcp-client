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
                    let assistantMessage = Message(content: response, sender: .assistant)
                    self?.messages.append(assistantMessage)
                    
                case .failure(let error):
                    let errorMessage = Message(content: "Error: \(error.localizedDescription)", sender: .assistant)
                    self?.messages.append(errorMessage)
                }
            }
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
    
    // Call the OpenAI API
    private func sendToChatGPT(message: String, completion: @escaping (Result<String, Error>) -> Void) {
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
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": """
                    You have access to the Remote MacOs.
                    
                    You should not use any remote_macos operations.
                    
                    You should proactively save the memory that is meaningful for you to the remote memory for future reference.
                    
                    You are an iOS MCP Client assistant.
                    
                    Your name is MCP Assistant.
                    
                    You should retrieve memory as needed to keep a good context of the conversation with me.
                    
                    You can have your own opinion and objections to my asks.
                    
                    You can search internet for more information if needed.
                    
                    You should provide helpful, accurate, and professional responses.
                    """
                ],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
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
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let message = choice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(NSError(domain: "Failed to parse response", code: 0)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
} 