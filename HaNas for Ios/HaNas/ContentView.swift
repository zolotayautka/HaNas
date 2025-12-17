import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            appState.checkAuthentication()
        }
    }
}

struct MainView: View {
    var body: some View {
        NavigationView {
            FileListView()
        }
        .navigationViewStyle(.stack)
    }
}
