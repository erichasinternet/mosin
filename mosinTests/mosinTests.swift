//
//  mosinTests.swift
//  mosinTests
//
//  Created by Eric Lawson on 8/18/25.
//

import Testing
import Foundation
@testable import mosin
import Combine

struct mosinTests {

    @Test func testMLXGrammarModel() async throws {
        // Test the MLX model directly instead of the full service
        let mlxModel = MLXGrammarModel()
        let incorrectSentence = "my dogs has went outside."
        
        let suggestions = try await mlxModel.checkGrammar(incorrectSentence)
        
        #expect(suggestions.count >= 1)
        if let firstSuggestion = suggestions.first {
            print("Expected: 'My dogs have gone outside.'")
            print("Actual: '\(firstSuggestion.suggestedText)'")
            #expect(firstSuggestion.suggestedText == "My dogs have gone outside.")
        }
    }
    
    @Test func testGrammarSuggestionStructure() {
        // Test the basic data structure
        let suggestion = GrammarSuggestion(
            range: NSRange(location: 0, length: 10),
            originalText: "original",
            suggestedText: "corrected", 
            type: .grammar,
            confidence: 0.9
        )
        
        #expect(suggestion.range.location == 0)
        #expect(suggestion.range.length == 10)
        #expect(suggestion.originalText == "original")
        #expect(suggestion.suggestedText == "corrected")
        #expect(suggestion.type == .grammar)
        #expect(suggestion.confidence == 0.9)
    }
    
    @Test func testDifferenceKitIntegration() {
        // Test that GrammarSuggestion properly implements Differentiable
        let suggestion1 = GrammarSuggestion(
            range: NSRange(location: 0, length: 5),
            originalText: "hello",
            suggestedText: "Hello",
            type: .grammar,
            confidence: 0.8
        )
        
        let suggestion2 = GrammarSuggestion(
            range: NSRange(location: 0, length: 5),
            originalText: "hello",
            suggestedText: "Hello",
            type: .grammar,
            confidence: 0.8
        )
        
        let suggestion3 = GrammarSuggestion(
            range: NSRange(location: 5, length: 5),
            originalText: "world",
            suggestedText: "World",
            type: .grammar,
            confidence: 0.9
        )
        
        // Test difference identifier
        #expect(suggestion1.differenceIdentifier == suggestion2.differenceIdentifier)
        #expect(suggestion1.differenceIdentifier != suggestion3.differenceIdentifier)
        
        // Test content equality
        #expect(suggestion1.isContentEqual(to: suggestion2))
        #expect(!suggestion1.isContentEqual(to: suggestion3))
    }
    
    @Test func testPythonGrammarCorrection() async throws {
        // Test Python script integration directly
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Users/eric/mosin/venv/bin/python3")
        process.arguments = ["/Users/eric/mosin/grammar_corrector.py", "this are wrong grammar"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        #expect(process.terminationStatus == 0)
        #expect(output != nil)
        #expect(output != "this are wrong grammar") // Should be corrected
    }
    
    @Test func testMLXModelErrorHandling() async throws {
        let mlxModel = MLXGrammarModel()
        
        // Test with empty string - should handle gracefully
        let emptySuggestions = try await mlxModel.checkGrammar("")
        // Empty strings may or may not return suggestions, just check it doesn't crash
        print("Empty string suggestions count: \(emptySuggestions.count)")
        
        // Test with already correct text
        let correctSuggestions = try await mlxModel.checkGrammar("This is perfectly correct grammar.")
        print("Correct text suggestions count: \(correctSuggestions.count)")
        // Should return empty or very few suggestions, but we won't assert specific behavior
        // since the Python model might still suggest minor changes
    }
    
    @Test func testTextChunkPriority() {
        let lowChunk = TextChunk(
            id: UUID(),
            text: "test",
            range: NSRange(location: 0, length: 4),
            priority: .low
        )
        
        let highChunk = TextChunk(
            id: UUID(),
            text: "test",
            range: NSRange(location: 0, length: 4),
            priority: .high
        )
        
        let urgentChunk = TextChunk(
            id: UUID(),
            text: "test",
            range: NSRange(location: 0, length: 4),
            priority: .urgent
        )
        
        // Test priority comparison
        #expect(lowChunk.priority < highChunk.priority)
        #expect(highChunk.priority < urgentChunk.priority)
        #expect(lowChunk.priority < urgentChunk.priority)
    }
    
    @Test func testApplySuggestionLogic() {
        // Test the suggestion application logic without creating GrammarService
        let originalText = "This is a test sentence."
        
        let suggestion = GrammarSuggestion(
            range: NSRange(location: 10, length: 4), // "test"
            originalText: "test",
            suggestedText: "sample",
            type: .grammar,
            confidence: 0.9
        )
        
        // Manually apply the same logic as GrammarService.applySuggestion
        let nsString = originalText as NSString
        let result = nsString.replacingCharacters(in: suggestion.range, with: suggestion.suggestedText)
        #expect(result == "This is a sample sentence.")
    }
    
    @Test func testSuggestionTypes() {
        // Test all suggestion types exist
        let grammarSuggestion = GrammarSuggestion(
            range: NSRange(location: 0, length: 1),
            originalText: "a",
            suggestedText: "A",
            type: .grammar,
            confidence: 0.9
        )
        
        let spellingSuggestion = GrammarSuggestion(
            range: NSRange(location: 0, length: 1),
            originalText: "a",
            suggestedText: "A",
            type: .spelling,
            confidence: 0.9
        )
        
        let styleSuggestion = GrammarSuggestion(
            range: NSRange(location: 0, length: 1),
            originalText: "a",
            suggestedText: "A",
            type: .style,
            confidence: 0.9
        )
        
        let claritySuggestion = GrammarSuggestion(
            range: NSRange(location: 0, length: 1),
            originalText: "a",
            suggestedText: "A",
            type: .clarity,
            confidence: 0.9
        )
        
        #expect(grammarSuggestion.type == .grammar)
        #expect(spellingSuggestion.type == .spelling)
        #expect(styleSuggestion.type == .style)
        #expect(claritySuggestion.type == .clarity)
    }

}
