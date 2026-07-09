import SwiftUI

struct MyVocabularyView: View {
    @State private var vocabs: [Vocabulary] = []
    @State private var isLoading = false
    @State private var showingTopicDraft = false
    
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
                if isLoading && vocabs.isEmpty {
                    ProgressView("Đang tải dữ liệu...")
                } else if vocabs.isEmpty {
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
            let fetchedVocabs = try await VocabularyRepository.fetchUserVocabs(userId: userId, ordered: true)
            
            DispatchQueue.main.async {
                self.vocabs = fetchedVocabs
                self.isLoading = false
            }
        } catch {
            print("Lỗi lấy dữ liệu: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}
