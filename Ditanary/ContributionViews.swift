import SwiftUI

struct TopicDraftRequestView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var topicName = ""
    @State private var topicDescription = ""
    @State private var draftWords: [TopicDraftWordInput] = []
    @State private var editingWord = TopicDraftWordInput()
    @State private var isSubmitting = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Bộ từ nháp") {
                    TextField("Tên topic muốn đề xuất", text: $topicName)
                    TextField("Mô tả ngắn", text: $topicDescription)
                }

                Section("Thêm từ vào bản nháp") {
                    Group {
                        TextField("Từ vựng", text: $editingWord.word)
                        TextField("CEFR", text: $editingWord.cefr)
                        TextField("IPA", text: $editingWord.ipa)
                        TextField("Từ loại", text: $editingWord.wordForm)
                        TextField("Nghĩa tiếng Anh", text: $editingWord.eMeaning)
                        TextField("Nghĩa Anh - Việt", text: $editingWord.evMeaning)
                        TextField("Nghĩa tiếng Việt", text: $editingWord.vMeaning)
                        TextField("Ví dụ tiếng Anh", text: $editingWord.eExample)
                        TextField("Ví dụ tiếng Việt", text: $editingWord.vExample)
                        TextField("Từ cùng họ", text: $editingWord.wordFamily)
                        TextField("Đồng nghĩa", text: $editingWord.synonymous)
                        TextField("Trái nghĩa", text: $editingWord.antonym)
                        TextField("Thông tin mở rộng", text: $editingWord.bonus)
                    }

                    Button {
                        addDraftWord()
                    } label: {
                        Label("Thêm vào bản nháp", systemImage: "plus.circle.fill")
                    }
                    .disabled(editingWord.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !draftWords.isEmpty {
                    Section("Danh sách chờ gửi") {
                        ForEach(draftWords) { word in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.word)
                                    .font(.headline)
                                if !word.vMeaning.isEmpty {
                                    Text(word.vMeaning)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            draftWords.remove(atOffsets: indexSet)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await submitDraft() }
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text("Đang gửi...")
                            }
                        } else {
                            Label("Gửi admin duyệt", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationTitle("Đề xuất topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .alert("Thông báo", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("đã gửi") {
                        onComplete()
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var canSubmit: Bool {
        !topicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draftWords.isEmpty
    }

    private func addDraftWord() {
        let word = editingWord.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        editingWord.word = word
        draftWords.append(editingWord)
        editingWord = TopicDraftWordInput()
    }

    private func submitDraft() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await ContributionRepository.submitTopicDraft(
                name: topicName,
                description: topicDescription,
                words: draftWords
            )
            alertMessage = "Bộ từ nháp đã gửi admin duyệt."
            showingAlert = true
        } catch {
            alertMessage = "Gửi yêu cầu thất bại: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct AdminContributionReviewView: View {
    @State private var vocabSubmissions: [VocabContribution] = []
    @State private var topicSubmissions: [TopicContribution] = []
    @State private var profilesById: [String: Profile] = [:]
    @State private var selectedTopicWordIds: [String: Set<String>] = [:]
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        Group {
            if isLoading && vocabSubmissions.isEmpty && topicSubmissions.isEmpty {
                ProgressView("Đang tải yêu cầu...")
            } else {
                List {
                    Section("Từ riêng chờ duyệt") {
                        if vocabSubmissions.isEmpty {
                            Text("Không có từ nào chờ duyệt.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(vocabSubmissions) { submission in
                                VStack(alignment: .leading, spacing: 12) {
                                    ContributionWordCard(vocab: submission.vocab)

                                    Text("Người gửi: \(displayName(for: submission.requesterId))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 10) {
                                        Button {
                                            Task { await approveVocab(submission) }
                                        } label: {
                                            Label("Duyệt", systemImage: "checkmark.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)

                                        Button {
                                            Task { await rejectVocab(submission) }
                                        } label: {
                                            Label("Từ chối", systemImage: "xmark.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    Section("Topic nháp chờ duyệt") {
                        if topicSubmissions.isEmpty {
                            Text("Không có topic nào chờ duyệt.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(topicSubmissions) { submission in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(submission.name)
                                                .font(.headline)
                                            Text("Người gửi: \(displayName(for: submission.requesterId))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text("\(selectedCount(for: submission))/\(submission.words.count) từ")
                                            .font(.caption.bold())
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.12))
                                            .cornerRadius(6)
                                    }

                                    if let description = submission.description, !description.isEmpty {
                                        Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    }

                                    ForEach(submission.words) { word in
                                        ContributionDraftWordCard(
                                            word: word,
                                            isSelected: isSelected(word, in: submission),
                                            onToggle: { toggle(word, in: submission) }
                                        )
                                    }

                                    HStack(spacing: 10) {
                                        Button {
                                            Task { await approveTopic(submission) }
                                        } label: {
                                            Label("Duyệt topic", systemImage: "checkmark.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                        .disabled(selectedCount(for: submission) == 0)

                                        Button {
                                            Task { await rejectTopic(submission) }
                                        } label: {
                                            Label("Từ chối", systemImage: "xmark.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .refreshable {
                    await fetchSubmissions()
                }
            }
        }
        .navigationTitle("Duyệt đóng góp")
        .task {
            await fetchSubmissions()
        }
        .alert("Thông báo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func fetchSubmissions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let vocab = ContributionRepository.fetchPendingVocabularySubmissions()
            async let topics = ContributionRepository.fetchPendingTopicSubmissions()
            async let profiles = ProfileRepository.fetchProfiles()
            let result = try await (vocab, topics, profiles)
            vocabSubmissions = result.0
            topicSubmissions = result.1
            profilesById = Dictionary(uniqueKeysWithValues: result.2.map { ($0.id, $0) })
            seedTopicSelection(for: result.1)
        } catch {
            alertMessage = "Tải danh sách duyệt thất bại: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func approveVocab(_ submission: VocabContribution) async {
        await performReview {
            try await ContributionRepository.approveVocabularySubmission(submission)
        }
    }

    private func rejectVocab(_ submission: VocabContribution) async {
        await performReview {
            try await ContributionRepository.rejectVocabularySubmission(submission)
        }
    }

    private func approveTopic(_ submission: TopicContribution) async {
        await performReview {
            try await ContributionRepository.approveTopicSubmission(
                submission,
                approvedWordIds: selectedTopicWordIds[submission.id] ?? Set(submission.words.map(\.id))
            )
        }
    }

    private func rejectTopic(_ submission: TopicContribution) async {
        await performReview {
            try await ContributionRepository.rejectTopicSubmission(submission)
        }
    }

    private func performReview(_ action: () async throws -> Void) async {
        do {
            try await action()
            await fetchSubmissions()
        } catch {
            alertMessage = "Thao tác thất bại: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func displayName(for userId: String) -> String {
        let profile = profilesById[userId]
        return profile?.display_name?.isEmpty == false
            ? profile!.display_name!
            : profile?.email ?? userId
    }

    private func seedTopicSelection(for submissions: [TopicContribution]) {
        for submission in submissions where selectedTopicWordIds[submission.id] == nil {
            selectedTopicWordIds[submission.id] = Set(submission.words.map(\.id))
        }
    }

    private func isSelected(_ word: TopicDraftWordInput, in submission: TopicContribution) -> Bool {
        selectedTopicWordIds[submission.id, default: Set(submission.words.map(\.id))].contains(word.id)
    }

    private func selectedCount(for submission: TopicContribution) -> Int {
        selectedTopicWordIds[submission.id, default: Set(submission.words.map(\.id))].count
    }

    private func toggle(_ word: TopicDraftWordInput, in submission: TopicContribution) {
        var selected = selectedTopicWordIds[submission.id] ?? Set(submission.words.map(\.id))
        if selected.contains(word.id) {
            selected.remove(word.id)
        } else {
            selected.insert(word.id)
        }
        selectedTopicWordIds[submission.id] = selected
    }
}

private struct ContributionWordCard: View {
    let vocab: Vocabulary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vocab.vocab ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let cefr = vocab.CEFR, !cefr.isEmpty {
                    Text(cefr)
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.14))
                        .cornerRadius(5)
                }
            }

            if let ipa = vocab.IPA, !ipa.isEmpty {
                Text(ipa)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            if let meaning = vocab.V_meaning, !meaning.isEmpty {
                Text(meaning)
                    .font(.body)
                    .lineLimit(2)
            }

            if let topic = vocab.topics, !topic.isEmpty {
                Text(topic)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

private struct ContributionDraftWordCard: View {
    let word: TopicDraftWordInput
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(word.word)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if !word.cefr.isEmpty {
                            Text(word.cefr)
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.14))
                                .cornerRadius(5)
                        }
                    }

                    if !word.ipa.isEmpty {
                        Text(word.ipa)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    if !word.vMeaning.isEmpty {
                        Text(word.vMeaning)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }

                    if !word.eExample.isEmpty {
                        Text(word.eExample)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .background(isSelected ? Color.green.opacity(0.08) : Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
