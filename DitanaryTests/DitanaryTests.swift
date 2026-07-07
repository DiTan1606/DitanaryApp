//
//  DitanaryTests.swift
//  DitanaryTests
//
//  Created by Trần Lê Duy Tân on 24/4/26.
//

import Foundation
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

    @Test func reviewSchedulerCapsAtMasterLevel() async throws {
        #expect(ReviewScheduler.nextLearningLevel(from: 0) == 1)
        #expect(ReviewScheduler.nextLearningLevel(from: 5) == 6)
        #expect(ReviewScheduler.nextLearningLevel(from: 6) == 6)
        #expect(ReviewScheduler.reviewDelayDays(for: 4) == 7)
        #expect(ReviewScheduler.reviewDelayDays(for: 5) == 15)
    }

    @Test func learningSessionBuilderCountsDueAndMasterWords() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let past = ISO8601DateFormatter().string(from: now.addingTimeInterval(-3600))
        let future = ISO8601DateFormatter().string(from: now.addingTimeInterval(3600))

        let due = Vocabulary(id: "due", vocab: "apple", V_meaning: "quả táo", learning_level: 2, next_review: past)
        let notDue = Vocabulary(id: "future", vocab: "banana", V_meaning: "quả chuối", learning_level: 2, next_review: future)
        let master = Vocabulary(id: "master", vocab: "orange", V_meaning: "quả cam", E_example: "I like orange juice", learning_level: 6, pronunciation_score: 20)

        let plan = LearningSessionBuilder.build(from: [due, notDue, master], now: now, maxWords: 7)

        #expect(plan.totalSavedWords == 3)
        #expect(plan.totalLearningWords == 3)
        #expect(plan.dueVocabsCount == 1)
        #expect(plan.masterDueVocabsCount == 1)
        #expect(plan.selectedGroups.count == 1)
        #expect(plan.masterTasks.count == 1)
        #expect(plan.tasks.contains { $0.type == .multipleChoice })
    }

}
