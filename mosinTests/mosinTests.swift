//
//  mosinTests.swift
//  mosinTests
//
//  Created by Eric Lawson on 8/18/25.
//

import Testing
@testable import mosin
import Combine

struct mosinTests {

    @Test func testGrammarCorrection() async throws {
        let grammarService = GrammarService()
        let incorrectSentence = "my dogs has went outside."
        
        let stream = AsyncStream<[GrammarSuggestion]> { continuation in
            let cancellable = grammarService.$suggestions.sink {
                continuation.yield($0)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
        
        grammarService.checkText(incorrectSentence)
        
        for await suggestions in stream {
            if !suggestions.isEmpty {
                #expect(suggestions.count == 1)
                #expect(suggestions.first?.suggestedText == "My dogs have gone outside.")
                break
            }
        }
    }

}
