import SwiftUI

struct MyVocabularyView: View {
    @State private var vocabs: [Vocabulary] = []
    @State private var topicSubmissions: [TopicContribution] = []
    @State private var isLoading = false
    @State private var showingTopicDraft = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    // Gom nhóm từ vựng theo topics
    var groupedVocabs: [String: [Vocabulary]] {
        Dictionary(grouping: vocabs, by: { 
            if let topic = $0.topics, !topic.trimmingCharacters(in: .whitespaces).isEmpty {
                return topic.trimmingCharacters(in: .whitespaces)
            }
            return "Chưa phân loại"
        })
    }
    
    // Sắp xếp tên chủ đề theo alphabet
    var sortedTopics: [String] {
        groupedVocabs.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && vocabs.isEmpty && topicSubmissions.isEmpty {
                    ProgressView("Đang tải dữ liệu...")
                } else if vocabs.isEmpty && topicSubmissions.isEmpty {
                    VStack {
                        Text("Chưa có từ vựng nào.")
                            .foregroundColor(.secondary)
                        Text("Hãy tải một bộ từ ở Trang chủ trước, rồi thêm từ riêng trong bộ đó.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                } else {
                    List {
                        if !vocabs.isEmpty {
                            Section("Bộ từ của tôi") {
                                ForEach(sortedTopics, id: \.self) { topic in
                                    NavigationLink {
                                        TopicDetailView(
                                            topic: topic,
                                            vocabs: groupedVocabs[topic] ?? [],
                                            onRefresh: {
                                                Task { await fetchVocabs() }
                                            }
                                        )
                                    } label: {
                                        HStack {
                                            Text(topic)
                                                .font(.headline)
                                            Spacer()
                                            let topicVocabs = groupedVocabs[topic] ?? []
                                            let uniqueCount = Set(topicVocabs.compactMap { $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() }).count
                                            Text("\(uniqueCount) từ")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }

                        if !topicSubmissions.isEmpty {
                            Section("Topic đang gửi duyệt") {
                                ForEach(topicSubmissions) { submission in
                                    TopicSubmissionStatusCard(
                                        submission: submission,
                                        onResubmit: {
                                            Task { await resubmitTopic(submission) }
                                        },
                                        onDelete: {
                                            Task { await deleteTopicSubmission(submission) }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .refreshable {
                        await fetchVocabs()
                    }
                }
            }
            .navigationTitle("My Vocabulary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTopicDraft = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .task {
                await fetchVocabs()
            }
            .alert("Thông báo", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingTopicDraft) {
                TopicDraftRequestView(onComplete: {
                    Task { await fetchVocabs() }
                })
            }
        }
    }
    
    func fetchVocabs() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            self.isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            async let fetchedVocabs = VocabularyRepository.fetchUserVocabs(userId: userId, ordered: true)
            async let fetchedSubmissions = ContributionRepository.fetchUserTopicSubmissions()
            let result = try await (fetchedVocabs, fetchedSubmissions)
            
            DispatchQueue.main.async {
                self.vocabs = result.0
                self.topicSubmissions = result.1
                self.isLoading = false
            }
        } catch {
            print("Lỗi lấy dữ liệu: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    func resubmitTopic(_ submission: TopicContribution) async {
        do {
            try await ContributionRepository.resubmitTopicSubmission(submission)
            await fetchVocabs()
            DispatchQueue.main.async {
                alertMessage = "Đã gửi lại topic cho admin duyệt."
                showingAlert = true
            }
        } catch {
            DispatchQueue.main.async {
                alertMessage = "Gửi lại thất bại: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    func deleteTopicSubmission(_ submission: TopicContribution) async {
        do {
            try await ContributionRepository.deleteTopicSubmission(submission)
            await fetchVocabs()
            DispatchQueue.main.async {
                alertMessage = "Đã xoá topic nháp."
                showingAlert = true
            }
        } catch {
            DispatchQueue.main.async {
                alertMessage = "Xoá thất bại: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

private struct TopicSubmissionStatusCard: View {
    let submission: TopicContribution
    let onResubmit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(submission.name)
                        .font(.headline)
                    Text("\(submission.words.count) từ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusBadge
            }

            if let description = submission.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(submission.words.prefix(3)) { word in
                HStack(spacing: 8) {
                    Image(systemName: "textformat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(word.word)
                        .font(.subheadline)
                    if !word.vMeaning.isEmpty {
                        Text("- \(word.vMeaning)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if submission.words.count > 3 {
                Text("+\(submission.words.count - 3) từ khác")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if submission.status == "rejected" {
                HStack {
                    Button {
                        onResubmit()
                    } label: {
                        Label("Gửi duyệt lại", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Xoá", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if submission.status == "pending" {
            Label("Chờ duyệt", systemImage: "clock.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
        } else {
            Label("Không duyệt", systemImage: "xmark.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.12))
                .cornerRadius(6)
        }
    }
}
