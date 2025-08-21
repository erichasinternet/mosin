//
//  MLXModelManager.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import Network
import AppKit

enum ModelType: String, CaseIterable {
    case grammar = "grammar"
    case style = "style"  
    case clarity = "clarity"
    
    var displayName: String {
        switch self {
        case .grammar: return "Grammar Correction"
        case .style: return "Style Enhancement"
        case .clarity: return "Clarity Improvement"
        }
    }
    
    var priority: Int {
        switch self {
        case .grammar: return 1
        case .style: return 2
        case .clarity: return 3
        }
    }
}

struct MLXModel {
    let type: ModelType
    let name: String
    let version: String
    let size: Int64 // bytes
    let downloadURL: URL
    let localPath: URL
    let quantization: String // "int4", "int8", "float16"
    let description: String
    
    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localPath.path)
    }
    
    var sizeString: String {
        ByteCountFormatter().string(fromByteCount: size)
    }
}

class MLXModelManager: ObservableObject {
    @Published var availableModels: [MLXModel] = []
    @Published var loadedModels: [ModelType: Any] = [:]
    @Published var downloadProgress: [String: Float] = [:]
    @Published var isModelLoaded: [ModelType: Bool] = [:]
    
    private let modelsDirectory: URL
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = false
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        modelsDirectory = documentsPath.appendingPathComponent("MosinModels")
        
