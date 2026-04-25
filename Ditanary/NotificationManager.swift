import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Quyền thông báo đã được cấp")
            } else if let error = error {
                print("Lỗi yêu cầu quyền thông báo: \(error)")
            }
        }
    }
    
    // 1. Nhắc nhở học mỗi ngày
    func scheduleDailyReminder(at date: Date) {
        // Hủy các nhắc nhở hàng ngày cũ
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Ditanary"
        content.body = "Đã đến giờ học từ vựng rồi, vào app học ngay thôi! 🔥"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // 2. Thông báo ôn lại từ vựng
    func scheduleReviewNotification(for word: String, at reviewDate: Date) {
        // Chỉ thông báo nếu thời gian ở tương lai
        guard reviewDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Đã đến lúc ôn tập! 📚"
        content.body = "Đã đến lúc ôn lại từ '\(word)' rồi bạn ơi."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reviewDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // ID duy nhất cho mỗi từ và mốc thời gian
        let id = "review_\(word)_\(Int(reviewDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Hiển thị thông báo khi app đang mở (foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
