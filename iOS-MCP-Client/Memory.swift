import Foundation

struct MemoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let content: String
    
    init(content: String, timestamp: Date = Date(), id: UUID = UUID()) {
        self.content = content
        self.timestamp = timestamp
        self.id = id
    }
}

class MemoryManager {
    private let fileManager = FileManager.default
    private let memoryDirectoryName = "Memories"
    
    // Get the URL for the documents directory
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Get the URL for the memories directory
    private var memoriesDirectory: URL {
        let directory = documentsDirectory.appendingPathComponent(memoryDirectoryName)
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Error creating memories directory: \(error)")
            }
        }
        
        return directory
    }
    
    // Get URL for the memory file
    private var memoryFileURL: URL {
        memoriesDirectory.appendingPathComponent("memory_data.json")
    }
    
    // Save a memory entry
    func saveMemory(content: String) -> Bool {
        print("MemoryManager: Saving new memory entry")
        let newEntry = MemoryEntry(content: content)
        
        var entries = getAllMemories()
        print("MemoryManager: Current entries count: \(entries.count)")
        entries.append(newEntry)
        
        let success = saveAllMemories(entries)
        print("MemoryManager: Save operation result: \(success ? "successful" : "failed")")
        return success
    }
    
    // Get all memory entries
    func getAllMemories() -> [MemoryEntry] {
        print("MemoryManager: Reading all memory entries")
        guard fileManager.fileExists(atPath: memoryFileURL.path) else {
            print("MemoryManager: Memory file does not exist yet")
            return []
        }
        
        do {
            let data = try Data(contentsOf: memoryFileURL)
            let decoder = JSONDecoder()
            let memories = try decoder.decode([MemoryEntry].self, from: data)
            print("MemoryManager: Successfully read \(memories.count) memory entries")
            return memories
        } catch {
            print("MemoryManager: Error reading memories: \(error)")
            return []
        }
    }
    
    // Save all memory entries
    private func saveAllMemories(_ entries: [MemoryEntry]) -> Bool {
        print("MemoryManager: Saving \(entries.count) memory entries")
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            try data.write(to: memoryFileURL)
            print("MemoryManager: Successfully wrote to \(memoryFileURL.path)")
            return true
        } catch {
            print("MemoryManager: Error saving memories: \(error)")
            return false
        }
    }
    
    // Format timestamp for display
    func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
} 