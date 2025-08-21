//
//  GrammarService.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import Foundation
import AppKit
import DifferenceKit

struct GrammarSuggestion: Differentiable {
    var differenceIdentifier: String {
        return "\(range.location)-\(originalText)"
    }

    func isContentEqual(to source: GrammarSuggestion) -> Bool {
        return range == source.range && originalText == source.originalText && suggestedText == source.suggestedText
    }

    let range: NSRange
    let originalText: String
    let suggestedText: String
    let type: SuggestionType
    let confidence: Float
}

struct StringWrapper: Differentiable {
    let value: String

    var differenceIdentifier: String {
        return value
    }

    func isContentEqual(to source: StringWrapper) -> Bool {
        return value == source.value
    }
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
    
    func checkText(_ text: String) {
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
        
        suggestions.append(contentsOf: checkGrammarWithPython(text))
        
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
    
    private func checkGrammarWithPython(_ text: String) -> [GrammarSuggestion] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/Users/eric/mosin/venv/bin/python3")
        task.arguments = ["/Users/eric/mosin/grammar_corrector.py", text]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let correctedText = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return diff(original: text, corrected: correctedText)
        } catch {
            print("Error running python script: \(error)")
            return []
        }
    }

    private func diff(original: String, corrected: String) -> [GrammarSuggestion] {
        print("Original: \(original)")
        print("Corrected: \(corrected)")

        if original.lowercased() == corrected.lowercased() {
            print("No changes found.")
            return []
        }

        let range = NSRange(location: 0, length: original.count)
        let suggestion = GrammarSuggestion(range: range, originalText: original, suggestedText: corrected, type: .grammar, confidence: 0.9)
        print("Suggestions: \(suggestion)")
        return [suggestion]
    }
}
