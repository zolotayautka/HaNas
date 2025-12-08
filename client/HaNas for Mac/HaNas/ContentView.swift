import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                LoginView {
                    appState.checkAuthentication()
                }
            }
        }
        .onAppear {
            appState.checkAuthentication()
        }
    }
}

struct MainView: View {
    var body: some View {
        FileListView()
    }
}