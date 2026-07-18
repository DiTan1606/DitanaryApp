import SwiftUI

struct PronunciationExampleExerciseView: View {
    let task: LearningTask
    let onContinue: () -> Void

    @StateObject private var pronunciationManager = PronunciationManager()
    @State private var assessment: AzurePronunciationAssessment?
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedWordIndex: Int?

    private var meaning: Vocabulary? {
        task.pronunciationMeaning
    }

    private var example: String {
        task.pronunciationExample ?? ""
    }

    private var score: PronunciationScore? {
        assessment.map(PronunciationScore.init)
    }

    private var hasPassed: Bool {
        guard let assessment else { return false }
        return PronunciationPassingRule.passes(assessment)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Label("Luyện phát âm câu ví dụ", systemImage: "mic.fill")
                    .font(.headline)
                    .foregroundColor(.purple)

                HStack(spacing: 8) {
                    Text(task.word)
                        .font(.title3.bold())

                    if let ipa = meaning?.IPA, !ipa.isEmpty {
                        Text(ipa)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                Text(example)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                if let vietnameseExample = meaning?.V_example, !vietnameseExample.isEmpty {
                    Text(vietnameseExample)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple.opacity(0.08)))

            Button {
                SpeechManager.shared.speak(
                    example: example,
                    targetWord: task.word,
                    ipa: meaning?.IPA
                )
            } label: {
                Label("Nghe câu mẫu", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .tint(.blue)

            if pronunciationManager.hasRecorded {
                recordedAudioControls
            }

            if let score {
                scoreResult(score)

                if !hasPassed {
                    recordingControls
                }
            } else {
                recordingControls
            }
        }
        .padding()
        .alert("Lỗi", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: wordFeedbackSheetPresented) {
            selectedWordFeedbackSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            if pronunciationManager.isRecording {
                pronunciationManager.stopRecording()
            }
            pronunciationManager.stopPlayback()
        }
    }

    private var recordedAudioControls: some View {
        Button {
            if pronunciationManager.isPlaying {
                pronunciationManager.stopPlayback()
            } else {
                pronunciationManager.playRecordedAudio()
            }
        } label: {
            Label(
                pronunciationManager.isPlaying ? "Dừng nghe" : "Nghe lại giọng của bạn",
                systemImage: pronunciationManager.isPlaying ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(pronunciationManager.isPlaying ? .red : .orange)
    }

    private var recordingControls: some View {
        VStack(spacing: 14) {
            Button {
                toggleRecording()
            } label: {
                Image(systemName: pronunciationManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 68))
                    .foregroundColor(pronunciationManager.isRecording ? .red : .purple)
            }

            Text(recordingInstruction)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if pronunciationManager.hasRecorded, assessment == nil {
                Button {
                    submitRecording()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        }
                        Text(isSubmitting ? "Đang chấm..." : "Chấm phát âm")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isSubmitting)
            }
        }
    }

    @ViewBuilder
    private func scoreResult(_ score: PronunciationScore) -> some View {
        VStack(spacing: 15) {
            Text("Kết quả phát âm")
                .font(.headline)
                .foregroundColor(.secondary)

            if let azureTranscript {
                Text("Bạn đọc: \(azureTranscript)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
            }

            if let assessment, !assessment.words.isEmpty {
                wordFeedbackSection(assessment.words)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 14
            ) {
                ScoreCircle(title: "Tổng", score: score.finalScore, color: .purple)
                ScoreCircle(title: "Chính xác", score: score.accuracyScore, color: .blue)
                ScoreCircle(title: "Trôi chảy", score: score.fluencyScore, color: .green)
                ScoreCircle(title: "Đầy đủ", score: score.completenessScore, color: .orange)
            }

            if hasPassed {
                Label("Đạt yêu cầu phát âm", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.green)

                Button("Tiếp tục") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if let assessment {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chưa đạt, hãy nghe mẫu và bấm mic để thu lại.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)

                    ForEach(PronunciationPassingRule.failureReasons(for: assessment), id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    private func toggleRecording() {
        if pronunciationManager.isRecording {
            pronunciationManager.stopRecording()
            return
        }

        do {
            assessment = nil
            try pronunciationManager.startRecording()
        } catch {
            errorMessage = "Không thể bắt đầu thu âm: \(error.localizedDescription)"
            showError = true
        }
    }

    private func submitRecording() {
        if pronunciationManager.isPlaying {
            pronunciationManager.stopPlayback()
        }

        guard let userVocabularyId = meaning?.user_vocabulary_id ?? meaning?.id,
              let audioURL = pronunciationManager.recordedAudioURL else {
            errorMessage = "Không tìm thấy bản ghi âm. Vui lòng thu âm lại."
            showError = true
            return
        }

        isSubmitting = true
        Task {
            do {
                let result = try await PronunciationAssessmentService.assess(
                    audioURL: audioURL,
                    userVocabularyId: userVocabularyId
                )
                let resultScore = PronunciationScore(assessment: result)

                if PronunciationPassingRule.passes(result) {
                    let currentBestScore = meaning?.pronunciation_score ?? 0
                    let newScore = Int(resultScore.finalScore.rounded())
                    if newScore > currentBestScore {
                        try? await VocabularyRepository.updatePronunciationScore(
                            id: userVocabularyId,
                            score: newScore
                        )
                    }
                }

                await MainActor.run {
                    assessment = result
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Không thể chấm phát âm lúc này. Vui lòng kiểm tra mạng và thử lại."
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }

    private var recordingInstruction: String {
        if pronunciationManager.isRecording {
            return "Đang thu âm... Bấm để dừng"
        }

        return pronunciationManager.hasRecorded ? "Bấm mic để thu âm lại" : "Bấm để thu âm"
    }

    private var azureTranscript: String? {
        let transcript = assessment?.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return transcript.isEmpty ? nil : transcript
    }

    private var wordFeedbackSheetPresented: Binding<Bool> {
        Binding(
            get: { selectedWordIndex != nil },
            set: { isPresented in
                if !isPresented {
                    selectedWordIndex = nil
                }
            }
        )
    }

    @ViewBuilder
    private var selectedWordFeedbackSheet: some View {
        if let selectedWordIndex,
           let assessment,
           assessment.words.indices.contains(selectedWordIndex) {
            PronunciationWordFeedbackSheet(
                feedback: assessment.words[selectedWordIndex],
                pronunciationManager: pronunciationManager
            )
        } else {
            EmptyView()
        }
    }

    private func wordFeedbackSection(_ words: [AzurePronunciationAssessment.WordFeedback]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kết quả từng từ")
                .font(.subheadline.weight(.semibold))

            FlowLayout(spacing: 8) {
                PronunciationFeedbackLegend(level: .good)
                PronunciationFeedbackLegend(level: .needsImprovement)
                PronunciationFeedbackLegend(level: .retry)
            }

            FlowLayout(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let level = PronunciationPassingRule.feedbackLevel(for: word)
                    Button {
                        selectedWordIndex = index
                    } label: {
                        HStack(spacing: 4) {
                            Text(word.word)
                            Text("\(Int(word.accuracy.rounded()))")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundColor(level.foregroundColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(level.backgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(level.foregroundColor.opacity(0.22), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(word.word), \(level.title), \(Int(word.accuracy.rounded())) điểm")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
