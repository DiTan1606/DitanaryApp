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
        ReviewIntervalSettings.days(for: learningLevel)
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

enum ReviewIntervalSettings {
    static let defaults = [1: 0, 2: 1, 3: 3, 4: 7, 5: 15]
    static let ranges = [1: 0...1, 2: 1...3, 3: 3...7, 4: 7...21, 5: 15...45]

    static func days(for level: Int) -> Int {
        guard level < 6 else { return 0 }
        let fallback = defaults[level] ?? 0
        let stored = UserDefaults.standard.object(forKey: key(for: level)) as? Int ?? fallback
        return clamped(stored, for: level)
    }

    static func setDays(_ days: Int, for level: Int) {
        UserDefaults.standard.set(clamped(days, for: level), forKey: key(for: level))
    }

    static func reset() {
        for level in 1...5 {
            UserDefaults.standard.removeObject(forKey: key(for: level))
        }
    }

    static func range(for level: Int) -> ClosedRange<Int> {
        ranges[level] ?? 0...0
    }

    private static func clamped(_ days: Int, for level: Int) -> Int {
        let range = range(for: level)
        return min(max(days, range.lowerBound), range.upperBound)
    }

    private static func key(for level: Int) -> String {
        "review_interval_level_\(level)"
    }
}

enum ReviewTimeFormatter {
    static func text(for dateStr: String?) -> String {
        guard let dateStr else { return "Ngay bây giờ" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        guard let date = formatter.date(from: dateStr) ?? fallbackFormatter.date(from: dateStr) else {
            return "Ngay bây giờ"
        }

        let now = Date()
        if date <= now {
            return "Hôm nay"
        }

        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        if let days = diff.day, days > 0 {
            return "sau \(days) ngày"
        }
        if let hours = diff.hour, hours > 0 {
            return "sau \(hours) giờ"
        }
        if let minutes = diff.minute, minutes > 0 {
            return "sau \(minutes) phút"
        }
        return "Ngay bây giờ"
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
            let pronunciationScores = group.compactMap(\.pronunciation_score)
            let hasPassedPronunciation = !pronunciationScores.isEmpty
                && pronunciationScores.reduce(0, +) / pronunciationScores.count >= 70
                && pronunciationScores.count == group.count

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
            for meaning in group {
                if let example = meaning.E_example, !example.isEmpty {
                    tasks.append(PronunciationTask(word: word, targetText: example, meaning: meaning))
                } else {
                    tasks.append(PronunciationTask(word: word, targetText: word, meaning: meaning))
                }
            }
        }

        return tasks
    }
}