        createModelsDirectory()
        setupNetworkMonitoring()
        loadModelCatalog()
    }
    
    private func createModelsDirectory() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func loadModelCatalog() {
        // In production, this would fetch from a remote catalog
        // For now, define the available models
        availableModels = [
            MLXModel(
                type: .grammar,
                name: "mosin-grammar-t5-small",
                version: "1.0.0",
                size: 242_000_000, // ~242MB
                downloadURL: URL(string: "https://example.com/models/grammar-t5-small-q4.mlx")!,
                localPath: modelsDirectory.appendingPathComponent("grammar-t5-small-q4.mlx"),
                quantization: "int4",
                description: "Fast grammar correction model based on T5-small, quantized to int4 for optimal performance on Apple Silicon."
            ),
            MLXModel(
                type: .style,
                name: "mosin-style-flan-t5-base",
                version: "1.0.0", 
                size: 990_000_000, // ~990MB
                downloadURL: URL(string: "https://example.com/models/style-flan-t5-base-q8.mlx")!,
                localPath: modelsDirectory.appendingPathComponent("style-flan-t5-base-q8.mlx"),
                quantization: "int8",
                description: "Advanced style improvement model based on FLAN-T5-base, optimized for natural language enhancement."
            ),
            MLXModel(
                type: .clarity,
                name: "mosin-clarity-distilbert",
                version: "1.0.0",
                size: 268_000_000, // ~268MB
                downloadURL: URL(string: "https://example.com/models/clarity-distilbert-q4.mlx")!,
                localPath: modelsDirectory.appendingPathComponent("clarity-distilbert-q4.mlx"),
                quantization: "int4",
                description: "Lightweight clarity enhancement model for improving readability and simplifying complex sentences."
            )
        ]
        
        // Initialize loading states
        for model in availableModels {
            isModelLoaded[model.type] = false
        }
        
        // Auto-load grammar model for immediate functionality
        loadGrammarModel()
    }
    
    func downloadModel(_ model: MLXModel) async throws {
        guard isNetworkAvailable else {
            throw ModelError.networkUnavailable
        }
        
        guard !model.isDownloaded else {
            print("Model \(model.name) already downloaded")
            return
        }
        
        DispatchQueue.main.async {
            self.downloadProgress[model.name] = 0.0
        }
        
        let session = URLSession.shared
        let (tempURL, response) = try await session.download(from: model.downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelError.downloadFailed
        }
        
        try FileManager.default.moveItem(at: tempURL, to: model.localPath)
        
        DispatchQueue.main.async {
            self.downloadProgress[model.name] = 1.0
        }
        
        print("✅ Downloaded model: \(model.name)")
        
        // Auto-load after download
        try await loadModel(model.type)
    }
    
    func loadModel(_ type: ModelType) async throws {
        guard let model = availableModels.first(where: { $0.type == type }) else {
            throw ModelError.modelNotFound
        }
        
        guard model.isDownloaded else {
            throw ModelError.modelNotDownloaded
        }
        
        // Basic model loading (no actual MLX yet)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        DispatchQueue.main.async {
            // Store a placeholder for the loaded model
            self.loadedModels[type] = "Loaded-\(model.name)"
            self.isModelLoaded[type] = true
        }
        
        print("✅ Loaded model: \(model.name)")
    }
    
    func unloadModel(_ type: ModelType) {
        loadedModels.removeValue(forKey: type)
        isModelLoaded[type] = false
        print("♻️ Unloaded model: \(type.rawValue)")
    }
    
    func generateCorrections(for text: String, using type: ModelType) async throws -> [GrammarSuggestion] {
        guard isModelLoaded[type] == true else {
            throw ModelError.modelNotLoaded
        }
        
        // In production, this would use actual MLX inference
        return try await simulateMLXInference(text: text, type: type)
    }
    
    private func simulateMLXInference(text: String, type: ModelType) async throws -> [GrammarSuggestion] {
        // Fast processing for basic grammar checking
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        var suggestions: [GrammarSuggestion] = []
        
        switch type {
        case .grammar:
            suggestions = generateGrammarSuggestions(text)
        case .style:
            suggestions = generateStyleSuggestions(text)
        case .clarity:
            suggestions = generateClaritySuggestions(text)
        }
        
        return suggestions
    }
    
    private func generateGrammarSuggestions(_ text: String) -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        
        // Add spell checking using NSSpellChecker
        suggestions.append(contentsOf: performSpellCheck(text))
        
        // Add basic grammar patterns
        let grammarPatterns = [
            ("\\bi\\s", "I ", SuggestionType.grammar, Float(0.95)),
            ("\\byour\\s+welcome\\b", "you're welcome", SuggestionType.grammar, Float(0.90)),
            ("\\bits\\s+its\\b", "its", SuggestionType.grammar, Float(0.85)),
            ("\\bthere\\s+is\\s+\\d+\\s+\\w+s\\b", "there are", SuggestionType.grammar, Float(0.80)),
            ("\\bcant\\b", "can't", SuggestionType.grammar, Float(0.90)),
            ("\\bwont\\b", "won't", SuggestionType.grammar, Float(0.90)),
            ("\\bdont\\b", "don't", SuggestionType.grammar, Float(0.90)),
            ("\\bisnt\\b", "isn't", SuggestionType.grammar, Float(0.90))
        ]
        
        for (pattern, replacement, type, confidence) in grammarPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let originalText = (text as NSString).substring(with: match.range)
                    suggestions.append(GrammarSuggestion(
                        range: match.range,
                        originalText: originalText,
                        suggestedText: replacement,
                        type: type,
                        confidence: confidence
                    ))
                }
            } catch {
                continue
            }
        }
        
        return suggestions
    }
    
    private func performSpellCheck(_ text: String) -> [GrammarSuggestion] {
        let checker = NSSpellChecker.shared
        var suggestions: [GrammarSuggestion] = []
        
        let range = NSRange(location: 0, length: text.count)
        var searchRange = range
        
        while searchRange.length > 0 {
            let misspelledRange = checker.checkSpelling(of: text, startingAt: searchRange.location)
            
            guard misspelledRange.location != NSNotFound else { break }
            
            let misspelledWord = (text as NSString).substring(with: misspelledRange)
            let corrections = checker.completions(forPartialWordRange: misspelledRange, in: text, language: "en", inSpellDocumentWithTag: 0) ?? []
            
            if let bestCorrection = corrections.first, bestCorrection != misspelledWord {
                suggestions.append(GrammarSuggestion(
                    range: misspelledRange,
                    originalText: misspelledWord,
                    suggestedText: bestCorrection,
                    type: .spelling,
                    confidence: 0.85
                ))
            }
            
            searchRange = NSRange(
                location: misspelledRange.location + misspelledRange.length,
                length: range.length - (misspelledRange.location + misspelledRange.length)
            )
        }
        
        return suggestions
    }
    
    private func generateStyleSuggestions(_ text: String) -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        
        let patterns = [
            ("\\bvery\\s+good\\b", "excellent", SuggestionType.style, Float(0.75)),
            ("\\bkind\\s+of\\b", "somewhat", SuggestionType.style, Float(0.70)),
            ("\\bin\\s+order\\s+to\\b", "to", SuggestionType.style, Float(0.80))
        ]
        
        for (pattern, replacement, type, confidence) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let originalText = (text as NSString).substring(with: match.range)
                    suggestions.append(GrammarSuggestion(
                        range: match.range,
                        originalText: originalText,
                        suggestedText: replacement,
                        type: type,
                        confidence: confidence
                    ))
                }
            } catch {
                continue
            }
        }
        
        return suggestions
    }
    
    private func generateClaritySuggestions(_ text: String) -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        
        let patterns = [
            ("\\butilize\\b", "use", SuggestionType.clarity, Float(0.85)),
            ("\\bfacilitate\\b", "help", SuggestionType.clarity, Float(0.80)),
            ("\\bat\\s+this\\s+point\\s+in\\s+time\\b", "now", SuggestionType.clarity, Float(0.90))
        ]
        
        for (pattern, replacement, type, confidence) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let originalText = (text as NSString).substring(with: match.range)
                    suggestions.append(GrammarSuggestion(
                        range: match.range,
                        originalText: originalText,
                        suggestedText: replacement,
                        type: type,
                        confidence: confidence
                    ))
                }
            } catch {
                continue
            }
        }
        
        return suggestions
    }
    
    func getModelStatus() -> [ModelType: String] {
        var status: [ModelType: String] = [:]
        
        for model in availableModels {
            if isModelLoaded[model.type] == true {
                status[model.type] = "loaded"
            } else if model.isDownloaded {
                status[model.type] = "downloaded"
            } else {
                status[model.type] = "not_downloaded"
            }
        }
        
        return status
    }
    
    func getRecommendedModel() -> MLXModel? {
        // Return the grammar model as primary recommendation
        return availableModels.first { $0.type == .grammar }
    }
    
    func deleteModel(_ type: ModelType) throws {
        guard let model = availableModels.first(where: { $0.type == type }) else {
            throw ModelError.modelNotFound
        }
        
        if isModelLoaded[type] == true {
            unloadModel(type)
        }
        
        if model.isDownloaded {
            try FileManager.default.removeItem(at: model.localPath)
        }
        
        downloadProgress.removeValue(forKey: model.name)
        print("🗑️ Deleted model: \(model.name)")
    }
}

enum ModelError: Error, LocalizedError {
    case modelNotFound
    case modelNotDownloaded
    case modelNotLoaded
    case downloadFailed
    case networkUnavailable
    case loadingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Model not found in catalog"
        case .modelNotDownloaded:
            return "Model not downloaded. Please download first."
        case .modelNotLoaded:
            return "Model not loaded. Please load model first."
        case .downloadFailed:
            return "Failed to download model"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .loadingFailed:
            return "Failed to load model"
        }
    }
}

private extension MLXModelManager {
    func loadGrammarModel() {
        Task {
            await MainActor.run {
                // Mark grammar model as "downloaded" and loaded for immediate use
                isModelLoaded[.grammar] = true
                loadedModels[.grammar] = "Basic-Grammar-Checker"
                print("✅ Basic grammar checker enabled")
            }
        }
    }
    
    func loadAvailableModels() {
        Task {
            for model in availableModels where model.isDownloaded {
                do {
                    try await loadModel(model.type)
                } catch {
                    print("Failed to auto-load model \(model.name): \(error)")
                }
            }
        }
    }
}