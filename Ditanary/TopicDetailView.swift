import SwiftUI

struct TopicDetailView: View {
    let topic: String
    var vocabs: [Vocabulary]
    var saveAsSystem: Bool = false
    var onRefresh: () -> Void
    
    @State private var selectedVocabForEdit: Vocabulary? = nil
    @State private var showingAddVocab = false
    
    var groupedByWord: [String: [Vocabulary]] {
        Dictionary(grouping: vocabs, by: { $0.vocab?.trimmingCharacters(in: .whitespaces) ?? "Unknown" })
    }
    
    var uniqueWords: [String] {
        groupedByWord.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    var body: some View {
        List {
            if vocabs.isEmpty {
                Text("Không có từ vựng nào trong chủ đề này.")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(uniqueWords, id: \.self) { word in
                    let meanings = groupedByWord[word] ?? []
                    let firstMeaning = meanings.first
                    
                    NavigationLink(destination: WordDetailView(word: word, meanings: meanings, saveAsSystem: saveAsSystem, onRefresh: onRefresh)) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(word)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                // Hiển thị tiến độ x/6
                                let level = meanings.first(where: { ($0.learning_level ?? 0) > 0 })?.learning_level ?? 0
                                if level >= 6 {
                                    Text("Master")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple)
                                        .cornerRadius(4)
                                        
                                    // Thêm phần hiển thị điểm phát âm
                                    if let score = pronunciationAverage(for: meanings) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 8))
                                            Text("\(score)/100")
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(score >= 70 ? .green : .orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((score >= 70 ? Color.green : Color.orange).opacity(0.2))
                                        .cornerRadius(4)
                                    }
                                } else {
                                    Text("\(level)/6")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(level == 0 ? .red : .orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((level == 0 ? Color.red : Color.yellow).opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                            }
                            
                            if let ipa = firstMeaning?.IPA, !ipa.isEmpty {
                                Text(ipa)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            // Nối các nghĩa Tiếng Việt lại
                            let vMeanings = Array(Set(meanings.compactMap { $0.V_meaning }.filter { !$0.isEmpty })).joined(separator: "; ")
                            if !vMeanings.isEmpty {
                                Text(vMeanings)
                                    .font(.body)
                                    .lineLimit(1) // Thu gọn ở màn hình ngoài
                            }

                            Text(learningSummary(for: meanings))
                                .font(.caption)
                                .foregroundColor(learningSummaryColor(for: meanings))
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                for item in meanings {
                                    await deleteVocab(item)
                                }
                                DispatchQueue.main.async { onRefresh() }
                            }
                        } label: {
                            Label("Xóa từ", systemImage: "trash")
                        }
                        
                        if canEdit(firstMeaning) {
                            Button {
                                selectedVocabForEdit = firstMeaning
                            } label: {
                                Label("Sửa", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle(topic)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddVocab = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedVocabForEdit) { vocab in
            AddVocabView(existing: vocab, saveAsSystem: saveAsSystem, onComplete: {
                onRefresh()
                selectedVocabForEdit = nil
            })
        }
        .sheet(isPresented: $showingAddVocab) {
            AddVocabView(saveAsSystem: saveAsSystem, fixedTopic: topic, onComplete: {
                onRefresh()
            })
        }
    }
    
    func deleteVocab(_ item: Vocabulary) async {
        guard let id = item.id else { return }
        do {
            try await VocabularyRepository.delete(id: id)
        } catch {
            print("Xóa thất bại: \(error)")
        }
    }

    private func canEdit(_ item: Vocabulary?) -> Bool {
        guard let item else { return false }
        return AuthManager.shared.isAdmin || item.visibility == "private"
    }

    private func learningSummary(for meanings: [Vocabulary]) -> String {
        let learningItems = meanings.filter { ($0.learning_level ?? 0) > 0 }
        guard let first = learningItems.first else {
            return "Đưa từ này vào học"
        }

        let level = first.learning_level ?? 0
        if level < 6 {
            return "Ôn lại: \(ReviewTimeFormatter.text(for: first.next_review))"
        }

        guard let average = pronunciationAverage(for: learningItems) else {
            return "Kiểm tra phát âm"
        }

        return "Điểm phát âm: \(average)/100"
    }

    private func learningSummaryColor(for meanings: [Vocabulary]) -> Color {
        let learningItems = meanings.filter { ($0.learning_level ?? 0) > 0 }
        guard let first = learningItems.first else { return .secondary }
        if (first.learning_level ?? 0) < 6 { return .orange }
        guard let average = pronunciationAverage(for: learningItems) else { return .purple }
        return average >= 70 ? .green : .orange
    }

    private func pronunciationAverage(for meanings: [Vocabulary]) -> Int? {
        let scores = meanings.compactMap(\.pronunciation_score)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }
}

struct WordDetailView: View {
    let word: String
    var meanings: [Vocabulary]
    var saveAsSystem: Bool = false
    var onRefresh: () -> Void
    
    @State private var selectedVocab: Vocabulary? = nil
    @State private var practiceTasks: [PronunciationTask] = []
    @State private var showingPractice = false
    @State private var isSubmittingContribution = false
    @State private var contributionMessage = ""
    @State private var showingContributionAlert = false
    
    var body: some View {
        List {
            ForEach(Array(meanings.enumerated()), id: \.element.id) { index, item in
                Section(header: HStack {
                    Text("Nghĩa \(index + 1)")
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let form = item.word_form, !form.isEmpty {
                            HStack {
                                DetailRow(title: "Từ loại (Word form)", content: form, color: .purple)
                                Spacer()
                                Button(action: {
                                    SpeechManager.shared.speak(word: item.vocab ?? "", ipa: item.IPA)
                                }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                        }
                        if let ipa = item.IPA, !ipa.isEmpty {
                            DetailRow(title: "Phát âm (IPA)", content: ipa, color: .blue)
                        }
                        if let cefr = item.CEFR, !cefr.isEmpty {
                            DetailRow(title: "Cấp độ (CEFR)", content: cefr, color: .orange)
                        }
                        if let eMeaning = item.E_meaning, !eMeaning.isEmpty {
                            DetailRow(title: "Nghĩa Tiếng Anh", content: eMeaning, onSpeak: {
                                SpeechManager.shared.speak(word: eMeaning, ipa: nil)
                            })
                        }
                        if let evMeaning = item.EV_meaning, !evMeaning.isEmpty {
                            DetailRow(title: "Nghĩa Anh - Việt", content: evMeaning)
                        }
                        if let vMeaning = item.V_meaning, !vMeaning.isEmpty {
                            DetailRow(title: "Nghĩa Tiếng Việt", content: vMeaning)
                        }
                        if let eExample = item.E_example, !eExample.isEmpty {
                            DetailRow(title: "Ví dụ Tiếng Anh", content: eExample, isItalic: true, onSpeak: {
                                SpeechManager.shared.speak(word: eExample, ipa: nil)
                            })
                        }
                        if let vExample = item.V_example, !vExample.isEmpty {
                            DetailRow(title: "Ví dụ Tiếng Việt", content: vExample)
                        }
                        if let family = item.word_family, !family.isEmpty {
                            DetailRow(title: "Từ cùng họ (Word family)", content: family)
                        }
                        if let synonymous = item.synonymous, !synonymous.isEmpty {
                            DetailRow(title: "Từ đồng nghĩa", content: synonymous)
                        }
                        if let antonym = item.antonym, !antonym.isEmpty {
                            DetailRow(title: "Từ trái nghĩa", content: antonym)
                        }
                        if let bonus = item.bonus, !bonus.isEmpty {
                            DetailRow(title: "Thông tin mở rộng", content: bonus)
                        }
                        
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await deleteSingleMeaning(item) }
                    } label: {
                        Label("Xóa", systemImage: "trash")
                    }
                    
                    if canEdit(item) {
                        Button {
                            selectedVocab = item
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            
            Section {
                let learningItem = meanings.first(where: { ($0.learning_level ?? 0) > 0 })
                if learningItem == nil {
                    Button(action: {
                        Task { await addToLearning(meanings) }
                    }) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                            Text("Đưa từ này vào học")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                } else if let learningItem = learningItem {
                    let level = learningItem.learning_level ?? 1
                    
                    VStack(spacing: 5) {
                        if level >= 6 {
                            let averageScore = pronunciationAverage(for: meanings)
                            let hasPassed = (averageScore ?? 0) >= 70
                            
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Đã master từ này")
                            }
                            .font(.headline)
                            .foregroundColor(.purple)
                            
                            if hasPassed {
                                Text("=> Đã hoàn thành kiểm tra phát âm")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    
                                if let score = averageScore {
                                    HStack {
                                        Image(systemName: "mic.fill")
                                        Text("Điểm phát âm: \(score)/100")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(score >= 70 ? .green : .orange)
                                    .padding(.top, 2)
                                }
                                
                                Button(action: {
                                    practiceTasks = makePronunciationTasks(from: meanings)
                                    showingPractice = true
                                }) {
                                    Text("Luyện phát âm ngay")
                                        .font(.subheadline)
                                        .bold()
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 5)
                            } else {
                                Text("=> Cần kiểm tra phát âm trong phần Master")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                        } else {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Đang học (Cấp độ \(level)/6)")
                            }
                            .font(.headline)
                            .foregroundColor(.orange)
                            
                            Text("=> Ôn lại: \(reviewTimeText(for: learningItem.next_review))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(level >= 6 ? Color.purple.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .listRowBackground(Color.clear)
                }
            }

            if canSubmitToSystem {
                Section {
                    Button {
                        Task { await submitPrivateMeanings() }
                    } label: {
                        if isSubmittingContribution {
                            HStack {
                                ProgressView()
                                Text("Đang gửi duyệt...")
                            }
                        } else {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Gửi duyệt lên hệ thống")
                            }
                        }
                    }
                    .disabled(isSubmittingContribution)
                } footer: {
                    Text("Admin duyệt xong thì từ riêng này sẽ được bổ sung vào bộ từ chung.")
                }
            }
        }
        .navigationTitle(word)
        .sheet(item: $selectedVocab) { vocab in
            AddVocabView(existing: vocab, saveAsSystem: saveAsSystem, onComplete: {
                onRefresh()
                selectedVocab = nil
            })
        }
        .fullScreenCover(isPresented: $showingPractice) {
            PronunciationSessionView(tasks: practiceTasks) {
                showingPractice = false
                onRefresh()
            }
        }
        .alert("Thông báo", isPresented: $showingContributionAlert) {
            Button("OK") {}
        } message: {
            Text(contributionMessage)
        }
    }
    
    func reviewTimeText(for dateStr: String?) -> String {
        ReviewTimeFormatter.text(for: dateStr)
    }

    func deleteSingleMeaning(_ item: Vocabulary) async {
        guard let id = item.id else { return }
        do {
            try await VocabularyRepository.delete(id: id)

            DispatchQueue.main.async {
                onRefresh()
            }
        } catch {
            print("Xóa thất bại: \(error)")
        }
    }
    
    func addToLearning(_ items: [Vocabulary]) async {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: now)
        
        do {
            for item in items {
                guard let id = item.id else { continue }
                try await VocabularyRepository.updateLearningData(id: id, learningLevel: 1, nextReview: dateString)
            }
                
            DispatchQueue.main.async {
                onRefresh()
            }
        } catch {
            print("Học: \(error)")
        }
    }

    private func canEdit(_ item: Vocabulary) -> Bool {
        AuthManager.shared.isAdmin || item.visibility == "private"
    }

    private var canSubmitToSystem: Bool {
        !AuthManager.shared.isAdmin && meanings.contains { $0.visibility == "private" }
    }

    private func submitPrivateMeanings() async {
        let privateMeanings = meanings.filter { $0.visibility == "private" }
        guard !privateMeanings.isEmpty else { return }

        isSubmittingContribution = true
        defer { isSubmittingContribution = false }

        do {
            for item in privateMeanings {
                try await ContributionRepository.submitVocabulary(item)
            }
            contributionMessage = "Đã gửi từ này cho admin duyệt."
            showingContributionAlert = true
        } catch {
            contributionMessage = "Gửi duyệt thất bại: \(error.localizedDescription)"
            showingContributionAlert = true
        }
    }

    private func makePronunciationTasks(from meanings: [Vocabulary]) -> [PronunciationTask] {
        meanings.compactMap { item in
            guard let word = item.vocab else { return nil }
            return PronunciationTask(
                word: word,
                targetText: item.E_example?.isEmpty == false ? item.E_example! : word,
                meaning: item
            )
        }
    }

    private func pronunciationAverage(for meanings: [Vocabulary]) -> Int? {
        let scores = meanings.compactMap(\.pronunciation_score)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
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
