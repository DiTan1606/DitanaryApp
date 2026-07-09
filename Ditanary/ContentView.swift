import SwiftUI

extension Foundation.Notification.Name {
    static let openLearningTab = Self("openLearningTab")
}

private enum UserTab {
    case home
    case myVocabulary
    case learning
    case setting
    case profile
}

struct ContentView: View {
    @ObservedObject private var auth = AuthManager.shared
    @State private var selectedUserTab: UserTab = .home
    
    var body: some View {
        if auth.isAdmin {
            TabView {
                AdminView()
                    .tabItem {
                        Label("Admin", systemImage: "shield")
                    }
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        } else {
            TabView(selection: $selectedUserTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(UserTab.home)
                
                MyVocabularyView()
                    .tabItem {
                        Label("My Vocab", systemImage: "book")
                    }
                    .tag(UserTab.myVocabulary)
                
                LearningView()
                    .tabItem {
                        Label("Learning", systemImage: "graduationcap")
                    }
                    .tag(UserTab.learning)
                
                SettingView()
                    .tabItem {
                        Label("Setting", systemImage: "gear")
                    }
                    .tag(UserTab.setting)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .tag(UserTab.profile)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openLearningTab)) { _ in
                selectedUserTab = .learning
            }
        }
    }
}
