import Foundation

enum LearningTextNormalizer {
    static func normalizedWords(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    static func normalizedAnswer(_ text: String) -> String {
        normalizedWords(text).joined(separator: " ")
    }

    static func sentenceScrambleWords(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "[.,!?;:]", with: "", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}

enum PronunciationScorer {
    static func score(target: String, input: String, averageConfidence: Double) -> PronunciationScore {
        let targetWords = LearningTextNormalizer.normalizedWords(target)
        let inputWords = LearningTextNormalizer.normalizedWords(input)

        guard !targetWords.isEmpty, !inputWords.isEmpty else {
            return PronunciationScore(finalScore: 0, sequenceScore: 0, confidenceScore: 0)
        }

        let empty = [Int](repeating: 0, count: inputWords.count + 1)
        var last = [Int](0...inputWords.count)

        for (i, targetWord) in targetWords.enumerated() {
            var current = [i + 1] + empty.dropFirst()
            for (j, inputWord) in inputWords.enumerated() {
                if targetWord == inputWord {
                    current[j + 1] = last[j]
                } else {
                    current[j + 1] = min(last[j], current[j], last[j + 1]) + 1
                }
            }
            last = current
        }

        let diffCount = last.last ?? 0
        let maxLength = max(targetWords.count, inputWords.count)
        let sequenceScoreRaw = Double(maxLength - diffCount) / Double(maxLength)
        let sequenceScore = max(0, sequenceScoreRaw * 100)
        let boundedConfidence = min(max(averageConfidence, 0), 1)
        let confidenceScore = boundedConfidence * 100
        let finalScore = max(0, sequenceScoreRaw * boundedConfidence * 100)

        return PronunciationScore(
            finalScore: finalScore,
            sequenceScore: sequenceScore,
            confidenceScore: confidenceScore
        )
    }
}

enum ReviewScheduler {
    static func nextLearningLevel(from currentLevel: Int) -> Int {
        min(currentLevel + 1, 6)
    }

    static func reviewDelayDays(for learningLevel: Int) -> Int {
        switch learningLevel {
        case 1: return 0
        case 2: return 1
        case 3: return 3
        case 4: return 7
        case 5: return 15
        case 6: return 0
        default: return 0
        }
    }

    static func nextReviewDate(for learningLevel: Int, from date: Date) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: reviewDelayDays(for: learningLevel),
            to: date
        ) ?? date
    }

    static func reviewString(for learningLevel: Int, from date: Date, formatter: ISO8601DateFormatter) -> String {
        formatter.string(from: nextReviewDate(for: learningLevel, from: date))
    }

    static func isDue(_ vocab: Vocabulary, now: Date) -> Bool {
        guard let level = vocab.learning_level, level > 0 else { return false }
        guard let nextReview = vocab.next_review else { return true }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        if let date = fractionalFormatter.date(from: nextReview) ?? fallbackFormatter.date(from: nextReview) {
            return date <= now
        }

        return true
    }
}

enum LearningSessionBuilder {
    static func build(from vocabs: [Vocabulary], now: Date = Date(), maxWords: Int = 7) -> LearningSessionPlan {
        let allGrouped = Dictionary(grouping: vocabs, by: {
            $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() ?? "unknown"
        })

        let allJoinedMeanings = Array(Set(allGrouped.values.compactMap { group -> String? in
            let meanings = group.compactMap { $0.V_meaning }.filter { !$0.isEmpty }
            return meanings.isEmpty ? nil : meanings.joined(separator: " / ")
        }))

        var dueGroups: [[Vocabulary]] = []
        var masterDueGroups: [[Vocabulary]] = []
        var stats = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0]
        var totalLearningWords = 0

        for group in allGrouped.values {
            let isLearning = group.contains { ($0.learning_level ?? 0) > 0 }
            guard isLearning else { continue }

            totalLearningWords += 1
            let level = group.first(where: { ($0.learning_level ?? 0) > 0 })?.learning_level ?? 1
            stats[level, default: 0] += 1

            let isDue = group.contains { ReviewScheduler.isDue($0, now: now) }
            let hasPassedPronunciation = (group.first(where: { ($0.learning_level ?? 0) > 0 })?.pronunciation_score ?? 0) >= 70

            if level == 6 && !hasPassedPronunciation {
                masterDueGroups.append(group)
            } else if level < 6 && isDue {
                dueGroups.append(group)
            }
        }

        let dueCount = dueGroups.count
        let masterDueCount = masterDueGroups.count

        dueGroups.shuffle()
        let selectedGroups = Array(dueGroups.prefix(maxWords))
        let tasks = buildLearningTasks(from: selectedGroups, allJoinedMeanings: allJoinedMeanings).shuffled()

        masterDueGroups.shuffle()
        let selectedMasterGroups = Array(masterDueGroups.prefix(maxWords))
        let masterTasks = buildMasterTasks(from: selectedMasterGroups)

        return LearningSessionPlan(
            selectedGroups: selectedGroups,
            tasks: tasks,
            masterTasks: masterTasks,
            statsByLevel: stats,
            totalLearningWords: totalLearningWords,
            totalSavedWords: allGrouped.count,
            dueVocabsCount: dueCount,
            masterDueVocabsCount: masterDueCount
        )
    }

    private static func buildLearningTasks(from groups: [[Vocabulary]], allJoinedMeanings: [String]) -> [LearningTask] {
        var tasks: [LearningTask] = []

        for group in groups {
            guard let word = group.first?.vocab else { continue }

            tasks.append(LearningTask(word: word, meanings: group, type: .listenAndType))
            tasks.append(LearningTask(word: word, meanings: group, type: .meaningAndType))

            let correctMeaning = group.compactMap { $0.V_meaning }.filter { !$0.isEmpty }.joined(separator: " / ")
            let correctOption = correctMeaning.isEmpty ? "Không có nghĩa" : correctMeaning
            var options = [correctOption]
            let distractors = allJoinedMeanings.filter { $0 != correctOption }.shuffled()
            options.append(contentsOf: distractors.prefix(3))

            while options.count < 4 {
                options.append("Nghĩa giả định \(UUID().uuidString.prefix(4))")
            }

            options.shuffle()
            tasks.append(LearningTask(word: word, meanings: group, type: .multipleChoice, options: options))

            for meaning in group {
                if let example = meaning.E_example, !example.isEmpty {
                    let words = LearningTextNormalizer.sentenceScrambleWords(example)

                    if words.count >= 3 {
                        tasks.append(LearningTask(
                            word: word,
                            meanings: group,
                            type: .sentenceScramble,
                            correctSentence: example,
                            scrambledWords: words.shuffled(),
                            vHint: meaning.V_example
                        ))
                    }
                }
            }
        }

        return tasks
    }

    private static func buildMasterTasks(from groups: [[Vocabulary]]) -> [PronunciationTask] {
        var tasks: [PronunciationTask] = []

        for group in groups {
            guard let word = group.first?.vocab else { continue }
            if let meaningWithExample = group.first(where: { $0.E_example != nil && !$0.E_example!.isEmpty }),
               let example = meaningWithExample.E_example {
                tasks.append(PronunciationTask(word: word, targetText: example, meaning: meaningWithExample))
            } else if let first = group.first {
                tasks.append(PronunciationTask(word: word, targetText: word, meaning: first))
            }
        }

        return tasks
    }
}
