import SwiftUI

struct ContentView: View {
    @ObservedObject private var auth = AuthManager.shared
    
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
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                MyVocabularyView()
                    .tabItem {
                        Label("My Vocab", systemImage: "book")
                    }
                
                LearningView()
                    .tabItem {
                        Label("Learning", systemImage: "graduationcap")
                    }
                
                SettingView()
                    .tabItem {
                        Label("Setting", systemImage: "gear")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        }
    }
}
