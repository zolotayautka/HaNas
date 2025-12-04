import SwiftUI

@main
struct HaNas_for_MacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState.shared)
        }
    }
}
