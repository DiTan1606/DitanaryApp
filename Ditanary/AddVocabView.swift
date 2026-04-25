import SwiftUI
import Supabase

struct AddVocabView: View {
    @Environment(\.dismiss) var dismiss
    
    var existing: Vocabulary?
    var onComplete: () -> Void
    
    @State private var vocab = ""
    @State private var wordForm = ""
    @State private var ipa = ""
    @State private var cefr = ""
    @State private var vMeaning = ""
    @State private var eMeaning = ""
    @State private var evMeaning = ""
    @State private var vExample = ""
    @State private var eExample = ""
    @State private var topics = ""
    @State private var wordFamily = ""
    @State private var synonymous = ""
    @State private var antonym = ""
    @State private var bonus = ""
    
    @State private var isSaving = false
    @State private var errorMessage = ""
    
    init(existing: Vocabulary? = nil, onComplete: @escaping () -> Void) {
        self.existing = existing
        self.onComplete = onComplete
        
        if let v = existing {
            _vocab = State(initialValue: v.vocab ?? "")
            _wordForm = State(initialValue: v.word_form ?? "")
            _ipa = State(initialValue: v.IPA ?? "")
            _cefr = State(initialValue: v.CEFR ?? "")
            _vMeaning = State(initialValue: v.V_meaning ?? "")
            _eMeaning = State(initialValue: v.E_meaning ?? "")
            _evMeaning = State(initialValue: v.EV_meaning ?? "")
            _vExample = State(initialValue: v.V_example ?? "")
            _eExample = State(initialValue: v.E_example ?? "")
            _topics = State(initialValue: v.topics ?? "")
            _wordFamily = State(initialValue: v.word_family ?? "")
            _synonymous = State(initialValue: v.synonymous ?? "")
            _antonym = State(initialValue: v.antonym ?? "")
            _bonus = State(initialValue: v.bonus ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thông tin cơ bản")) {
                    TextField("Chủ đề (Topics)", text: $topics)
                    TextField("Từ vựng (Vocab)", text: $vocab)
                    TextField("Cấp độ (CEFR)", text: $cefr)
                    TextField("Phiên âm (IPA)", text: $ipa)
                    TextField("Từ loại (Word Form)", text: $wordForm)
                }
                
                Section(header: Text("Ý nghĩa")) {
                    TextField("Nghĩa tiếng Anh", text: $eMeaning)
                    TextField("Nghĩa Anh-Việt", text: $evMeaning)
                    TextField("Nghĩa tiếng Việt", text: $vMeaning)
                }
                
                Section(header: Text("Ví dụ")) {
                    TextField("Ví dụ tiếng Anh", text: $eExample)
                    TextField("Ví dụ tiếng Việt", text: $vExample)
                }
                
                Section(header: Text("Mở rộng")) {
                    TextField("Họ từ (Word family)", text: $wordFamily)
                    TextField("Từ đồng nghĩa", text: $synonymous)
                    TextField("Từ trái nghĩa", text: $antonym)
                    TextField("Ghi chú thêm (Bonus)", text: $bonus)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle(existing == nil ? "Thêm từ mới" : "Sửa từ vựng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") { Task { await saveVocab() } }
                        .disabled(vocab.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Đang lưu...")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    func saveVocab() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            errorMessage = "Chưa đăng nhập!"
            return
        }
        
        isSaving = true
        errorMessage = ""
        
        let newVocab = Vocabulary(
            id: existing?.id ?? UUID().uuidString,
            created_at: existing?.created_at, // Giữ nguyên ngày tạo nếu đang edit
            topics: topics.isEmpty ? nil : topics,
            vocab: vocab.isEmpty ? nil : vocab,
            CEFR: cefr.isEmpty ? nil : cefr,
            IPA: ipa.isEmpty ? nil : ipa,
            word_form: wordForm.isEmpty ? nil : wordForm,
            E_meaning: eMeaning.isEmpty ? nil : eMeaning,
            EV_meaning: evMeaning.isEmpty ? nil : evMeaning,
            V_meaning: vMeaning.isEmpty ? nil : vMeaning,
            E_example: eExample.isEmpty ? nil : eExample,
            V_example: vExample.isEmpty ? nil : vExample,
            word_family: wordFamily.isEmpty ? nil : wordFamily,
            synonymous: synonymous.isEmpty ? nil : synonymous,
            antonym: antonym.isEmpty ? nil : antonym,
            bonus: bonus.isEmpty ? nil : bonus,
            user_id: existing?.user_id ?? userId // Gắn user_id
        )
        
        do {
            if existing != nil {
                // Update
                try await supabase
                    .from("vocab_list")
                    .update(newVocab)
                    .eq("ID", value: newVocab.id!)
                    .execute()
            } else {
                // Insert
                try await supabase
                    .from("vocab_list")
                    .insert(newVocab)
                    .execute()
            }
            
            DispatchQueue.main.async {
                isSaving = false
                onComplete()
                dismiss()
            }
        } catch {
            DispatchQueue.main.async {
                isSaving = false
                errorMessage = "Lỗi: \(error.localizedDescription)"
                print("Lỗi lưu dữ liệu: \(error)")
            }
        }
    }
}
