import SwiftUI
import Supabase
import Charts

struct LearningView: View {
    @State private var isLoading = true
    
    @State private var learningVocabGroups: [[Vocabulary]] = []
    @State private var tasks: [LearningTask] = []
    
    @State private var totalLearningWords = 0
    @State private var totalSavedWords = 0
    @State private var dueVocabsCount = 0
    @State private var masterDueVocabsCount = 0
    
    @State private var showLearningSession = false
    @State private var showPronunciationSession = false
    @State private var statsByLevel: [Int: Int] = [1:0, 2:0, 3:0, 4:0, 5:0, 6:0]
    @State private var masterTasks: [PronunciationTask] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Đang tải dữ liệu...")
                } else {
                    dashboardView()
                }
            }
            .navigationTitle("Học từ vựng")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task { await prepareSession() }
            }
            .fullScreenCover(isPresented: $showLearningSession) {
                LearningSessionView(
                    tasks: tasks,
                    learningVocabGroups: learningVocabGroups,
                    onClose: {
                        showLearningSession = false
                        Task { await prepareSession() }
                    }
                )
            }
            .fullScreenCover(isPresented: $showPronunciationSession) {
                PronunciationSessionView(
                    tasks: masterTasks,
                    onClose: {
                        showPronunciationSession = false
                        Task { await prepareSession() }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    func dashboardView() -> some View {
        ScrollView {
            VStack(spacing: 25) {
                // Progress Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tiến độ học tập")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(totalLearningWords)")
                                    .font(.system(size: 34, weight: .bold))
                                Text("/ \(totalSavedWords)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("từ")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        Chart {
                            ForEach(1...6, id: \.self) { level in
                                SectorMark(
                                    angle: .value("Số từ", statsByLevel[level] ?? 0),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(colorForLevel(level))
                                .cornerRadius(4)
                            }
                        }
                        .frame(width: 80, height: 80)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Phân bổ cấp độ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Chart {
                            ForEach(1...6, id: \.self) { level in
                                BarMark(
                                    x: .value("Cấp độ", level == 6 ? "Master" : "Cấp \(level)"),
                                    y: .value("Số từ", statsByLevel[level] ?? 0)
                                )
                                .foregroundStyle(colorForLevel(level))
                                .cornerRadius(6)
                                .annotation(position: .top) {
                                    let count = statsByLevel[level] ?? 0
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 150)
                        .chartLegend(.hidden)
                        .chartYAxis(.hidden)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                )
                .padding(.horizontal)
                
                // Review Section
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Cần ôn tập hôm nay")
                                .font(.headline)
                            
                            Text(dueVocabsCount > 0 ? "Bạn có \(dueVocabsCount) từ vựng đến hạn ôn tập." : "Tuyệt vời! Bạn đã hoàn thành hết các từ cần ôn.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 30))
                            .foregroundColor(dueVocabsCount > 0 ? .orange : .green)
                    }
                    
                    if dueVocabsCount > 0 {
                        Button(action: {
                            showLearningSession = true
                        }) {
                            HStack {
                                Text("Ôn tập ngay")
                                    .bold()
                                Image(systemName: "arrow.right")
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    } else {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Hoàn thành mục tiêu!")
                                .bold()
                        }
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(18)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Kiểm tra Phát âm Master")
                                .font(.headline)
                            
                            Text(masterDueVocabsCount > 0 ? "Bạn có \(masterDueVocabsCount) từ Master hiện có để luyện tập." : "Không có từ Master nào cần kiểm tra lúc này.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(masterDueVocabsCount > 0 ? .purple : .green)
                    }
                    
                    if masterDueVocabsCount > 0 {
                        Button(action: {
                            showPronunciationSession = true
                        }) {
                            HStack {
                                Text("Luyện tập Master")
                                    .bold()
                                Image(systemName: "star.fill")
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.purple, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    } else {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Hoàn thành mục tiêu!")
                                .bold()
                        }
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(18)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
    
    func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1: return .red.opacity(0.7)
        case 2: return .orange.opacity(0.7)
        case 3: return .yellow.opacity(0.7)
        case 4: return .green.opacity(0.7)
        case 5: return .blue.opacity(0.7)
        case 6: return .purple.opacity(0.7)
        default: return .gray
        }
    }
    
    func prepareSession() async {
        isLoading = true
        do {
            guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
            
            let allResponse: [Vocabulary] = try await supabase
                .from("vocab_list")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let allGrouped = Dictionary(grouping: allResponse, by: { $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() ?? "unknown" })
            
            var allJoinedMeanings = allGrouped.values.compactMap { group -> String? in
                let ms = group.compactMap { $0.V_meaning }.filter { !$0.isEmpty }
                return ms.isEmpty ? nil : ms.joined(separator: " / ")
            }
            allJoinedMeanings = Array(Set(allJoinedMeanings))
            
            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter2 = ISO8601DateFormatter()
            
            var dueGroups: [[Vocabulary]] = []
            var masterDueGroups: [[Vocabulary]] = []
            var tempStats = [1:0, 2:0, 3:0, 4:0, 5:0, 6:0]
            var totalCount = 0
            
            for (_, group) in allGrouped {
                let isLearning = group.contains { ($0.learning_level ?? 0) > 0 }
                if isLearning {
                    totalCount += 1
                    let lvl = group.first(where: { ($0.learning_level ?? 0) > 0 })?.learning_level ?? 1
                    tempStats[lvl, default: 0] += 1
                    
                    let isDue = group.contains { vocab in
                        guard let lvl = vocab.learning_level, lvl > 0 else { return false }
                        guard let nextStr = vocab.next_review else { return true }
                        if let date = formatter.date(from: nextStr) ?? formatter2.date(from: nextStr) {
                            return date <= now
                        }
                        return true
                    }
                    
                    let hasPassed = (group.first(where: { ($0.learning_level ?? 0) > 0 })?.pronunciation_score ?? 0) >= 70
                    
                    if lvl == 6 && !hasPassed {
                        masterDueGroups.append(group)
                    } else if lvl < 6 && isDue {
                        dueGroups.append(group)
                    }
                }
            }
            
            let dueCount = dueGroups.count
            let masterDueCount = masterDueGroups.count

            DispatchQueue.main.async {
                self.statsByLevel = tempStats
                self.totalLearningWords = totalCount
                self.totalSavedWords = allGrouped.count
                self.dueVocabsCount = dueCount
                self.masterDueVocabsCount = masterDueCount
            }
            
            dueGroups.shuffle()
            let selectedGroups = Array(dueGroups.prefix(7))
            
            var newTasks: [LearningTask] = []
            for group in selectedGroups {
                guard let word = group.first?.vocab else { continue }
                
                newTasks.append(LearningTask(word: word, meanings: group, type: .listenAndType))
                newTasks.append(LearningTask(word: word, meanings: group, type: .meaningAndType))
                
                let correctMeaning = group.compactMap { $0.V_meaning }.filter { !$0.isEmpty }.joined(separator: " / ")
                var options = [correctMeaning.isEmpty ? "Không có nghĩa" : correctMeaning]
                
                let distractors = allJoinedMeanings.filter { $0 != options[0] }.shuffled()
                options.append(contentsOf: distractors.prefix(3))
                while options.count < 4 {
                    options.append("Nghĩa giả định \(UUID().uuidString.prefix(4))")
                }
                options.shuffle()
                
                newTasks.append(LearningTask(word: word, meanings: group, type: .multipleChoice, options: options))
                
                for m in group {
                    if let example = m.E_example, !example.isEmpty {
                        let cleanedExample = example.replacingOccurrences(of: "[.,!?;:]", with: "", options: .regularExpression)
                        let words = cleanedExample.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                        
                        if words.count >= 3 {
                            newTasks.append(LearningTask(
                                word: word,
                                meanings: group,
                                type: .sentenceScramble,
                                correctSentence: example,
                                scrambledWords: words.shuffled(),
                                vHint: m.V_example
                            ))
                        }
                    }
                }
            }
            
            masterDueGroups.shuffle()
            let selectedMasterGroups = Array(masterDueGroups.prefix(7))
            var newMasterTasks: [PronunciationTask] = []
            for group in selectedMasterGroups {
                guard let word = group.first?.vocab else { continue }
                if let meaningWithExample = group.first(where: { $0.E_example != nil && !$0.E_example!.isEmpty }), let example = meaningWithExample.E_example {
                    newMasterTasks.append(PronunciationTask(word: word, targetText: example, meaning: meaningWithExample))
                } else {
                    newMasterTasks.append(PronunciationTask(word: word, targetText: word, meaning: group.first!))
                }
            }
            
            DispatchQueue.main.async {
                self.learningVocabGroups = selectedGroups
                self.tasks = newTasks.shuffled()
                self.masterTasks = newMasterTasks
                self.isLoading = false
            }
            
        } catch {
            print("Lỗi tải bài học: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}
