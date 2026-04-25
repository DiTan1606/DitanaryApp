import Foundation
import AVFoundation

class SpeechManager: ObservableObject {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(word: String, ipa: String?, stopPrevious: Bool = true) {
        // Dừng giọng đọc cũ nếu đang đọc dở
        if stopPrevious {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance: AVSpeechUtterance
        
        if let ipa = ipa, !ipa.isEmpty {
            // Xóa dấu '/' thường có trong IPA (ví dụ: "/prəˈdʒekt/") để engine dễ đọc hơn
            let cleanIPA = ipa.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces)
            
            let attrString = NSMutableAttributedString(string: word)
            // Cung cấp phiên âm IPA để Apple Voice đọc đúng chuẩn theo từng từ loại (Giải quyết bài toán từ đồng âm dị nghĩa)
            attrString.addAttribute(.accessibilitySpeechIPANotation, value: cleanIPA, range: NSRange(location: 0, length: word.utf16.count))
            
            utterance = AVSpeechUtterance(attributedString: attrString)
        } else {
            // Nếu không có IPA thì đọc mặc định
            utterance = AVSpeechUtterance(string: word)
        }
        
        // Cài đặt giọng Mỹ (hoặc bạn có thể cho user tự chọn Anh-Anh, Anh-Mỹ sau này)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Giảm tốc độ đọc một xíu để nghe rõ hơn
        utterance.rate = 0.45 
        
        synthesizer.speak(utterance)
    }
}
