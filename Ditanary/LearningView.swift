import SwiftUI
import Supabase
import Charts

enum QuestionType {
    case listenAndType
    case meaningAndType
    case multipleChoice
}

struct LearningTask: Identifiable {
    let id = UUID()
    let word: String
    let meanings: [Vocabulary]
    let type: QuestionType
    var options: [String] = []
}

struct TaskResult: Identifiable {
    let id = UUID()
    let task: LearningTask
    let isCorrect: Bool
    let selectedOption: String?
    let answerText: String
}

struct LearningView: View {
    @State private var isLoading = true
    
    @State private var learningVocabGroups: [[Vocabulary]] = []
    @State private var tasks: [LearningTask] = []
    
    @State private var totalLearningWords = 0
    @State private var totalSavedWords = 0
    @State private var dueVocabsCount = 0
    
    @State private var showLearningSession = false
    @State private var statsByLevel: [Int: Int] = [1:0, 2:0, 3:0, 4:0, 5:0]
    
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
                            ForEach(1...5, id: \.self) { level in
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
                            ForEach(1...5, id: \.self) { level in
                                BarMark(
                                    x: .value("Cấp độ", "Cấp \(level)"),
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
            var tempStats = [1:0, 2:0, 3:0, 4:0, 5:0]
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
                    if isDue {
                        dueGroups.append(group)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.statsByLevel = tempStats
                self.totalLearningWords = totalCount
                self.totalSavedWords = allGrouped.count
                self.dueVocabsCount = dueGroups.count
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
                
                var distractors = allJoinedMeanings.filter { $0 != options[0] }.shuffled()
                options.append(contentsOf: distractors.prefix(3))
                while options.count < 4 {
                    options.append("Nghĩa giả định \(UUID().uuidString.prefix(4))")
                }
                options.shuffle()
                
                newTasks.append(LearningTask(word: word, meanings: group, type: .multipleChoice, options: options))
            }
            
            DispatchQueue.main.async {
                self.learningVocabGroups = selectedGroups
                self.tasks = newTasks.shuffled()
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

struct LearningSessionView: View {
    @State var tasks: [LearningTask]
    let learningVocabGroups: [[Vocabulary]]
    let onClose: () -> Void
    
    @State private var currentTaskIndex = 0
    @State private var isCompleted = false
    
    @State private var inputText = ""
    @State private var currentResult: TaskResult? = nil
    
    var currentTask: LearningTask? {
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }
    
    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(currentTaskIndex) / Double(tasks.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isCompleted {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        Text("Chúc mừng bạn đã hoàn thành bài học!")
                            .font(.title2)
                            .bold()
                        Text("Bạn đã ôn tập \(learningVocabGroups.count) từ vựng.")
                            .foregroundColor(.secondary)
                        
                        Button("Quay về") {
                            onClose()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                } else if let task = currentTask {
                    ProgressView(value: progress)
                        .padding()
                        .tint(.blue)
                    
                    Text("Câu \(currentTaskIndex + 1) / \(tasks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    questionView(for: task)
                    
                    Spacer()
                    
                    inputArea(for: task)
                }
            }
            .navigationTitle("Đang học")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Thoát") {
                        onClose()
                    }
                }
            }
            .onAppear {
                if let first = tasks.first, first.type == .listenAndType {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        SpeechManager.shared.speak(word: first.word, ipa: first.meanings.first?.IPA)
                    }
                }
            }
            .sheet(item: $currentResult, onDismiss: {
                nextTask()
            }) { result in
                resultView(for: result)
                    .presentationDetents([.fraction(1.0), .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    @ViewBuilder
    func questionView(for task: LearningTask) -> some View {
        VStack(spacing: 20) {
            switch task.type {
            case .listenAndType:
                Button(action: {
                    SpeechManager.shared.speak(word: task.word, ipa: task.meanings.first?.IPA)
                }) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                Text("Nghe và viết lại từ đúng")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            case .meaningAndType:
                VStack(spacing: 15) {
                    Text("Viết từ vựng có các nghĩa sau:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(task.meanings.enumerated()), id: \.element.id) { index, meaning in
                        HStack(alignment: .top, spacing: 10) {
                            let form = meaning.word_form ?? ""
                            let eMeaning = meaning.E_meaning ?? ""
                            
                            if !form.isEmpty {
                                Text(form)
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if !eMeaning.isEmpty {
                                    Text(eMeaning)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                
                                if let vMeaning = meaning.V_meaning, !vMeaning.isEmpty {
                                    Text(vMeaning)
                                        .font(.body)
                                        .bold()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.gray.opacity(0.1)))
                
            case .multipleChoice:
                VStack(spacing: 15) {
                    Text("Chọn nghĩa Tiếng Việt đúng cho từ:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(task.word)
                        .font(.largeTitle)
                        .bold()
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    func inputArea(for task: LearningTask) -> some View {
        VStack {
            if task.type == .multipleChoice {
                ForEach(task.options, id: \.self) { option in
                    Button(action: {
                        checkAnswer(for: task, selected: option)
                    }) {
                        Text(option)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                            .foregroundColor(.primary)
                    }
                }
            } else {
                TextField("Nhập từ tiếng Anh...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit {
                        checkAnswer(for: task)
                    }
                
                Button("Kiểm tra") {
                    checkAnswer(for: task)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    func resultView(for result: TaskResult) -> some View {
        let task = result.task
        let isCorrect = result.isCorrect
        
        VStack(spacing: 15) {
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)
                Text(isCorrect ? "Chính xác!" : "Chưa đúng rồi!")
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)
            }
            
            if !isCorrect {
                if task.type == .multipleChoice {
                    let correctMeaning = task.meanings.compactMap { $0.V_meaning }.filter { !$0.isEmpty }.joined(separator: " / ")
                    let expected = correctMeaning.isEmpty ? "Không có nghĩa" : correctMeaning
                    Text("Debug: Bạn chọn '\(result.selectedOption ?? "")' - Đáp án: '\(expected)'")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    let actualWord = task.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    Text("Debug: Bạn nhập '\(result.answerText)' - Đáp án: '\(actualWord)'")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text(task.word).font(.title).bold()
                        Spacer()
                        Button(action: {
                            playAllAudios(for: task.word, meanings: task.meanings)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title)
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(Array(task.meanings.enumerated()), id: \.element.id) { index, meaning in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NGHĨA \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 10)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                if let form = meaning.word_form, !form.isEmpty {
                                    HStack {
                                        DetailRow(title: "Từ loại (Word form)", content: form, color: .purple)
                                        Spacer()
                                        Button(action: {
                                            SpeechManager.shared.speak(word: task.word, ipa: meaning.IPA)
                                        }) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                    }
                                }
                                if let ipa = meaning.IPA, !ipa.isEmpty {
                                    DetailRow(title: "Phát âm (IPA)", content: ipa, color: .blue)
                                }
                                if let cefr = meaning.CEFR, !cefr.isEmpty {
                                    DetailRow(title: "Cấp độ (CEFR)", content: cefr, color: .orange)
                                }
                                if let eMeaning = meaning.E_meaning, !eMeaning.isEmpty {
                                    DetailRow(title: "Nghĩa Tiếng Anh", content: eMeaning, onSpeak: {
                                        SpeechManager.shared.speak(word: eMeaning, ipa: nil)
                                    })
                                }
                                if let evMeaning = meaning.EV_meaning, !evMeaning.isEmpty {
                                    DetailRow(title: "Nghĩa Anh - Việt", content: evMeaning)
                                }
                                if let vMeaning = meaning.V_meaning, !vMeaning.isEmpty {
                                    DetailRow(title: "Nghĩa Tiếng Việt", content: vMeaning)
                                }
                                if let eExample = meaning.E_example, !eExample.isEmpty {
                                    DetailRow(title: "Ví dụ Tiếng Anh", content: eExample, isItalic: true, onSpeak: {
                                        SpeechManager.shared.speak(word: eExample, ipa: nil)
                                    })
                                }
                                if let vExample = meaning.V_example, !vExample.isEmpty {
                                    DetailRow(title: "Ví dụ Tiếng Việt", content: vExample)
                                }
                                if let family = meaning.word_family, !family.isEmpty {
                                    DetailRow(title: "Từ cùng họ (Word family)", content: family)
                                }
                                if let synonymous = meaning.synonymous, !synonymous.isEmpty {
                                    DetailRow(title: "Từ đồng nghĩa", content: synonymous)
                                }
                                if let antonym = meaning.antonym, !antonym.isEmpty {
                                    DetailRow(title: "Từ trái nghĩa", content: antonym)
                                }
                                if let bonus = meaning.bonus, !bonus.isEmpty {
                                    DetailRow(title: "Thông tin mở rộng", content: bonus)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Button("Tiếp tục") {
                currentResult = nil
            }
            .buttonStyle(.borderedProminent)
            .tint(isCorrect ? .green : .red)
        }
        .padding()
        .onAppear {
            playAllAudios(for: task.word, meanings: task.meanings)
        }
    }
    
    func playAllAudios(for word: String, meanings: [Vocabulary]) {
        var seenIPAs = Set<String>()
        var count = 0
        for m in meanings {
            let ipa = m.IPA ?? ""
            if !seenIPAs.contains(ipa) {
                seenIPAs.insert(ipa)
                SpeechManager.shared.speak(word: word, ipa: ipa, stopPrevious: count == 0)
                count += 1
            }
        }
    }
    
    func checkAnswer(for task: LearningTask, selected: String? = nil) {
        let actualWord = task.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var isCorrect = false
        var answer = ""
        
        if task.type == .multipleChoice {
            let correctMeaning = task.meanings.compactMap { $0.V_meaning }.filter { !$0.isEmpty }.joined(separator: " / ")
            let expected = correctMeaning.isEmpty ? "Không có nghĩa" : correctMeaning
            isCorrect = (selected == expected)
        } else {
            answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isCorrect = (answer == actualWord)
        }
        
        currentResult = TaskResult(
            task: task,
            isCorrect: isCorrect,
            selectedOption: selected,
            answerText: answer
        )
    }
    
    func nextTask() {
        if let result = currentResult, !result.isCorrect {
            if let current = currentTask {
                var retryTask = current
                if retryTask.type == .multipleChoice { retryTask.options.shuffle() }
                tasks.append(retryTask)
            }
        }
        
        inputText = ""
        currentResult = nil
        
        currentTaskIndex += 1
        
        if currentTaskIndex >= tasks.count {
            Task { await finishSession() }
        } else {
            if let next = currentTask, next.type == .listenAndType {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    SpeechManager.shared.speak(word: next.word, ipa: next.meanings.first?.IPA)
                }
            }
        }
    }
    
    func finishSession() async {
        isCompleted = true
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for group in learningVocabGroups {
            for vocab in group {
                guard let id = vocab.id else { continue }
                let currentLvl = vocab.learning_level ?? 0
                var newLvl = currentLvl + 1
                if newLvl > 5 { newLvl = 5 }
                
                var addDays = 0
                switch newLvl {
                case 1: addDays = 0
                case 2: addDays = 1
                case 3: addDays = 3
                case 4: addDays = 7
                case 5: addDays = 30
                default: addDays = 0
                }
                
                let nextDate = Calendar.current.date(byAdding: .day, value: addDays, to: now) ?? now
                let nextStr = formatter.string(from: nextDate)
                
                // Lên lịch thông báo ôn tập
                NotificationManager.shared.scheduleReviewNotification(for: vocab.vocab ?? "từ vựng", at: nextDate)
                
                do {
                    try await supabase
                        .from("vocab_list")
                        .update(UpdateLearningData(learning_level: newLvl, next_review: nextStr))
                        .eq("ID", value: id)
                        .execute()
                } catch {
                    print("Lỗi cập nhật level cho \(vocab.vocab ?? ""): \(error)")
                }
            }
        }
        
        // Record activity and update streak
        await recordActivity()
    }
    
    func recordActivity() async {
        guard let myUserId = AuthManager.shared.currentUser?.id.uuidString else { return }
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: now)
        
        do {
            // 1. Ghi nhận Activity Log vào Supabase
            // Sử dụng upsert để tránh trùng lặp nếu học nhiều lần trong ngày
            let log = ActivityLog(user_id: myUserId, date: dateStr, completed: true)
            try await supabase
                .from("activity_logs")
                .upsert(log)
                .execute()
            
            // 2. Cập nhật Streak trong Supabase
            let statsResponse: [UserStats] = try await supabase
                .from("user_stats")
                .select()
                .eq("user_id", value: myUserId)
                .execute()
                .value
            
            var stats = statsResponse.first ?? UserStats(user_id: myUserId, streak_count: 0, last_learning_date: nil)
            let calendar = Calendar.current
            
            if let lastDateStr = stats.last_learning_date, let lastDate = formatter.date(from: lastDateStr) {
                let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: now)).day ?? 0
                
                if diff == 1 {
                    stats.streak_count += 1
                } else if diff > 1 {
                    stats.streak_count = 1
                }
                // Nếu diff == 0 (học lần 2 trong ngày) thì không tăng streak
            } else {
                stats.streak_count = 1
            }
            
            stats.last_learning_date = dateStr
            
            // Lưu stats mới vào Supabase
            try await supabase
                .from("user_stats")
                .upsert(stats)
                .execute()
                
        } catch {
            print("Lỗi đồng bộ hoạt động với Supabase: \(error)")
        }
    }
    
    struct DetailRow: View {
        let title: String
        let content: String
        var color: Color = .primary
        var isItalic: Bool = false
        var onSpeak: (() -> Void)? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let onSpeak = onSpeak {
                    HStack(alignment: .top) {
                        Text(content)
                            .font(.body)
                            .foregroundColor(color)
                            .italic(isItalic)
                        Spacer()
                        Button(action: onSpeak) {
                            Image(systemName: "speaker.wave.2")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text(content)
                        .font(.body)
                        .foregroundColor(color)
                        .italic(isItalic)
                }
            }
            .padding(.bottom, 2)
        }
    }
}
