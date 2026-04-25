import SwiftUI

@main
struct DitanaryApp: App {
    @StateObject private var auth = AuthManager.shared

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            if auth.isCheckingAuth {
                VStack {
                    ProgressView("Đang kiểm tra đăng nhập...")
                }
            } else if auth.isAuthenticated {
                ContentView()
            } else {
                AuthView()
            }
        }
    }
}
