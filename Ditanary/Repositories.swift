import Foundation
import Supabase

enum VocabularyRepository {
    private struct TopicRow: Codable {
        let id: String
        let name: String
    }

    private struct VocabCatalogRow: Codable {
        let id: String
        let created_at: String?
        let topic_id: String?
        let created_by: String?
        let visibility: String?
        let word: String?
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
        let topics: TopicRow?
    }

    private struct UserVocabularyRow: Codable {
        let id: String
        let user_id: String?
        let vocab_id: String?
        let learning_level: Int?
        let next_review: String?
        let pronunciation_score: Int?
        let saved_at: String?
        let vocab_catalog: VocabCatalogRow?
    }

    private struct VocabCatalogInsert: Encodable {
        let id: String
        let topic_id: String?
        let created_by: String?
        let visibility: String
        let word: String
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
    }

    private struct VocabCatalogUpdate: Encodable {
        let topic_id: String?
        let word: String
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
    }

    private struct UserVocabularyInsert: Encodable {
        let id: String
        let user_id: String
        let vocab_id: String
        let learning_level: Int
        let next_review: String?
        let pronunciation_score: Int?
    }

    private struct UserVocabularyDeleteLookup: Decodable {
        let id: String
        let vocab_id: String?
        let vocab_catalog: VocabCatalogRow?
    }

    static func fetchUserVocabs(userId: String, ordered: Bool = false) async throws -> [Vocabulary] {
        let selectColumns = """
        id,user_id,vocab_id,learning_level,next_review,pronunciation_score,saved_at,
        vocab_catalog(id,created_at,topic_id,created_by,visibility,word,cefr,ipa,word_form,e_meaning,ev_meaning,v_meaning,e_example,v_example,word_family,synonymous,antonym,bonus,topics(id,name))
        """

        if ordered {
            let rows: [UserVocabularyRow] = try await supabase
                .from("user_vocabulary")
                .select(selectColumns)
                .eq("user_id", value: userId)
                .order("saved_at", ascending: false)
                .execute()
                .value

            return rows.compactMap(mapUserVocabulary)
        }

        let rows: [UserVocabularyRow] = try await supabase
            .from("user_vocabulary")
            .select(selectColumns)
            .eq("user_id", value: userId)
            .execute()
            .value

        return rows.compactMap(mapUserVocabulary)
    }

    static func fetchSystemVocabs(adminUserId: String) async throws -> [Vocabulary] {
        let rows: [VocabCatalogRow] = try await supabase
            .from("vocab_catalog")
            .select("id,created_at,topic_id,created_by,visibility,word,cefr,ipa,word_form,e_meaning,ev_meaning,v_meaning,e_example,v_example,word_family,synonymous,antonym,bonus,topics(id,name)")
            .eq("visibility", value: "system")
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map(mapCatalog)
    }

    static func insert(_ vocabs: [Vocabulary]) async throws {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        let links = vocabs.compactMap { vocab -> UserVocabularyInsert? in
            guard let catalogId = vocab.catalog_id ?? vocab.id else { return nil }
            return UserVocabularyInsert(
                id: UUID().uuidString,
                user_id: userId,
                vocab_id: catalogId,
                learning_level: vocab.learning_level ?? 0,
                next_review: vocab.next_review,
                pronunciation_score: vocab.pronunciation_score
            )
        }

        guard !links.isEmpty else { return }
        try await supabase
            .from("user_vocabulary")
            .insert(links)
            .execute()
    }

    static func insert(_ vocab: Vocabulary, asSystem: Bool = false) async throws {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        let catalogId = vocab.catalog_id ?? vocab.id ?? UUID().uuidString
        let topicId = try await topicId(for: vocab.topics, allowCreate: asSystem)

        try await supabase
            .from("vocab_catalog")
            .insert(makeCatalogInsert(from: vocab, id: catalogId, topicId: topicId, userId: userId, asSystem: asSystem))
            .execute()

        if !asSystem {
            let link = UserVocabularyInsert(
                id: UUID().uuidString,
                user_id: userId,
                vocab_id: catalogId,
                learning_level: vocab.learning_level ?? 0,
                next_review: vocab.next_review,
                pronunciation_score: vocab.pronunciation_score
            )

            try await supabase
                .from("user_vocabulary")
                .insert(link)
                .execute()
        }
    }

