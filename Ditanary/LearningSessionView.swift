import SwiftUI

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
                    Text("Bạn chọn: \(result.selectedOption ?? ""). Đáp án đúng: \(expected)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if task.type == .sentenceScramble {
                    Text("Câu đúng: \(task.correctSentence ?? "")")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Bạn nhập: \(result.answerText). Đáp án đúng: \(task.word)")
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
                
                let newLvl = ReviewScheduler.nextLearningLevel(from: vocab.learning_level ?? 0)
                let nextStr = ReviewScheduler.reviewString(for: newLvl, from: now, formatter: formatter)
                
                do {
                    try await VocabularyRepository.updateLearningData(id: id, learningLevel: newLvl, nextReview: nextStr)
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
        
        do {
            try await UserProgressRepository.recordDailyActivityAndUpdateStreak(userId: myUserId)
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
