import Foundation
import Supabase

struct AzurePronunciationAssessment: Decodable {
    struct Scores: Decodable {
        let pronunciation: Double
        let accuracy: Double
        let fluency: Double
        let completeness: Double
    }

    struct WordFeedback: Decodable, Identifiable {
        struct PhonemeFeedback: Decodable, Identifiable {
            let phoneme: String
            let accuracy: Double
            var heardPhoneme: String? = nil
            var heardScore: Double? = nil

            var id: String { phoneme }
        }

        let word: String
        let accuracy: Double
        let errorType: String
        var offsetMilliseconds: Int? = nil
        var durationMilliseconds: Int? = nil
        let phonemes: [PhonemeFeedback]

        var id: String { "\(offsetMilliseconds ?? -1)-\(word)" }
    }

    struct ShadowingProgress: Decodable {
        let status: String
        let attemptPassed: Bool
        let attempts: Int
        let latestScore: Double
        let bestScore: Double
        let passedSegmentCount: Int
        let totalSegmentCount: Int
        let lessonLatestScore: Double
        let lessonBestScore: Double
        let lessonPassed: Bool
    }

    let referenceText: String
    let transcript: String
    let scores: Scores
    let words: [WordFeedback]
    let shadowingProgress: ShadowingProgress? = nil
}

enum PronunciationFeedbackLevel: Equatable {
    case good
    case needsImprovement
    case retry

    var title: String {
        switch self {
        case .good:
            return "Tốt"
        case .needsImprovement:
            return "Cần cải thiện"
        case .retry:
            return "Cần đọc lại"
        }
    }
}

enum PronunciationPassingRule {
    static let minimumPronunciationScore = 82.0
    static let minimumAccuracyScore = 80.0
    static let minimumCompletenessScore = 95.0
    static let minimumWordAccuracyScore = 70.0
    static let strongWordAccuracyScore = 85.0
    static let minimumPhonemeAccuracyScore = 60.0
    static let strongPhonemeAccuracyScore = 80.0

    private static let criticalErrorTypes: Set<String> = [
        "mispronunciation",
        "omission",
        "insertion"
    ]

    static func passes(_ assessment: AzurePronunciationAssessment) -> Bool {
        failureReasons(for: assessment).isEmpty
    }

    static func failureReasons(for assessment: AzurePronunciationAssessment) -> [String] {
        var reasons: [String] = []
        let scores = assessment.scores

        if scores.pronunciation < minimumPronunciationScore {
            reasons.append("Điểm tổng cần từ \(Int(minimumPronunciationScore)) trở lên")
        }
        if scores.accuracy < minimumAccuracyScore {
            reasons.append("Điểm chính xác cần từ \(Int(minimumAccuracyScore)) trở lên")
        }
        if scores.completeness < minimumCompletenessScore {
            reasons.append("Bạn cần đọc gần như đầy đủ cả câu")
        }
        if assessment.words.isEmpty {
            reasons.append("Chưa nhận được kết quả chi tiết từng từ, hãy thu âm lại")
        }

        if let criticalWord = assessment.words.first(where: { isCriticalError($0.errorType) }) {
            reasons.append(feedbackMessage(for: criticalWord) ?? "Có từ cần phát âm hoặc đọc lại rõ hơn")
        }

        if let weakWord = assessment.words.first(where: {
            !isCriticalError($0.errorType) && $0.accuracy < minimumWordAccuracyScore
        }) {
            reasons.append("Từ “\(weakWord.word)” cần đạt ít nhất \(Int(minimumWordAccuracyScore)) điểm")
        }

        return reasons
    }

    static func feedbackLevel(for word: AzurePronunciationAssessment.WordFeedback) -> PronunciationFeedbackLevel {
        if isCriticalError(word.errorType) || word.accuracy < minimumWordAccuracyScore {
            return .retry
        }
        if word.accuracy < strongWordAccuracyScore {
            return .needsImprovement
        }
        return .good
    }

