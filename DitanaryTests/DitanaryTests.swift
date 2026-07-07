//
//  DitanaryTests.swift
//  DitanaryTests
//
//  Created by Trần Lê Duy Tân on 24/4/26.
//

import Testing
@testable import Ditanary

struct DitanaryTests {

    @Test func normalizesLearningText() async throws {
        #expect(LearningTextNormalizer.normalizedWords("Hello, world!") == ["hello", "world"])
        #expect(LearningTextNormalizer.normalizedAnswer("  The quick, brown fox. ") == "the quick brown fox")
    }

    @Test func pronunciationScoringRewardsExactMatch() async throws {
        let score = PronunciationScorer.score(
            target: "Most plants require water.",
            input: "Most plants require water",
            averageConfidence: 1
        )

        #expect(score.finalScore == 100)
        #expect(score.sequenceScore == 100)
        #expect(score.confidenceScore == 100)
    }

    @Test func pronunciationScoringHandlesMissingWords() async throws {
        let score = PronunciationScorer.score(
            target: "Most plants require water",
            input: "Most plants water",
            averageConfidence: 0.8
        )

        #expect(score.sequenceScore == 75)
        #expect(score.finalScore == 60)
    }

}
