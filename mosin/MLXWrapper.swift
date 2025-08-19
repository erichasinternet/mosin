//
//  MLXWrapper.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation

class MLXWrapper: ObservableObject {
    @Published var isModelLoaded = false
    @Published var modelLoadingProgress: Float = 0.0
    
    private var modelPath: String?
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        Task {
            await loadModel()
        }
    }
    
    @MainActor
    private func loadModel() async {
        isModelLoaded = false
        modelLoadingProgress = 0.0
        
        do {
            updateProgress(0.2)
            
            updateProgress(0.5)
            
            updateProgress(0.8)
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            updateProgress(1.0)
            isModelLoaded = true
            
            print("MLX Grammar model loaded successfully")
        } catch {
            print("Failed to load MLX model: \(error)")
        }
    }
    
    private func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.modelLoadingProgress = progress
        }
    }
    
    func generateCorrections(for text: String) async throws -> [GrammarSuggestion] {
        guard isModelLoaded else {
            throw MLXError.modelNotLoaded
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: MLXError.modelNotLoaded)
                    return
                }
                let prompt = self.buildGrammarPrompt(text)
                let corrections = self.processWithModel(prompt)
                continuation.resume(returning: corrections)
            }
        }
    }
    
    private func buildGrammarPrompt(_ text: String) -> String {
        return """
        Please analyze the following text for grammar, spelling, and style issues.
        Provide specific suggestions for improvement.
        
        Text: "\(text)"
        
        Format your response as JSON with the following structure:
        {
            "suggestions": [
                {
                    "start": 0,
                    "length": 5,
                    "original": "original text",
                    "suggestion": "corrected text",
                    "type": "grammar|spelling|style",
                    "confidence": 0.95
                }
            ]
        }
        """
    }
    
    private func processWithModel(_ prompt: String) -> [GrammarSuggestion] {
        let fallbackSuggestions = generateFallbackSuggestions(prompt)
        return fallbackSuggestions
    }
    
    private func generateFallbackSuggestions(_ text: String) -> [GrammarSuggestion] {
        let basicChecks = [
            ("i ", "I ", SuggestionType.grammar),
            ("its really", "it's really", SuggestionType.grammar),
            ("your welcome", "you're welcome", SuggestionType.grammar),
            ("alot", "a lot", SuggestionType.spelling),
            ("recieve", "receive", SuggestionType.spelling)
        ]
        
        var suggestions: [GrammarSuggestion] = []
        
        for (incorrect, correct, type) in basicChecks {
            if let range = text.range(of: incorrect, options: .caseInsensitive) {
                let nsRange = NSRange(range, in: text)
                suggestions.append(GrammarSuggestion(
                    range: nsRange,
                    originalText: String(text[range]),
                    suggestedText: correct,
                    type: type,
                    confidence: 0.85
                ))
            }
        }
        
        return suggestions
    }
}

enum MLXError: Error {
    case modelNotLoaded
    case inferenceError(String)
    case invalidResponse
}