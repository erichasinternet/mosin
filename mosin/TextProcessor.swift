//
//  TextProcessor.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import CryptoKit

struct TextChunk {
    let id: UUID
    let text: String
    let range: NSRange
    let priority: ProcessingPriority
    
    enum ProcessingPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
        
        static func < (lhs: ProcessingPriority, rhs: ProcessingPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

struct ProcessingResult {
    let chunkId: UUID
    let suggestions: [GrammarSuggestion]
    let modelType: ModelType
    let processingTime: TimeInterval
    let cacheHit: Bool
}

class TextProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var processingQueue: [TextChunk] = []
    @Published var results: [UUID: [GrammarSuggestion]] = [:]
    
    private let modelManager: MLXModelManager
    private let cache = SuggestionCache()
    private let processingDispatchQueue = DispatchQueue(label: "com.mosin.processing", qos: .userInitiated)
    private let resultsQueue = DispatchQueue(label: "com.mosin.results", qos: .utility)
    
    private var debounceTimer: Timer?
    private var currentProcessingTasks: [UUID: Task<Void, Never>] = [:]
    
    // Configuration
    private let maxChunkSize = 1000 // characters
    private let debounceInterval: TimeInterval = 0.5
    private let maxConcurrentTasks = 3
    
    init(modelManager: MLXModelManager) {
        self.modelManager = modelManager
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextCaptured(_:)),
            name: .textCaptured,
            object: nil
        )
    }
    
    @objc private func handleTextCaptured(_ notification: Notification) {
        guard let text = notification.userInfo?["text"] as? String,
              let source = notification.userInfo?["source"] as? TextInputManager.TextSource else {
            print("⚠️ TextProcessor: Invalid notification data")
            return
        }
        
        print("📥 TextProcessor received text: \(text.prefix(50))... from \(source)")
        
        let priority: TextChunk.ProcessingPriority = switch source {
        case .hotkey: .urgent
        case .manual: .high
        case .clipboard: .normal
        case .none: .low
        }
        
        processText(text, priority: priority)
    }
    
    func processText(_ text: String, priority: TextChunk.ProcessingPriority = .normal) {
        // Cancel existing debounce timer
        debounceTimer?.invalidate()
        
        // Debounce processing for non-urgent requests
        if priority != .urgent {
            debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
                self?.performTextProcessing(text, priority: priority)
            }
        } else {
            performTextProcessing(text, priority: priority)
        }
    }
    
    private func performTextProcessing(_ text: String, priority: TextChunk.ProcessingPriority) {
        let chunks = chunkText(text, priority: priority)
        
        DispatchQueue.main.async {
            self.isProcessing = !chunks.isEmpty
            self.processingQueue.append(contentsOf: chunks)
        }
        
        // Process chunks concurrently
        for chunk in chunks {
            processChunk(chunk)
        }
    }
    
    private func chunkText(_ text: String, priority: TextChunk.ProcessingPriority) -> [TextChunk] {
        // For short text, process as single chunk
        if text.count <= maxChunkSize {
            return [TextChunk(
                id: UUID(),
                text: text,
                range: NSRange(location: 0, length: text.count),
                priority: priority
            )]
        }
        
        // Split longer text into semantic chunks
        var chunks: [TextChunk] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        var currentChunk = ""
        var currentStart = 0
        
        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSentence.isEmpty else { continue }
            
            let potentialChunk = currentChunk.isEmpty ? trimmedSentence : currentChunk + ". " + trimmedSentence
            
            if potentialChunk.count <= maxChunkSize {
                currentChunk = potentialChunk
            } else {
                // Commit current chunk
                if !currentChunk.isEmpty {
                    chunks.append(TextChunk(
                        id: UUID(),
                        text: currentChunk,
                        range: NSRange(location: currentStart, length: currentChunk.count),
                        priority: priority
                    ))
                    currentStart += currentChunk.count
                }
                
                // Start new chunk
                currentChunk = trimmedSentence
            }
        }
        
        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append(TextChunk(
                id: UUID(),
                text: currentChunk,
                range: NSRange(location: currentStart, length: currentChunk.count),
                priority: priority
            ))
        }
        
        return chunks
    }
    
    private func processChunk(_ chunk: TextChunk) {
        // Limit concurrent processing
        if currentProcessingTasks.count >= maxConcurrentTasks {
            // Queue chunk for later processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processChunk(chunk)
            }
            return
        }
        
        let task = Task {
            await processChunkAsync(chunk)
        }
        
        currentProcessingTasks[chunk.id] = task
    }
    
    @MainActor
    private func processChunkAsync(_ chunk: TextChunk) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check cache first
        if let cachedSuggestions = cache.getSuggestions(for: chunk.text) {
            let result = ProcessingResult(
                chunkId: chunk.id,
                suggestions: cachedSuggestions,
                modelType: .grammar, // Default for cached results
                processingTime: CFAbsoluteTimeGetCurrent() - startTime,
                cacheHit: true
            )
            
            await handleProcessingResult(result)
            return
        }
        
        // Process with available models in priority order
        let availableModels = ModelType.allCases.sorted { $0.priority < $1.priority }
        var allSuggestions: [GrammarSuggestion] = []
        
        for modelType in availableModels {
            if modelManager.isModelLoaded[modelType] == true {
                do {
                    let suggestions = try await modelManager.generateCorrections(
                        for: chunk.text,
                        using: modelType
                    )
                    
                    // Merge suggestions, avoiding duplicates
                    allSuggestions.append(contentsOf: suggestions.filter { newSuggestion in
                        !allSuggestions.contains { existingSuggestion in
                            existingSuggestion.range.intersection(newSuggestion.range) != nil
                        }
                    })
                    
                } catch {
                    print("Processing failed for \(modelType): \(error)")
                }
            }
        }
        
        // Sort suggestions by confidence and position
        allSuggestions.sort { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.range.location < rhs.range.location
        }
        
        // Cache results for future use
        cache.storeSuggestions(allSuggestions, for: chunk.text)
        
        let result = ProcessingResult(
            chunkId: chunk.id,
            suggestions: allSuggestions,
            modelType: .grammar, // Primary model type
            processingTime: CFAbsoluteTimeGetCurrent() - startTime,
            cacheHit: false
        )
        
        await handleProcessingResult(result)
    }
    
    @MainActor
    private func handleProcessingResult(_ result: ProcessingResult) async {
        // Store results
        results[result.chunkId] = result.suggestions
        
        // Remove from processing queue
        processingQueue.removeAll { $0.id == result.chunkId }
        currentProcessingTasks.removeValue(forKey: result.chunkId)
        
        // Update processing state
        isProcessing = !processingQueue.isEmpty
        
        // Notify UI about new suggestions
        print("🎯 Found \(result.suggestions.count) suggestions, posting notification")
        NotificationCenter.default.post(
            name: .mosinSuggestionsReady,
            object: nil,
            userInfo: [
                "chunkId": result.chunkId,
                "suggestions": result.suggestions,
                "processingTime": result.processingTime,
                "cacheHit": result.cacheHit
            ]
        )
        
        print("✅ Processed chunk in \(String(format: "%.2f", result.processingTime))s (cache: \(result.cacheHit ? "HIT" : "MISS")), found \(result.suggestions.count) suggestions")
    }
    
    func cancelProcessing() {
        debounceTimer?.invalidate()
        
        for task in currentProcessingTasks.values {
            task.cancel()
        }
        
        DispatchQueue.main.async {
            self.currentProcessingTasks.removeAll()
            self.processingQueue.removeAll()
            self.isProcessing = false
        }
    }
    
    func clearResults() {
        DispatchQueue.main.async {
            self.results.removeAll()
        }
    }
    
    func getAllSuggestions() -> [GrammarSuggestion] {
        return results.values.flatMap { $0 }
    }
}

