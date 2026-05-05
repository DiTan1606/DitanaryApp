import SwiftUI
import Supabase
import Charts
import Speech
import AVFoundation

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
            
            DispatchQueue.main.async {
                self.statsByLevel = tempStats
                self.totalLearningWords = totalCount
                self.totalSavedWords = allGrouped.count
                self.dueVocabsCount = dueGroups.count
                self.masterDueVocabsCount = masterDueGroups.count
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

struct LearningSessionView: View {
    @State var tasks: [LearningTask]
    let learningVocabGroups: [[Vocabulary]]
    let onClose: () -> Void
    
    @State private var currentTaskIndex = 0
    @State private var isCompleted = false
    
    @State private var inputText = ""
    @State private var currentResult: TaskResult? = nil
    
    // Scramble logic state
    @State private var selectedScrambleWords: [String] = []
    @State private var availableScrambleWords: [String] = []
    @State private var shouldRetryCurrentTask = false
    
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
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            questionView(for: task)
                                .padding(.top)
                            
                            inputArea(for: task)
                        }
                        .padding(.bottom, 30)
                    }
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
                initializeTaskState()
                if let first = tasks.first, first.type == .listenAndType {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        SpeechManager.shared.speak(word: first.word, ipa: first.meanings.first?.IPA)
                    }
                }
            }
            .onChange(of: currentTaskIndex) { oldValue, newValue in
                initializeTaskState()
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
                
            case .sentenceScramble:
                VStack(spacing: 15) {
                    Text("Ghép các từ để hoàn thiện câu:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let hint = task.vHint, !hint.isEmpty {
                        Text(hint)
                            .font(.headline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.orange.opacity(0.1)))
                    } else {
                        let meanings = task.meanings.compactMap { $0.V_meaning }.joined(separator: ", ")
                        Text(meanings)
                            .font(.headline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.orange.opacity(0.1)))
                    }
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
            } else if task.type == .sentenceScramble {
                VStack(spacing: 25) {
                    // Built sentence
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Câu của bạn:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Spacer()
                            if !selectedScrambleWords.isEmpty {
                                Button(action: {
                                    availableScrambleWords.append(contentsOf: selectedScrambleWords)
                                    selectedScrambleWords.removeAll()
                                }) {
                                    Text("Xóa hết")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1.5)
                                )
                            
                            ScrollView {
                                FlowLayout(spacing: 10) {
                                    ForEach(Array(selectedScrambleWords.enumerated()), id: \.offset) { index, word in
                                        Button(action: {
                                            let removed = selectedScrambleWords.remove(at: index)
                                            availableScrambleWords.append(removed)
                                        }) {
                                            Text(word)
                                                .font(.body)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                                .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                                        }
                                    }
                                }
                                .padding(15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250) // Tăng lên 250 theo ý ông
                    }
                    
                    // Available words
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Từ gợi ý:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 10) {
                            ForEach(Array(availableScrambleWords.enumerated()), id: \.offset) { index, word in
                                Button(action: {
                                    selectedScrambleWords.append(word)
                                    availableScrambleWords.remove(at: index)
                                }) {
                                    Text(word)
                                        .font(.body)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .foregroundColor(.primary)
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(4)
                    }
                    
                    Button("Kiểm tra") {
                        checkAnswer(for: task)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedScrambleWords.isEmpty)
                    .padding(.top)
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
                } else if task.type == .sentenceScramble {
                    let correct = task.correctSentence?.replacingOccurrences(of: "[.,!?;:]", with: "", options: .regularExpression).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    Text("Debug: Bạn ghép '\(result.answerText)' - Đáp án: '\(correct)'")
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
        } else if task.type == .sentenceScramble {
            let built = selectedScrambleWords.joined(separator: " ").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let correct = task.correctSentence?.replacingOccurrences(of: "[.,!?;:]", with: "", options: .regularExpression).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            isCorrect = (built == correct)
            answer = built
        } else {
            answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isCorrect = (answer == actualWord)
        }
        
        // Mark for retry if incorrect
        shouldRetryCurrentTask = !isCorrect
        
        currentResult = TaskResult(
            task: task,
            isCorrect: isCorrect,
            selectedOption: selected,
            answerText: answer
        )
    }
    
    func nextTask() {
        if shouldRetryCurrentTask {
            if let current = currentTask {
                var retryTask = current
                if retryTask.type == .multipleChoice { retryTask.options.shuffle() }
                if retryTask.type == .sentenceScramble { retryTask.scrambledWords.shuffle() }
                tasks.append(retryTask)
            }
        }
        
        shouldRetryCurrentTask = false
        
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
    
    func initializeTaskState() {
        inputText = ""
        if let task = currentTask, task.type == .sentenceScramble {
            availableScrambleWords = task.scrambledWords
            selectedScrambleWords = []
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
                if newLvl > 6 { newLvl = 6 }
                
                var addDays = 0
                switch newLvl {
                case 1: addDays = 0
                case 2: addDays = 1
                case 3: addDays = 3
                case 4: addDays = 7
                case 5: addDays = 15
                case 6: addDays = 0 // Học phát âm ngay khi lên master
                default: addDays = 0
                }
                
                let nextDate = Calendar.current.date(byAdding: .day, value: addDays, to: now) ?? now
                let nextStr = formatter.string(from: nextDate)
                
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = layout(proposal: proposal, subviews: subviews, bounds: bounds)
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews, bounds: CGRect? = nil) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = bounds?.minX ?? 0
        var currentY: CGFloat = bounds?.minY ?? 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > (bounds?.minX ?? 0) {
                currentX = bounds?.minX ?? 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            if let _ = bounds {
                subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

struct PronunciationTask: Identifiable {
    let id = UUID()
    let word: String
    let targetText: String
    let meaning: Vocabulary
}

struct PronunciationSessionView: View {
    @State var tasks: [PronunciationTask]
    let onClose: () -> Void
    
    @StateObject private var pronunciationManager = PronunciationManager()
    
    @State private var currentTaskIndex = 0
    @State private var isCompleted = false
    
    @State private var scoreResult: PronunciationScore? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    
    var currentTask: PronunciationTask? {
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
                        Image(systemName: "star.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                        Text("Chúc mừng bạn đã hoàn thành bài tập Master!")
                            .font(.title2)
                            .bold()
                        
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
                    
                    ScrollView {
                        VStack(spacing: 30) {
                            Text("Đọc câu sau:")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(task.targetText)
                                    .font(.system(size: 28, weight: .bold))
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    pronunciationManager.speakTargetText(text: task.targetText)
                                }) {
                                    Image(systemName: pronunciationManager.isSpeakingTarget ? "speaker.wave.3.fill" : "speaker.wave.2")
                                        .font(.title)
                                        .foregroundColor(pronunciationManager.isSpeakingTarget ? .blue : .gray)
                                }
                                .padding(.leading, 10)
                            }
                            .padding()
                            
                            if pronunciationManager.hasRecorded {
                                VStack(spacing: 15) {
                                    Text("Bạn đọc: " + (pronunciationManager.transcribedText.isEmpty ? "(Chưa nghe rõ)" : pronunciationManager.transcribedText))
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .italic()
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                    
                                    Button(action: {
                                        if pronunciationManager.isPlaying {
                                            pronunciationManager.stopPlayback()
                                        } else {
                                            pronunciationManager.playRecordedAudio()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: pronunciationManager.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                            Text(pronunciationManager.isPlaying ? "Dừng nghe" : "Nghe lại giọng của bạn")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(pronunciationManager.isPlaying ? Color.red : Color.orange)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            
                            if let score = scoreResult {
                                VStack(spacing: 15) {
                                    Text("Kết quả từ AI")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 20) {
                                        ScoreCircle(title: "Tổng", score: score.finalScore, color: .purple)
                                        ScoreCircle(title: "Khớp chữ", score: score.sequenceScore, color: .blue)
                                        ScoreCircle(title: "Phát âm", score: score.confidenceScore, color: .green)
                                    }
                                    .padding(.vertical, 10)
                                    
                                    if score.finalScore >= 70 {
                                        Text("Tuyệt vời! Bạn đã đạt yêu cầu.")
                                            .foregroundColor(.green)
                                            .bold()
                                        Button("Tiếp tục") {
                                            nextTask()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                    } else {
                                        Text("Phát âm chưa tốt. Hãy thử lại nhé!")
                                            .foregroundColor(.red)
                                        Button("Thử lại") {
                                            self.scoreResult = nil
                                            pronunciationManager.resetRecordingState()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 15).fill(Color(UIColor.secondarySystemGroupedBackground)))
                            } else {
                                // Buttons for recording & submitting
                                if !pronunciationManager.hasRecorded {
                                    Button(action: {
                                        toggleRecording(task: task)
                                    }) {
                                        Image(systemName: pronunciationManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(pronunciationManager.isRecording ? .red : .purple)
                                    }
                                    .padding()
                                    
                                    Text(pronunciationManager.isRecording ? "Đang thu âm... Bấm để dừng" : "Bấm để thu âm")
                                        .foregroundColor(.secondary)
                                } else {
                                    HStack(spacing: 20) {
                                        Button(action: {
                                            pronunciationManager.resetRecordingState()
                                        }) {
                                            Text("Thu âm lại")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.gray)
                                                .cornerRadius(10)
                                        }
                                        
                                        Button(action: {
                                            submitRecording(task: task)
                                        }) {
                                            Text("Nộp bài")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.green)
                                                .cornerRadius(10)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("Không có bài tập nào.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Master Phát âm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Thoát") {
                        onClose()
                    }
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Lỗi"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func toggleRecording(task: PronunciationTask) {
        if pronunciationManager.isRecording {
            pronunciationManager.stopRecording()
        } else {
            do {
                try pronunciationManager.startRecording()
                self.scoreResult = nil
            } catch {
                errorMessage = "Không thể bắt đầu thu âm: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func submitRecording(task: PronunciationTask) {
        if pronunciationManager.isPlaying {
            pronunciationManager.stopPlayback()
        }
        let score = pronunciationManager.calculateSimilarity(target: task.targetText, input: pronunciationManager.transcribedText)
        self.scoreResult = score
        
        // Lưu điểm số cao nhất lên Supabase
        guard let id = task.meaning.id else { return }
        
        let currentBestScore = task.meaning.pronunciation_score ?? 0
        let newScore = Int(score.finalScore)
        
        if newScore > currentBestScore {
            Task {
                do {
                    try await supabase
                        .from("vocab_list")
                        .update(UpdatePronunciationScore(pronunciation_score: newScore))
                        .eq("ID", value: id)
                        .execute()
                } catch {
                    print("Lỗi lưu điểm phát âm cho \(task.word): \(error)")
                }
            }
        }
    }
    
    func nextTask() {
        scoreResult = nil
        pronunciationManager.resetRecordingState()
        currentTaskIndex += 1
        
        if currentTaskIndex >= tasks.count {
            Task { await finishMasterSession() }
        }
    }
    
    func finishMasterSession() async {
        isCompleted = true
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nextDate = Calendar.current.date(byAdding: .year, value: 100, to: now) ?? now
        let nextStr = formatter.string(from: nextDate)
        
        for task in tasks {
            guard let id = task.meaning.id else { continue }
            do {
                try await supabase
                    .from("vocab_list")
                    .update(UpdateLearningData(learning_level: 6, next_review: nextStr))
                    .eq("ID", value: id)
                    .execute()
            } catch {
                print("Lỗi update master review cho \(task.word): \(error)")
            }
        }
    }
}

struct PronunciationScore {
    let finalScore: Double
    let sequenceScore: Double
    let confidenceScore: Double
}

class PronunciationManager: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // For playback
    private var audioFile: AVAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isRecording = false
    @Published var hasRecorded = false
    @Published var transcribedText = ""
    @Published var currentTranscription: SFTranscription? = nil
    @Published var permissionGranted = false
    @Published var isPlaying = false
    @Published var isSpeakingTarget = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.permissionGranted = true
                default:
                    self.permissionGranted = false
                }
            }
        }
    }
    
    func resetRecordingState() {
        transcribedText = ""
        currentTranscription = nil
        hasRecorded = false
        isRecording = false
        isPlaying = false
        stopPlayback()
    }
    
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("user_recording.wav")
    }
    
    func startRecording() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        resetRecordingState()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Prepare to save audio for playback
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)
        } catch {
            print("Failed to create audio file for recording: \(error)")
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.currentTranscription = result.bestTranscription
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.audioFile = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.hasRecorded = true
                }
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("Failed to write audio buffer: \(error)")
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        hasRecorded = true
    }
    
    // MARK: - Playback
    func playRecordedAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        } catch {
            print("Error playing recorded audio: \(error)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    // MARK: - Text to Speech
    func speakTargetText(text: String) {
        if isSpeakingTarget {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeakingTarget = false
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.4 // Chậm hơn bình thường một chút (Mặc định 0.5)
            
            synthesizer.speak(utterance)
        } catch {
            print("TTS setup error: \(error)")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeakingTarget = true }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeakingTarget = false }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeakingTarget = false }
    }
    
    // MARK: - Scoring
    func calculateSimilarity(target: String, input: String) -> PronunciationScore {
        let targetWords = target.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let inputWords = input.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        guard !targetWords.isEmpty else { return PronunciationScore(finalScore: 0, sequenceScore: 0, confidenceScore: 0) }
        if inputWords.isEmpty { return PronunciationScore(finalScore: 0, sequenceScore: 0, confidenceScore: 0) }
        
        let empty = [Int](repeating: 0, count: inputWords.count + 1)
        var last = [Int](0...inputWords.count)
        
        for (i, tWord) in targetWords.enumerated() {
            var current = [i + 1] + empty.dropFirst()
            for (j, iWord) in inputWords.enumerated() {
                if tWord == iWord {
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
        let sequenceScore = max(0.0, sequenceScoreRaw * 100.0)
        
        var averageConfidence = 1.0
        if let transcription = currentTranscription, !transcription.segments.isEmpty {
            let confidences = transcription.segments.map { Double($0.confidence) }
            let validConfidences = confidences.filter { $0 > 0.0 }
            if !validConfidences.isEmpty {
                averageConfidence = validConfidences.reduce(0.0, +) / Double(validConfidences.count)
            }
        }
        let confidenceScore = averageConfidence * 100.0
        
        let finalScore = max(0.0, sequenceScoreRaw * averageConfidence * 100.0)
        
        return PronunciationScore(finalScore: finalScore, sequenceScore: sequenceScore, confidenceScore: confidenceScore)
    }
}

struct ScoreCircle: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0.0, to: CGFloat(score / 100.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score))")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 50, height: 50)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
