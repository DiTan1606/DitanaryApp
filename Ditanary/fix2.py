import sys

filepath = "/Users/ditan/Desktop/DitanaryApp/Ditanary/LearningView.swift"

with open(filepath, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = lines[:1133]

new_content = """struct PronunciationSessionView: View {
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
                    
                    Text("Câu \\(currentTaskIndex + 1) / \\(tasks.count)")
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
                                    
                                    if score.finalScore >= 75 {
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
                errorMessage = "Không thể bắt đầu thu âm: \\(error.localizedDescription)"
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
        let nextDate = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
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
                print("Lỗi update master review cho \\(task.word): \\(error)")
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
            print("Failed to create audio file for recording: \\(error)")
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
                print("Failed to write audio buffer: \\(error)")
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
            print("Error playing recorded audio: \\(error)")
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
            utterance.rate = 0.5 // Normal rate is 0.5
            
            synthesizer.speak(utterance)
        } catch {
            print("TTS setup error: \\(error)")
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
                
                Text("\\(Int(score))")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 50, height: 50)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
"""

with open(filepath, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
    f.write(new_content)

