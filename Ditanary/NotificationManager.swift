import Foundation
import UserNotifications
import Supabase

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
    
    // 1. Nhắc nhở học mỗi ngày (Tính năng chính)
    func scheduleDailyReminder(at date: Date) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "Ditanary"
        content.body = "Đã đến giờ học từ vựng rồi, vào app học ngay thôi! 🔥"
        content.sound = .default
        content.userInfo = ["type": "daily_reminder"]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("Đã đặt lịch nhắc nhở hàng ngày thành công")
            }
        }
    }
    
    // 2. Thông báo ôn lại từ vựng (Đã lược bỏ theo yêu cầu mới)
    func scheduleReviewNotification(for word: String, at reviewDate: Date) {
        // Tính năng này đã được lược bỏ để tránh làm phiền người dùng
    }
    
    // Lưu thông báo vào Supabase
    private func saveNotificationToSupabase(title: String, content: String, scheduledDate: Date? = nil) async {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        
        // Định dạng ngày tạo theo ý muốn (nếu là thông báo tương lai thì dùng ngày đó)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: scheduledDate ?? Date())
        
        let notification = Notification(
            id: UUID().uuidString,
            user_id: userId,
            title: title,
            content: content,
            is_read: false,
            created_at: dateString
        )
        
        do {
            try await supabase
                .from("notifications")
                .insert(notification)
                .execute()
        } catch {
            print("Lỗi lưu thông báo: \(error)")
        }
    }
    
    // Hiển thị thông báo khi app đang mở
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Khi thông báo thực sự nổ ra (kể cả khi đang mở app), ta có thể log thêm nếu muốn
        let content = notification.request.content
        print("Thông báo đang hiển thị: \(content.title)")
        
        completionHandler([.banner, .sound, .badge])
    }
    
    // Xử lý khi người dùng nhấn vào thông báo
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // Có thể điều hướng người dùng đến trang cụ thể ở đây
        completionHandler()
    }
}
