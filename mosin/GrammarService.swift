//
//  GrammarService.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import AppKit

struct GrammarSuggestion {
    let range: NSRange
    let originalText: String
    let suggestedText: String
    let type: SuggestionType
    let confidence: Float
}

enum SuggestionType {
    case spelling
    case grammar
    case style
    case clarity
}

class GrammarService: ObservableObject {
    @Published var suggestions: [GrammarSuggestion] = []
    @Published var isProcessing = false
    
    private let mlxModel: MLXGrammarModel
    private let debounceTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
    
    init() {
        self.mlxModel = MLXGrammarModel()
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
        guard let text = notification.userInfo?["text"] as? String else { return }
        
        debounceTimer.setEventHandler { [weak self] in
            self?.checkText(text)
        }
        
        debounceTimer.schedule(deadline: .now() + 0.5)
        debounceTimer.resume()
    }
    
    private func checkText(_ text: String) {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        Task {
            do {
                let suggestions = try await mlxModel.checkGrammar(text)
                
                DispatchQueue.main.async {
                    self.suggestions = suggestions
                    self.isProcessing = false
                }
            } catch {
                print("Grammar check failed: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    func applySuggestion(_ suggestion: GrammarSuggestion, to text: String) -> String {
        let nsString = text as NSString
        return nsString.replacingCharacters(in: suggestion.range, with: suggestion.suggestedText)
    }
}

class MLXGrammarModel {
    
    func checkGrammar(_ text: String) async throws -> [GrammarSuggestion] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let suggestions = self.performGrammarCheck(text)
                continuation.resume(returning: suggestions)
            }
        }
    }
    
    private func performGrammarCheck(_ text: String) -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        
        suggestions.append(contentsOf: checkSpelling(text))
        suggestions.append(contentsOf: checkBasicGrammar(text))
        
        return suggestions
    }
    
    private func checkSpelling(_ text: String) -> [GrammarSuggestion] {
        let checker = NSSpellChecker.shared
        var suggestions: [GrammarSuggestion] = []
        
        let range = NSRange(location: 0, length: text.count)
        var searchRange = range
        
        while searchRange.length > 0 {
            let misspelledRange = checker.checkSpelling(of: text, startingAt: searchRange.location)
            
            guard misspelledRange.location != NSNotFound else { break }
            
            let misspelledWord = (text as NSString).substring(with: misspelledRange)
            let corrections = checker.completions(forPartialWordRange: misspelledRange, in: text, language: "en", inSpellDocumentWithTag: 0) ?? []
            
            if let bestCorrection = corrections.first {
                suggestions.append(GrammarSuggestion(
                    range: misspelledRange,
                    originalText: misspelledWord,
                    suggestedText: bestCorrection,
                    type: .spelling,
                    confidence: 0.8
                ))
            }
            
            searchRange = NSRange(
                location: misspelledRange.location + misspelledRange.length,
                length: range.length - (misspelledRange.location + misspelledRange.length)
            )
        }
        
        return suggestions
    }
    
    private func checkBasicGrammar(_ text: String) -> [GrammarSuggestion] {
        var suggestions: [GrammarSuggestion] = []
        
        let patterns = [
            ("\\bi\\b", "I", SuggestionType.grammar),
            ("\\bits\\s+its\\b", "its", SuggestionType.grammar),
            ("\\byour\\s+welcome\\b", "you're welcome", SuggestionType.grammar),
            ("\\bthere\\s+is\\s+\\d+\\s+\\w+s\\b", "there are", SuggestionType.grammar)
        ]
        
        for (pattern, replacement, type) in patterns {
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
                        confidence: 0.7
                    ))
                }
            } catch {
                print("Regex error: \(error)")
            }
        }
        
        return suggestions
    }
}