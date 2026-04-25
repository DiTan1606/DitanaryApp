import Foundation

struct Vocabulary: Identifiable, Codable, Hashable {
    var id: String?
    var created_at: String?
    var topics: String?
    var vocab: String?
    var CEFR: String?
    var IPA: String?
    var word_form: String?
    var E_meaning: String?
    var EV_meaning: String?
    var V_meaning: String?
    var E_example: String?
    var V_example: String?
    var word_family: String?
    var synonymous: String?
    var antonym: String?
    var bonus: String?
    var user_id: String?
    var learning_level: Int?
    var next_review: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case created_at
        case topics
        case vocab
        case CEFR
        case IPA
        case word_form
        case E_meaning
        case EV_meaning
        case V_meaning
        case E_example
        case V_example
        case word_family
        case synonymous
        case antonym
        case bonus
        case user_id
        case learning_level
        case next_review
    }
    
    init(id: String? = UUID().uuidString,
         created_at: String? = nil,
         topics: String? = nil,
         vocab: String? = nil,
         CEFR: String? = nil,
         IPA: String? = nil,
         word_form: String? = nil,
         E_meaning: String? = nil,
         EV_meaning: String? = nil,
         V_meaning: String? = nil,
         E_example: String? = nil,
         V_example: String? = nil,
         word_family: String? = nil,
         synonymous: String? = nil,
         antonym: String? = nil,
         bonus: String? = nil,
         user_id: String? = nil,
         learning_level: Int? = 0,
         next_review: String? = nil) {
        self.id = id
        self.created_at = created_at
        self.topics = topics
        self.vocab = vocab
        self.CEFR = CEFR
        self.IPA = IPA
        self.word_form = word_form
        self.E_meaning = E_meaning
        self.EV_meaning = EV_meaning
        self.V_meaning = V_meaning
        self.E_example = E_example
        self.V_example = V_example
        self.word_family = word_family
        self.synonymous = synonymous
        self.antonym = antonym
        self.bonus = bonus
        self.user_id = user_id
        self.learning_level = learning_level
        self.next_review = next_review
    }
}

struct UpdateLearningData: Encodable {
    let learning_level: Int
    let next_review: String
}
struct Profile: Identifiable, Codable {
    var id: String
    var email: String?
    var display_name: String?
    var avatar_url: String?
    var role: String?
    var created_at: String?
}

struct ActivityLog: Identifiable, Codable {
    var id: String?
    var user_id: String?
    var date: String // YYYY-MM-DD
    var completed: Bool
}

struct UserStats: Codable {
    var user_id: String
    var streak_count: Int
    var last_learning_date: String?
}

struct Notification: Identifiable, Codable {
    var id: String
    var user_id: String?
    var title: String
    var content: String
    var is_read: Bool
    var created_at: String?
}
