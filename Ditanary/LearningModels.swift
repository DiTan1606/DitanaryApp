import Foundation

enum QuestionType: Equatable {
    case listenAndType
    case meaningAndType
    case multipleChoice
    case sentenceScramble
    case pronunciationExample
}

struct LearningTask: Identifiable {
    let id = UUID()
    let word: String
    let meanings: [Vocabulary]
    let type: QuestionType
    var options: [String] = []
    var correctSentence: String? = nil
    var scrambledWords: [String] = []
    var vHint: String? = nil
    var pronunciationMeaning: Vocabulary? = nil
    var pronunciationExample: String? = nil
}

struct TaskResult: Identifiable {
    let id = UUID()
    let task: LearningTask
    let isCorrect: Bool
    let selectedOption: String?
    let answerText: String
}

struct LearningSessionPlan {
    let selectedGroups: [[Vocabulary]]
    let tasks: [LearningTask]
    let statsByLevel: [Int: Int]
    let totalLearningWords: Int
    let totalSavedWords: Int
    let dueVocabsCount: Int
    let unavailablePronunciationWords: [String]
}
