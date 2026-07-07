import Foundation

enum QuestionType {
    case listenAndType
    case meaningAndType
    case multipleChoice
    case sentenceScramble
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
}

struct TaskResult: Identifiable {
    let id = UUID()
    let task: LearningTask
    let isCorrect: Bool
    let selectedOption: String?
    let answerText: String
}
