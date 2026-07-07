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
