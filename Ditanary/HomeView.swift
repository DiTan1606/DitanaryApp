import SwiftUI

struct HomeView: View {
    let adminUserId = AppConfig.adminUserId 
    
    @State private var storeVocabs: [Vocabulary] = []
    @State private var myVocabs: [Vocabulary] = [] // Store full objects for progress
    @State private var myCatalogIdsByTopic: [String: Set<String>] = [:]
    
    @State private var isLoading = false
    @State private var isDownloading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    // Streak and Activity states
    @State private var streakCount: Int = 0
    @State private var activityLogs: [String: Bool] = [:] // "YYYY-MM-DD" -> completed
    @State private var hasUnreadNotifications = false
    
    // Calendar state
    @State private var selectedMonth = Date()
    
    var groupedStoreVocabs: [String: [Vocabulary]] {
        Dictionary(grouping: storeVocabs, by: { 
            if let topic = $0.topics, !topic.trimmingCharacters(in: .whitespaces).isEmpty {
                return topic.trimmingCharacters(in: .whitespaces)
            }
            return "Chủ đề chung"
        })
    }
    
    var sortedTopics: [String] {
        groupedStoreVocabs.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    headerView
                    
                    // Streak Section
                    streakCard
                    
                    // Activity Calendar Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Lịch học tập")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                                }
                            }) {
                                Image(systemName: "chevron.left")
                            }
                            Text(monthYearString(selectedMonth))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(width: 120)
                            Button(action: {
                                withAnimation {
                                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                                }
                            }) {
                                Image(systemName: "chevron.right")
                            }
                        }
                        
                        CustomMonthCalendar(month: selectedMonth, activityLogs: activityLogs)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                    
                    // Explore Vocabulary Section (Wrapped in card)
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Khám Phá Từ Vựng")
                                .font(.title2)
                                .bold()
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if storeVocabs.isEmpty {
                            VStack {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .padding()
                                Text("Hiện chưa có bộ từ vựng hệ thống nào.")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVStack(spacing: 15) {
                                ForEach(sortedTopics, id: \.self) { topic in
                                    topicRow(topic: topic)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Components
    
    var headerView: some View {
        HStack {
            Image("AppLogo") // Using the requested logo file name
                .resizable()
                .scaledToFit()
                .frame(height: 50)
            
            Spacer()
            
            NavigationLink(destination: NotificationView()) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                    
                    if hasUnreadNotifications {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 8, y: -8)
                    }
                }
                .padding(12)
                .background(Circle().fill(Color(UIColor.secondarySystemGroupedBackground)))
                .shadow(color: Color.black.opacity(0.05), radius: 5)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var streakCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(streakCount > 0 ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(streakCount > 0 ? .orange : .gray)
                    .shadow(color: streakCount > 0 ? .orange.opacity(0.5) : .clear, radius: 10)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Chuỗi học tập")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streakCount)")
                        .font(.system(size: 40, weight: .bold))
                    Text("ngày")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                if streakCount > 0 {
                    Text("Tuyệt vời! Hãy tiếp tục nhé.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Bắt đầu học để tạo chuỗi nhé!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    func topicRow(topic: String) -> some View {
        let topicVocabs = groupedStoreVocabs[topic] ?? []
        let myCatalogIdsInTopic = myCatalogIdsByTopic[topic] ?? []
        let missingVocabs = topicVocabs.filter { adminVocab in
            guard let catalogId = adminVocab.catalog_id ?? adminVocab.id else { return false }
            return !myCatalogIdsInTopic.contains(catalogId)
        }
        
        let hasDownloadedSome = !myCatalogIdsInTopic.isEmpty
        let isFullyDownloaded = hasDownloadedSome && missingVocabs.isEmpty
        let needsUpdate = hasDownloadedSome && !missingVocabs.isEmpty
        
        let uniqueTopicVocabsCount = Set(topicVocabs.compactMap { $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() }).count
        let uniqueMissingVocabsCount = Set(missingVocabs.compactMap { $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() }).count
        
        NavigationLink(destination: TopicPreviewView(
            topicName: topic, 
            vocabs: topicVocabs, 
            missingVocabs: missingVocabs,
            isFullyDownloaded: isFullyDownloaded,
            needsUpdate: needsUpdate,
            onDownload: {
                Task { await downloadTopic(missingVocabs, topicName: topic) }
            },
            isDownloading: $isDownloading
        )) {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(uniqueTopicVocabsCount) từ vựng")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                statusBadge(isFullyDownloaded: isFullyDownloaded, needsUpdate: needsUpdate, missingCount: uniqueMissingVocabsCount)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
        }
    }
    
    @ViewBuilder
    func statusBadge(isFullyDownloaded: Bool, needsUpdate: Bool, missingCount: Int) -> some View {
        if isFullyDownloaded {
            Text("Đã tải")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.green.opacity(0.1)))
        } else if needsUpdate {
            Text("+\(missingCount)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.1)))
        } else {
            Text("Mới")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
        }
    }
    
    // MARK: - Logic
    
    func loadData() async {
        isLoading = true
        async let fetchStore: () = fetchStoreVocabs()
        async let fetchMy: () = fetchMyTopics()
        async let fetchStats: () = fetchUserStats()
        async let fetchNotif: () = fetchNotifications()
        
        _ = await (fetchStore, fetchMy, fetchStats, fetchNotif)
        isLoading = false
    }
    
    func fetchStoreVocabs() async {
        do {
            let fetched = try await VocabularyRepository.fetchSystemVocabs(adminUserId: adminUserId)
            
            DispatchQueue.main.async { self.storeVocabs = fetched }
        } catch {
            print("Lỗi lấy dữ liệu cửa hàng: \(error)")
        }
    }
    
    func fetchMyTopics() async {
        guard let myUserId = AuthManager.shared.currentUser?.id.uuidString else { return }
        do {
            let fetched = try await VocabularyRepository.fetchUserVocabs(userId: myUserId)
            
            var dict: [String: Set<String>] = [:]
            for v in fetched {
                if let topic = v.topics?.trimmingCharacters(in: .whitespaces), !topic.isEmpty {
                    if let catalogId = v.catalog_id {
                        dict[topic, default: []].insert(catalogId)
                    }
                }
            }
            DispatchQueue.main.async {
                self.myVocabs = fetched
                self.myCatalogIdsByTopic = dict
            }
        } catch {
            print("Lỗi lấy my topics: \(error)")
        }
    }
    
    func fetchUserStats() async {
        guard let myUserId = AuthManager.shared.currentUser?.id.uuidString else { return }
        do {
            // Fetch Streak from Supabase
            let stats = try await UserProgressRepository.fetchStats(userId: myUserId)
            
            if var currentStats = stats.first {
                // Check if streak is broken
                let now = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let lastDateStr = currentStats.last_learning_date, let lastDate = formatter.date(from: lastDateStr) {
                    let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastDate), to: Calendar.current.startOfDay(for: now)).day ?? 0
                    if diff > 1 {
                        currentStats.streak_count = 0
                        try await UserProgressRepository.resetStreak(userId: myUserId)
                    }
                }
                DispatchQueue.main.async { self.streakCount = currentStats.streak_count }
            }
            
            // Fetch Activity Logs from Supabase
            let logs = try await UserProgressRepository.fetchCompletedActivityLogs(userId: myUserId)
            
            var dict: [String: Bool] = [:]
            for log in logs { dict[log.date] = log.completed }
            DispatchQueue.main.async { self.activityLogs = dict }
            
        } catch {
            print("Lỗi lấy stats từ Supabase: \(error)")
        }
    }
    
    func fetchNotifications() async {
        guard let myUserId = AuthManager.shared.currentUser?.id.uuidString else { return }
        do {
            let unreadCount = try await NotificationRepository.fetchUnreadCount(userId: myUserId)
            
            DispatchQueue.main.async { self.hasUnreadNotifications = unreadCount > 0 }
        } catch {
            print("Lỗi check thông báo: \(error)")
        }
    }
    
    func downloadTopic(_ vocabsToDownload: [Vocabulary], topicName: String) async {
        guard let myUserId = AuthManager.shared.currentUser?.id.uuidString else {
            alertMessage = "Vui lòng đăng nhập!"
            showAlert = true
            return
        }
        
        DispatchQueue.main.async { isDownloading = true }
        
        let myNewVocabs = vocabsToDownload.map { v -> Vocabulary in
            var newVocab = v
            newVocab.user_id = myUserId
            newVocab.created_at = nil
            return newVocab
        }
        
        do {
            try await VocabularyRepository.insert(myNewVocabs)
            
            DispatchQueue.main.async {
                isDownloading = false
                let newCatalogIds = myNewVocabs.compactMap { $0.catalog_id ?? $0.id }
                myCatalogIdsByTopic[topicName, default: []].formUnion(newCatalogIds)
                let uniqueWordCount = Set(myNewVocabs.compactMap { $0.normalizedWord }).count
                alertMessage = "Tải thành công \(uniqueWordCount) từ!"
                showAlert = true
            }
        } catch {
            DispatchQueue.main.async {
                isDownloading = false
                alertMessage = "Lỗi: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // MARK: - Helpers
    
    func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