// MARK: - Suggestion Cache

class SuggestionCache {
    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize = 1000
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    private struct CacheEntry {
        let suggestions: [GrammarSuggestion]
        let timestamp: Date
        let accessCount: Int
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 3600
        }
    }
    
    func getSuggestions(for text: String) -> [GrammarSuggestion]? {
        let key = generateCacheKey(for: text)
        
        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        
        // Update access count
        cache[key] = CacheEntry(
            suggestions: entry.suggestions,
            timestamp: entry.timestamp,
            accessCount: entry.accessCount + 1
        )
        
        return entry.suggestions
    }
    
    func storeSuggestions(_ suggestions: [GrammarSuggestion], for text: String) {
        let key = generateCacheKey(for: text)
        
        // Don't cache empty results
        guard !suggestions.isEmpty else { return }
        
        cache[key] = CacheEntry(
            suggestions: suggestions,
            timestamp: Date(),
            accessCount: 1
        )
        
        // Cleanup if cache is too large
        if cache.count > maxCacheSize {
            cleanupCache()
        }
    }
    
    private func generateCacheKey(for text: String) -> String {
        let normalized = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let data = normalized.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func cleanupCache() {
        // Remove expired entries first
        cache = cache.filter { !$0.value.isExpired }
        
        // If still too large, remove least accessed entries
        if cache.count > maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.accessCount < $1.value.accessCount }
            let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize + 100)
            
            for (key, _) in entriesToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}

extension Notification.Name {
    static let mosinSuggestionsReady = Notification.Name("mosinSuggestionsReady")
}