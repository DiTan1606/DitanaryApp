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
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(submission.vocab.vocab ?? "Untitled")
                                        .font(.headline)
                                    Text(submission.vocab.topics ?? "Chưa phân loại")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if let meaning = submission.vocab.V_meaning, !meaning.isEmpty {
                                        Text(meaning)
                                            .font(.body)
                                    }
                                    Text("Người gửi: \(submission.requesterId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack {
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
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Topic nháp chờ duyệt") {
                        if topicSubmissions.isEmpty {
                            Text("Không có topic nào chờ duyệt.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(topicSubmissions) { submission in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(submission.name)
                                        .font(.headline)
                                    Text("\(submission.words.count) từ")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if let description = submission.description, !description.isEmpty {
                                        Text(description)
                                            .font(.body)
                                    }
                                    Text("Người gửi: \(submission.requesterId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ForEach(submission.words.prefix(3)) { word in
                                        Text("- \(word.word)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack {
                                        Button {
                                            Task { await approveTopic(submission) }
                                        } label: {
                                            Label("Duyệt topic", systemImage: "checkmark.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)

                                        Button {
                                            Task { await rejectTopic(submission) }
                                        } label: {
                                            Label("Từ chối", systemImage: "xmark.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }
                                }
                                .padding(.vertical, 4)
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
            let result = try await (vocab, topics)
            vocabSubmissions = result.0
            topicSubmissions = result.1
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
            try await ContributionRepository.rejectVocabularySubmission(id: submission.id)
        }
    }

    private func approveTopic(_ submission: TopicContribution) async {
        await performReview {
            try await ContributionRepository.approveTopicSubmission(submission)
        }
    }

    private func rejectTopic(_ submission: TopicContribution) async {
        await performReview {
            try await ContributionRepository.rejectTopicSubmission(id: submission.id)
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
}
