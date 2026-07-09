import SwiftUI
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
                                    x: .value("Cấp độ", LearningLevelDisplay.title(for: level)),
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
            let allResponse = try await VocabularyRepository.fetchUserVocabs(userId: userId)
            let plan = LearningSessionBuilder.build(from: allResponse)
            
            DispatchQueue.main.async {
                self.statsByLevel = plan.statsByLevel
                self.totalLearningWords = plan.totalLearningWords
                self.totalSavedWords = plan.totalSavedWords
                self.dueVocabsCount = plan.dueVocabsCount
                self.masterDueVocabsCount = plan.masterDueVocabsCount
                self.learningVocabGroups = plan.selectedGroups
                self.tasks = plan.tasks
                self.masterTasks = plan.masterTasks
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
