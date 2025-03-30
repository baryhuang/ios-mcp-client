import Foundation

enum Config {
    // Get API key from environment or from .env file
    static var openAIAPIKey: String {
        // First check Xcode environment variables
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty {
            return apiKey
        }
        
        // Fallback to .env file if exists
        return loadFromDotEnv(key: "OPENAI_API_KEY") ?? ""
    }
    
    // Helper method to load from .env file
    private static func loadFromDotEnv(key: String) -> String? {
        guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("No .env file found in bundle")
            return nil
        }
        
        do {
            let envContents = try String(contentsOfFile: envPath, encoding: .utf8)
            let lines = envContents.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip comments and empty lines
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Parse KEY=VALUE format
                let parts = trimmedLine.components(separatedBy: "=")
                if parts.count >= 2, parts[0] == key {
                    // Join all parts after first '=' in case value contains '='
                    let value = parts[1...].joined(separator: "=")
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return nil
    }
} 