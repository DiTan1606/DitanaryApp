import Foundation
import Supabase

enum VocabularyRepository {
    static func fetchUserVocabs(userId: String, ordered: Bool = false) async throws -> [Vocabulary] {
        if ordered {
            return try await supabase
                .from("vocab_list")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
        }

        return try await supabase
            .from("vocab_list")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    static func fetchSystemVocabs(adminUserId: String) async throws -> [Vocabulary] {
        try await supabase
            .from("vocab_list")
            .select()
            .eq("user_id", value: adminUserId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func insert(_ vocabs: [Vocabulary]) async throws {
        try await supabase
            .from("vocab_list")
            .insert(vocabs)
            .execute()
    }

    static func insert(_ vocab: Vocabulary) async throws {
        try await supabase
            .from("vocab_list")
            .insert(vocab)
            .execute()
    }

    static func update(_ vocab: Vocabulary) async throws {
        guard let id = vocab.id else { return }
        try await supabase
            .from("vocab_list")
            .update(vocab)
            .eq("ID", value: id)
            .execute()
    }

    static func delete(id: String) async throws {
        try await supabase
            .from("vocab_list")
            .delete()
            .eq("ID", value: id)
            .execute()
    }

    static func updateLearningData(id: String, learningLevel: Int, nextReview: String) async throws {
        try await supabase
            .from("vocab_list")
            .update(UpdateLearningData(learning_level: learningLevel, next_review: nextReview))
            .eq("ID", value: id)
            .execute()
    }

    static func updatePronunciationScore(id: String, score: Int) async throws {
        try await supabase
            .from("vocab_list")
            .update(UpdatePronunciationScore(pronunciation_score: score))
            .eq("ID", value: id)
            .execute()
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
