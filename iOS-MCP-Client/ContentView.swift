//
//  ContentView.swift
//  iOS-MCP-Client
//
//  Created by Bury Huang on 3/29/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            // App header
            HStack {
                Text("iOS MCP Client")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .padding()
            
            // Message list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            
            // Input area
            VStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.vertical, 10)
                }
                
                HStack {
                    // Text input field
                    TextField("Type a message...", text: $viewModel.inputMessage)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .onSubmit {
                            viewModel.sendMessage()
                        }
                    
                    // Send button
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
                    
                    // Voice input button
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 30))
                            .foregroundColor(viewModel.isRecording ? .red : .blue)
                    }
                    .disabled(viewModel.isProcessing)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .shadow(radius: 5)
        }
    }
}

#Preview {
    ContentView()
}
