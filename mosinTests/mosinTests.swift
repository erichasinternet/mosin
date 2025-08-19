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

}
