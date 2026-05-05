import SwiftUI
import Supabase

struct NotificationView: View {
    @State private var notifications: [Notification] = []
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if isLoading && notifications.isEmpty {
                ProgressView("Đang tải thông báo...")
            } else if notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Chưa có thông báo nào.")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(notifications) { notification in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(notification.title)
                                    .font(.headline)
                                    .foregroundColor(notification.is_read ? .secondary : .primary)
                                
                                Spacer()
                                
                                if !notification.is_read {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text(notification.content)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let dateStr = notification.created_at {
                                Text(formatDate(dateStr))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !notification.is_read {
                                markAsRead(notification)
                            }
                        }
                    }
                    .onDelete(perform: deleteNotification)
                }
                .refreshable {
                    await fetchNotifications()
                }
            }
        }
        .navigationTitle("Thông báo")
        .onAppear {
            Task { await fetchNotifications() }
        }
    }
    
    func fetchNotifications() async {
        guard let userId = await AuthManager.shared.currentUser?.id.uuidString else { return }
        
        isLoading = true
        do {
            let fetched: [Notification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Lọc chỉ hiện những thông báo đã đến giờ hoặc đã qua
            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter2 = ISO8601DateFormatter()
            
            let filtered = fetched.filter { notification in
                guard let dateStr = notification.created_at,
                      let date = formatter.date(from: dateStr) ?? formatter2.date(from: dateStr) else {
                    return true // Nếu không có ngày thì cứ hiện
                }
                return date <= now
            }
            
            DispatchQueue.main.async {
                self.notifications = filtered
                self.isLoading = false
            }
        } catch {
            print("Lỗi tải thông báo: \(error)")
            isLoading = false
        }
    }
    
    func markAsRead(_ notification: Notification) {
        Task {
            do {
                try await supabase
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("id", value: notification.id)
                    .execute()
                
                await fetchNotifications()
            } catch {
                print("Lỗi đánh dấu đã đọc: \(error)")
            }
        }
    }
    
    func deleteNotification(at offsets: IndexSet) {
        for index in offsets {
            let id = notifications[index].id
            Task {
                do {
                    try await supabase
                        .from("notifications")
                        .delete()
                        .eq("id", value: id)
                        .execute()
                } catch {
                    print("Lỗi xóa thông báo: \(error)")
                }
            }
        }
        notifications.remove(atOffsets: offsets)
    }
    
    func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter2 = ISO8601DateFormatter()
        
        guard let date = formatter.date(from: dateStr) ?? formatter2.date(from: dateStr) else {
            return dateStr
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return outputFormatter.string(from: date)
    }
}