    static func feedbackLevel(for phoneme: AzurePronunciationAssessment.WordFeedback.PhonemeFeedback) -> PronunciationFeedbackLevel {
        if phoneme.accuracy < minimumPhonemeAccuracyScore {
            return .retry
        }
        if phoneme.accuracy < strongPhonemeAccuracyScore {
            return .needsImprovement
        }
        return .good
    }

    static func heardAs(for phoneme: AzurePronunciationAssessment.WordFeedback.PhonemeFeedback) -> String? {
        guard feedbackLevel(for: phoneme) != .good,
              let heardPhoneme = phoneme.heardPhoneme?.trimmingCharacters(in: .whitespacesAndNewlines),
              !heardPhoneme.isEmpty,
              normalizedPhoneme(heardPhoneme) != normalizedPhoneme(phoneme.phoneme) else {
            return nil
        }

        return heardPhoneme
    }

    static func feedbackMessage(for word: AzurePronunciationAssessment.WordFeedback) -> String? {
        switch normalizedErrorType(word.errorType) {
        case "omission":
            return "Bạn đã bỏ sót từ “\(word.word)”"
        case "insertion":
            return "Bạn đã đọc thừa từ “\(word.word)”"
        case "mispronunciation":
            return "Từ “\(word.word)” cần phát âm lại"
        default:
            if word.accuracy < minimumWordAccuracyScore {
                return "Từ “\(word.word)” cần đọc lại rõ hơn"
            }
            return nil
        }
    }

    static func isCriticalError(_ errorType: String) -> Bool {
        criticalErrorTypes.contains(normalizedErrorType(errorType))
    }

    private static func normalizedErrorType(_ errorType: String) -> String {
        errorType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedPhoneme(_ phoneme: String) -> String {
        phoneme
            .replacingOccurrences(of: "/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

enum ShadowingPassingRule {
    static let minimumFluencyScore = 65.0

    static func passes(_ assessment: AzurePronunciationAssessment) -> Bool {
        PronunciationPassingRule.passes(assessment)
            && assessment.scores.fluency >= minimumFluencyScore
    }

    static func failureReasons(for assessment: AzurePronunciationAssessment) -> [String] {
        var reasons = PronunciationPassingRule.failureReasons(for: assessment)

        if assessment.scores.fluency < minimumFluencyScore {
            reasons.append("Độ trôi chảy cần từ \(Int(minimumFluencyScore)) trở lên")
        }

        return reasons
    }
}

enum PronunciationAssessmentService {
    static func assess(audioURL: URL, userVocabularyId: String) async throws -> AzurePronunciationAssessment {
        try await assess(
            audioURL: audioURL,
            identifierField: "userVocabularyId",
            identifierValue: userVocabularyId
        )
    }

    static func assessListeningSegment(
        audioURL: URL,
        segmentId: String
    ) async throws -> AzurePronunciationAssessment {
        try await assess(
            audioURL: audioURL,
            identifierField: "listeningSegmentId",
            identifierValue: segmentId
        )
    }

    private static func assess(
        audioURL: URL,
        identifierField: String,
        identifierValue: String
    ) async throws -> AzurePronunciationAssessment {
        let audioData = try Data(contentsOf: audioURL)
        let boundary = "DitanaryBoundary-\(UUID().uuidString)"
        let body = multipartBody(
            boundary: boundary,
            identifierField: identifierField,
            identifierValue: identifierValue,
            audioData: audioData
        )

        return try await supabase.functions.invoke(
            "pronunciation-assessment",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
                body: body
            )
        )
    }

    private static func multipartBody(
        boundary: String,
        identifierField: String,
        identifierValue: String,
        audioData: Data
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func append(_ value: String) {
            body.append(value.data(using: .utf8)!)
        }

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"\(identifierField)\"\(lineBreak)\(lineBreak)")
        append("\(identifierValue)\(lineBreak)")
        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"audio\"; filename=\"pronunciation.wav\"\(lineBreak)")
        append("Content-Type: audio/wav\(lineBreak)\(lineBreak)")
        body.append(audioData)
        append(lineBreak)
        append("--\(boundary)--\(lineBreak)")

        return body
    }
}