    static func update(_ vocab: Vocabulary) async throws {
        guard let catalogId = vocab.catalog_id ?? (vocab.user_vocabulary_id == nil ? vocab.id : nil) else { return }
        let topicId = try await topicId(for: vocab.topics, allowCreate: await AuthManager.shared.isAdmin)

        try await supabase
            .from("vocab_catalog")
            .update(makeCatalogUpdate(from: vocab, topicId: topicId))
            .eq("id", value: catalogId)
            .execute()
    }

    static func delete(id: String) async throws {
        let userRows: [UserVocabularyDeleteLookup] = try await supabase
            .from("user_vocabulary")
            .select("id,vocab_id,vocab_catalog(id,visibility)")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        try await supabase
            .from("user_vocabulary")
            .delete()
            .eq("id", value: id)
            .execute()

        if let userRow = userRows.first,
           userRow.vocab_catalog?.visibility == "private",
           let catalogId = userRow.vocab_id {
            try await supabase
                .from("vocab_catalog")
                .delete()
                .eq("id", value: catalogId)
                .execute()
            return
        }

        try await supabase
            .from("vocab_catalog")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    static func updateLearningData(id: String, learningLevel: Int, nextReview: String) async throws {
        try await supabase
            .from("user_vocabulary")
            .update(UpdateLearningData(learning_level: learningLevel, next_review: nextReview))
            .eq("id", value: id)
            .execute()
    }

    static func updatePronunciationScore(id: String, score: Int) async throws {
        try await supabase
            .from("user_vocabulary")
            .update(UpdatePronunciationScore(pronunciation_score: score))
            .eq("id", value: id)
            .execute()
    }

    private static func topicId(for topicName: String?, allowCreate: Bool) async throws -> String? {
        let name = topicName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let existing: [TopicRow] = try await supabase
            .from("topics")
            .select("id,name")
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value

        if let topic = existing.first {
            return topic.id
        }

        guard allowCreate else { return nil }

        let topic = TopicRow(id: UUID().uuidString, name: name)
        try await supabase
            .from("topics")
            .insert(topic)
            .execute()

        return topic.id
    }

    private static func makeCatalogInsert(from vocab: Vocabulary, id: String, topicId: String?, userId: String, asSystem: Bool) -> VocabCatalogInsert {
        VocabCatalogInsert(
            id: id,
            topic_id: topicId,
            created_by: userId,
            visibility: asSystem ? "system" : "private",
            word: normalizedRequiredWord(vocab.vocab),
            cefr: nilIfEmpty(vocab.CEFR),
            ipa: nilIfEmpty(vocab.IPA),
            word_form: nilIfEmpty(vocab.word_form),
            e_meaning: nilIfEmpty(vocab.E_meaning),
            ev_meaning: nilIfEmpty(vocab.EV_meaning),
            v_meaning: nilIfEmpty(vocab.V_meaning),
            e_example: nilIfEmpty(vocab.E_example),
            v_example: nilIfEmpty(vocab.V_example),
            word_family: nilIfEmpty(vocab.word_family),
            synonymous: nilIfEmpty(vocab.synonymous),
            antonym: nilIfEmpty(vocab.antonym),
            bonus: nilIfEmpty(vocab.bonus)
        )
    }

    private static func makeCatalogUpdate(from vocab: Vocabulary, topicId: String?) -> VocabCatalogUpdate {
        VocabCatalogUpdate(
            topic_id: topicId,
            word: normalizedRequiredWord(vocab.vocab),
            cefr: nilIfEmpty(vocab.CEFR),
            ipa: nilIfEmpty(vocab.IPA),
            word_form: nilIfEmpty(vocab.word_form),
            e_meaning: nilIfEmpty(vocab.E_meaning),
            ev_meaning: nilIfEmpty(vocab.EV_meaning),
            v_meaning: nilIfEmpty(vocab.V_meaning),
            e_example: nilIfEmpty(vocab.E_example),
            v_example: nilIfEmpty(vocab.V_example),
            word_family: nilIfEmpty(vocab.word_family),
            synonymous: nilIfEmpty(vocab.synonymous),
            antonym: nilIfEmpty(vocab.antonym),
            bonus: nilIfEmpty(vocab.bonus)
        )
    }

    private static func mapCatalog(_ row: VocabCatalogRow) -> Vocabulary {
        Vocabulary(
            id: row.id,
            catalog_id: row.id,
            created_at: row.created_at,
            topic_id: row.topic_id,
            topics: row.topics?.name,
            created_by: row.created_by,
            visibility: row.visibility,
            vocab: row.word,
            CEFR: row.cefr,
            IPA: row.ipa,
            word_form: row.word_form,
            E_meaning: row.e_meaning,
            EV_meaning: row.ev_meaning,
            V_meaning: row.v_meaning,
            E_example: row.e_example,
            V_example: row.v_example,
            word_family: row.word_family,
            synonymous: row.synonymous,
            antonym: row.antonym,
            bonus: row.bonus,
            user_id: row.created_by,
            learning_level: 0
        )
    }

    private static func mapUserVocabulary(_ row: UserVocabularyRow) -> Vocabulary? {
        guard let catalog = row.vocab_catalog else { return nil }
        return Vocabulary(
            id: row.id,
            catalog_id: catalog.id,
            user_vocabulary_id: row.id,
            created_at: catalog.created_at,
            saved_at: row.saved_at,
            topic_id: catalog.topic_id,
            topics: catalog.topics?.name,
            created_by: catalog.created_by,
            visibility: catalog.visibility,
            vocab: catalog.word,
            CEFR: catalog.cefr,
            IPA: catalog.ipa,
            word_form: catalog.word_form,
            E_meaning: catalog.e_meaning,
            EV_meaning: catalog.ev_meaning,
            V_meaning: catalog.v_meaning,
            E_example: catalog.e_example,
            V_example: catalog.v_example,
            word_family: catalog.word_family,
            synonymous: catalog.synonymous,
            antonym: catalog.antonym,
            bonus: catalog.bonus,
            user_id: row.user_id,
            learning_level: row.learning_level,
            next_review: row.next_review,
            pronunciation_score: row.pronunciation_score
        )
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func normalizedRequiredWord(_ value: String?) -> String {
        nilIfEmpty(value) ?? "Untitled"
    }
}

enum ContributionRepository {
    private struct TopicRow: Codable {
        let id: String
        let name: String
    }

    private struct VocabCatalogRow: Codable {
        let id: String
        let created_at: String?
        let topic_id: String?
        let created_by: String?
        let visibility: String?
        let word: String?
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
        let topics: TopicRow?
    }

    private struct VocabSubmissionInsert: Encodable {
        let id: String
        let requester_id: String
        let catalog_id: String
        let topic_id: String?
        let status: String
    }

    private struct VocabSubmissionRow: Decodable {
        let id: String
        let requester_id: String
        let catalog_id: String?
        let status: String
        let created_at: String?
        let vocab_catalog: VocabCatalogRow?
    }

    private struct TopicSubmissionInsert: Encodable {
        let id: String
        let requester_id: String
        let name: String
        let description: String?
        let status: String
    }

    private struct TopicSubmissionWordInsert: Encodable {
        let id: String
        let submission_id: String
        let word: String
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
    }

    private struct TopicSubmissionWordRow: Decodable {
        let id: String
        let word: String
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
    }

    private struct TopicSubmissionRow: Decodable {
        let id: String
        let requester_id: String
        let name: String
        let description: String?
        let status: String
        let created_at: String?
        let topic_submission_words: [TopicSubmissionWordRow]?
    }

    private struct VocabCatalogInsert: Encodable {
        let id: String
        let topic_id: String?
        let created_by: String?
        let visibility: String
        let word: String
        let cefr: String?
        let ipa: String?
        let word_form: String?
        let e_meaning: String?
        let ev_meaning: String?
        let v_meaning: String?
        let e_example: String?
        let v_example: String?
        let word_family: String?
        let synonymous: String?
        let antonym: String?
        let bonus: String?
    }

    private struct UserVocabularyInsert: Encodable {
        let id: String
        let user_id: String
        let vocab_id: String
        let learning_level: Int
        let next_review: String?
        let pronunciation_score: Int?
    }

    private struct ReviewUpdate: Encodable {
        let status: String
        let reviewed_by: String?
        let reviewed_at: String?
    }

    static func submitVocabulary(_ vocab: Vocabulary) async throws {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString,
              let catalogId = vocab.catalog_id ?? vocab.id else { return }

        let submission = VocabSubmissionInsert(
            id: UUID().uuidString,
            requester_id: userId,
            catalog_id: catalogId,
            topic_id: vocab.topic_id,
            status: "pending"
        )

        try await supabase
            .from("vocab_submissions")
            .insert(submission)
            .execute()
    }

    static func fetchPendingVocabularySubmissions() async throws -> [VocabContribution] {
        let rows: [VocabSubmissionRow] = try await supabase
            .from("vocab_submissions")
            .select("""
            id,requester_id,catalog_id,status,created_at,
            vocab_catalog(id,created_at,topic_id,created_by,visibility,word,cefr,ipa,word_form,e_meaning,ev_meaning,v_meaning,e_example,v_example,word_family,synonymous,antonym,bonus,topics(id,name))
            """)
            .eq("status", value: "pending")
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.compactMap { row in
            guard let catalog = row.vocab_catalog else { return nil }
            return VocabContribution(
                id: row.id,
                requesterId: row.requester_id,
                status: row.status,
                createdAt: row.created_at,
                vocab: mapCatalog(catalog)
            )
        }
    }

    static func fetchUserVocabularySubmissionStatuses() async throws -> [VocabSubmissionStatus] {
        let rows: [VocabSubmissionRow] = try await supabase
            .from("vocab_submissions")
            .select("id,requester_id,catalog_id,status,created_at")
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.compactMap { row in
            guard let catalogId = row.catalog_id else { return nil }
            return VocabSubmissionStatus(
                id: row.id,
                catalogId: catalogId,
                status: row.status,
                createdAt: row.created_at
            )
        }
    }

    static func approveVocabularySubmission(_ submission: VocabContribution) async throws {
        guard let catalogId = submission.vocab.catalog_id ?? submission.vocab.id else { return }

        try await supabase
            .from("vocab_catalog")
            .update(["visibility": "system"] as [String: String])
            .eq("id", value: catalogId)
            .execute()

        try await markVocabSubmission(submission.id, status: "approved")
        try await sendNotification(
            userId: submission.requesterId,
            title: "Từ đã được duyệt",
            content: "\"\(submission.vocab.vocab ?? "Từ vựng")\" đã được bổ sung vào bộ từ hệ thống."
        )
    }

    static func rejectVocabularySubmission(_ submission: VocabContribution) async throws {
        try await markVocabSubmission(submission.id, status: "rejected")
        try await sendNotification(
            userId: submission.requesterId,
            title: "Từ chưa được duyệt",
            content: "\"\(submission.vocab.vocab ?? "Từ vựng")\" chưa được duyệt. Bạn có thể chỉnh lại rồi gửi duyệt lại."
        )
    }

    static func submitTopicDraft(name: String, description: String?, words: [TopicDraftWordInput]) async throws {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let validWords = words.filter { !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validWords.isEmpty else { return }

        let submissionId = UUID().uuidString
        let submission = TopicSubmissionInsert(
            id: submissionId,
            requester_id: userId,
            name: trimmedName,
            description: nilIfEmpty(description),
            status: "pending"
        )

        try await supabase
            .from("topic_submissions")
            .insert(submission)
            .execute()

        let wordRows = validWords.map { word in
            TopicSubmissionWordInsert(
                id: UUID().uuidString,
                submission_id: submissionId,
                word: normalizedRequiredWord(word.word),
                cefr: nilIfEmpty(word.cefr),
                ipa: nilIfEmpty(word.ipa),
                word_form: nilIfEmpty(word.wordForm),
                e_meaning: nilIfEmpty(word.eMeaning),
                ev_meaning: nilIfEmpty(word.evMeaning),
                v_meaning: nilIfEmpty(word.vMeaning),
                e_example: nilIfEmpty(word.eExample),
                v_example: nilIfEmpty(word.vExample),
                word_family: nilIfEmpty(word.wordFamily),
                synonymous: nilIfEmpty(word.synonymous),
                antonym: nilIfEmpty(word.antonym),
                bonus: nilIfEmpty(word.bonus)
            )
        }

        try await supabase
            .from("topic_submission_words")
            .insert(wordRows)
            .execute()
    }

    static func fetchPendingTopicSubmissions() async throws -> [TopicContribution] {
        let rows: [TopicSubmissionRow] = try await supabase
            .from("topic_submissions")
            .select("""
            id,requester_id,name,description,status,created_at,
            topic_submission_words(id,word,cefr,ipa,word_form,e_meaning,ev_meaning,v_meaning,e_example,v_example,word_family,synonymous,antonym,bonus)
            """)
            .eq("status", value: "pending")
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows.map { row in
            TopicContribution(
                id: row.id,
                requesterId: row.requester_id,
                name: row.name,
                description: row.description,
                status: row.status,
                createdAt: row.created_at,
                words: (row.topic_submission_words ?? []).map(mapDraftWord)
            )
        }
    }

    static func approveTopicSubmission(_ submission: TopicContribution, approvedWordIds: Set<String>? = nil) async throws {
        guard let adminId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        let topicId = try await topicId(for: submission.name, allowCreate: true)
        let approvedWords = submission.words.filter { word in
            approvedWordIds?.contains(word.id) ?? true
        }
        let catalogRows = approvedWords.map { word in
            VocabCatalogInsert(
                id: UUID().uuidString,
                topic_id: topicId,
                created_by: submission.requesterId,
                visibility: "system",
                word: normalizedRequiredWord(word.word),
                cefr: nilIfEmpty(word.cefr),
                ipa: nilIfEmpty(word.ipa),
                word_form: nilIfEmpty(word.wordForm),
                e_meaning: nilIfEmpty(word.eMeaning),
                ev_meaning: nilIfEmpty(word.evMeaning),
                v_meaning: nilIfEmpty(word.vMeaning),
                e_example: nilIfEmpty(word.eExample),
                v_example: nilIfEmpty(word.vExample),
                word_family: nilIfEmpty(word.wordFamily),
                synonymous: nilIfEmpty(word.synonymous),
                antonym: nilIfEmpty(word.antonym),
                bonus: nilIfEmpty(word.bonus)
            )
        }

        guard !catalogRows.isEmpty else {
            try await markTopicSubmission(submission.id, status: "approved", reviewerId: adminId)
            return
        }

        try await supabase
            .from("vocab_catalog")
            .insert(catalogRows)
            .execute()

        let userRows = catalogRows.map {
            UserVocabularyInsert(
                id: UUID().uuidString,
                user_id: submission.requesterId,
                vocab_id: $0.id,
                learning_level: 0,
                next_review: nil,
                pronunciation_score: nil
            )
        }

        try await supabase
            .from("user_vocabulary")
            .insert(userRows)
            .execute()

        try await markTopicSubmission(submission.id, status: "approved", reviewerId: adminId)
        try await sendNotification(
            userId: submission.requesterId,
            title: "Topic nháp đã được duyệt",
            content: "\"\(submission.name)\" đã được duyệt với \(catalogRows.count) từ và tự động thêm vào kho từ của bạn."
        )
    }

    static func rejectTopicSubmission(_ submission: TopicContribution) async throws {
        try await markTopicSubmission(submission.id, status: "rejected")
        try await sendNotification(
            userId: submission.requesterId,
            title: "Topic nháp chưa được duyệt",
            content: "\"\(submission.name)\" chưa được duyệt. Bạn có thể tạo lại bản nháp tốt hơn rồi gửi lại."
        )
    }

    private static func markVocabSubmission(_ id: String, status: String) async throws {
        let reviewerId = await AuthManager.shared.currentUser?.id.uuidString
        try await supabase
            .from("vocab_submissions")
            .update(ReviewUpdate(status: status, reviewed_by: reviewerId, reviewed_at: nowString()))
            .eq("id", value: id)
            .execute()
    }

    private static func markTopicSubmission(_ id: String, status: String, reviewerId: String? = nil) async throws {
        let currentReviewerId = await AuthManager.shared.currentUser?.id.uuidString
        let reviewer = reviewerId ?? currentReviewerId
        try await supabase
            .from("topic_submissions")
            .update(ReviewUpdate(status: status, reviewed_by: reviewer, reviewed_at: nowString()))
            .eq("id", value: id)
            .execute()
    }

    private static func topicId(for topicName: String, allowCreate: Bool) async throws -> String? {
        let name = topicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let existing: [TopicRow] = try await supabase
            .from("topics")
            .select("id,name")
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value

        if let topic = existing.first {
            return topic.id
        }

        guard allowCreate else { return nil }

        let topic = TopicRow(id: UUID().uuidString, name: name)
        try await supabase
            .from("topics")
            .insert(topic)
            .execute()

        return topic.id
    }

    private static func mapCatalog(_ row: VocabCatalogRow) -> Vocabulary {
        Vocabulary(
            id: row.id,
            catalog_id: row.id,
            created_at: row.created_at,
            topic_id: row.topic_id,
            topics: row.topics?.name,
            created_by: row.created_by,
            visibility: row.visibility,
            vocab: row.word,
            CEFR: row.cefr,
            IPA: row.ipa,
            word_form: row.word_form,
            E_meaning: row.e_meaning,
            EV_meaning: row.ev_meaning,
            V_meaning: row.v_meaning,
            E_example: row.e_example,
            V_example: row.v_example,
            word_family: row.word_family,
            synonymous: row.synonymous,
            antonym: row.antonym,
            bonus: row.bonus,
            user_id: row.created_by,
            learning_level: 0
        )
    }

    private static func mapDraftWord(_ row: TopicSubmissionWordRow) -> TopicDraftWordInput {
        TopicDraftWordInput(
            id: row.id,
            word: row.word,
            cefr: row.cefr ?? "",
            ipa: row.ipa ?? "",
            wordForm: row.word_form ?? "",
            eMeaning: row.e_meaning ?? "",
            evMeaning: row.ev_meaning ?? "",
            vMeaning: row.v_meaning ?? "",
            eExample: row.e_example ?? "",
            vExample: row.v_example ?? "",
            wordFamily: row.word_family ?? "",
            synonymous: row.synonymous ?? "",
            antonym: row.antonym ?? "",
            bonus: row.bonus ?? ""
        )
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func normalizedRequiredWord(_ value: String?) -> String {
        nilIfEmpty(value) ?? "Untitled"
    }

    private static func nowString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func sendNotification(userId: String, title: String, content: String) async throws {
        let notification = Notification(
            id: UUID().uuidString,
            user_id: userId,
            title: title,
            content: content,
            is_read: false
        )
        try await NotificationRepository.insert(notification)
    }
}

enum UserProgressRepository {
    static func fetchStats(userId: String) async throws -> [UserStats] {
        try await supabase
            .from("user_stats")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    static func resetStreak(userId: String) async throws {
        try await supabase
            .from("user_stats")
            .update(["streak_count": 0])
            .eq("user_id", value: userId)
            .execute()
    }

    static func fetchCompletedActivityLogs(userId: String) async throws -> [ActivityLog] {
        try await supabase
            .from("activity_logs")
            .select()
            .eq("user_id", value: userId)
            .eq("completed", value: true)
            .execute()
            .value
    }

    static func recordDailyActivityAndUpdateStreak(userId: String, date: Date = Date()) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let log = ActivityLog(user_id: userId, date: dateString, completed: true)
        try await supabase
            .from("activity_logs")
            .upsert(log)
            .execute()

        let statsResponse = try await fetchStats(userId: userId)
        var stats = statsResponse.first ?? UserStats(user_id: userId, streak_count: 0, last_learning_date: nil)
        let calendar = Calendar.current

        if let lastDateString = stats.last_learning_date, let lastDate = formatter.date(from: lastDateString) {
            let diff = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastDate),
                to: calendar.startOfDay(for: date)
            ).day ?? 0

            if diff == 1 {
                stats.streak_count += 1
            } else if diff > 1 {
                stats.streak_count = 1
            }
        } else {
            stats.streak_count = 1
        }

        stats.last_learning_date = dateString

        try await supabase
            .from("user_stats")
            .upsert(stats)
            .execute()
    }
}

enum NotificationRepository {
    static func fetchUnreadCount(userId: String) async throws -> Int {
        try await supabase
            .from("notifications")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .count ?? 0
    }

    static func fetchUserNotifications(userId: String) async throws -> [Notification] {
        try await supabase
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func insert(_ notification: Notification) async throws {
        try await supabase
            .from("notifications")
            .insert(notification)
            .execute()
    }

    static func markAsRead(id: String) async throws {
        try await supabase
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: id)
            .execute()
    }

    static func delete(id: String) async throws {
        try await supabase
            .from("notifications")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    static func broadcast(title: String, content: String, profiles: [Profile]) async throws {
        for profile in profiles {
            let notification = Notification(
                id: UUID().uuidString,
                user_id: profile.id,
                title: title,
                content: content,
                is_read: false
            )
            try await insert(notification)
        }
    }
}

enum ProfileRepository {
    static func fetchRole(userId: String) async throws -> String? {
        struct RoleData: Decodable { let role: String? }
        let fetched: [RoleData] = try await supabase
            .from("profiles")
            .select("role")
            .eq("id", value: userId)
            .execute()
            .value

        return fetched.first?.role
    }

    static func fetchProfiles(ordered: Bool = false) async throws -> [Profile] {
        if ordered {
            return try await supabase
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        }

        return try await supabase
            .from("profiles")
            .select()
            .execute()
            .value
    }

    static func updateDisplayName(userId: String, name: String) async throws {
        try await supabase
            .from("profiles")
            .update(["display_name": name] as [String: String])
            .eq("id", value: userId)
            .execute()
    }

    static func updateAvatarURL(userId: String, urlString: String) async throws {
        try await supabase
            .from("profiles")
            .update(["avatar_url": urlString] as [String: String])
            .eq("id", value: userId)
            .execute()
    }

    static func updateProfile(_ profile: Profile) async throws {
        struct UpdateData: Encodable {
            let display_name: String
            let role: String
        }

        try await supabase
            .from("profiles")
            .update(UpdateData(display_name: profile.display_name ?? "", role: profile.role ?? "user"))
            .eq("id", value: profile.id)
            .execute()
    }

    static func deleteUser(id: String) async throws {
        struct DeleteParams: Encodable {
            let target_user_id: String
        }

        try await supabase
            .rpc("delete_user", params: DeleteParams(target_user_id: id))
            .execute()
    }
}
