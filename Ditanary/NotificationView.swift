import SwiftUI

struct NotificationView: View {
    var body: some View {
        List {
            Text("Chưa có thông báo nào.")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Thông báo")
    }
}

#Preview {
    NavigationStack {
        NotificationView()
    }
}
