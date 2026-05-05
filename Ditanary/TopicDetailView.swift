import SwiftUI
import Supabase

struct TopicDetailView: View {
    let topic: String
    var vocabs: [Vocabulary]
    var onRefresh: () -> Void
    
    @State private var selectedVocabForEdit: Vocabulary? = nil
    
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
                    
                    NavigationLink(destination: WordDetailView(word: word, meanings: meanings, onRefresh: onRefresh)) {
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
                                    if let score = meanings.first(where: { ($0.learning_level ?? 0) > 0 })?.pronunciation_score {
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
        .navigationTitle(topic)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedVocabForEdit) { vocab in
            AddVocabView(existing: vocab, onComplete: {
                onRefresh()
                selectedVocabForEdit = nil
            })
        }
    }
    
    func deleteVocab(_ item: Vocabulary) async {
        guard let id = item.id else { return }
        do {
            try await supabase
                .from("vocab_list")
                .delete()
                .eq("ID", value: id)
                .execute()
        } catch {
            print("Xóa thất bại: \(error)")
        }
    }
}

struct WordDetailView: View {
    let word: String
    var meanings: [Vocabulary]
    var onRefresh: () -> Void
    
    @State private var selectedVocab: Vocabulary? = nil
    @State private var practiceTask: PronunciationTask? = nil
    
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
                    
                    Button {
                        selectedVocab = item
                    } label: {
                        Label("Sửa", systemImage: "pencil")
                    }
                    .tint(.orange)
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
                            let hasPassed = (learningItem.pronunciation_score ?? 0) >= 70
                            
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
                                    
                                if let score = learningItem.pronunciation_score {
                                    HStack {
                                        Image(systemName: "mic.fill")
                                        Text("Điểm phát âm: \(score)/100")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(score >= 70 ? .green : .orange)
                                    .padding(.top, 2)
                                }
                                
                                Button(action: {
                                    practiceTask = PronunciationTask(
                                        word: learningItem.vocab ?? "",
                                        targetText: learningItem.E_example ?? learningItem.vocab ?? "",
                                        meaning: learningItem
                                    )
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
        }
        .navigationTitle(word)
        .sheet(item: $selectedVocab) { vocab in
            AddVocabView(existing: vocab, onComplete: {
                onRefresh()
                selectedVocab = nil
            })
        }
        .fullScreenCover(item: $practiceTask) { task in
            PronunciationSessionView(tasks: [task]) {
                practiceTask = nil
                onRefresh()
            }
        }
    }
    
    func reviewTimeText(for dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "Ngay bây giờ" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter2 = ISO8601DateFormatter()
        
        guard let date = formatter.date(from: dateStr) ?? formatter2.date(from: dateStr) else {
            return "Ngay bây giờ"
        }
        
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        
        if date <= now {
            return "Hôm nay"
        }
        
        if let days = diff.day, days > 0 {
            return "sau \(days) ngày"
        }
        if let hours = diff.hour, hours > 0 {
            return "sau \(hours) giờ"
        }
        if let minutes = diff.minute, minutes > 0 {
            return "sau \(minutes) phút"
        }
        return "Ngay bây giờ"
    }

    func deleteSingleMeaning(_ item: Vocabulary) async {
        guard let id = item.id else { return }
        do {
            try await supabase
                .from("vocab_list")
                .delete()
                .eq("ID", value: id)
                .execute()

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
                try await supabase
                    .from("vocab_list")
                    .update(UpdateLearningData(learning_level: 1, next_review: dateString))
                    .eq("ID", value: id)
                    .execute()
            }
                
            DispatchQueue.main.async {
                onRefresh()
            }
        } catch {
            print("Học: \(error)")
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
