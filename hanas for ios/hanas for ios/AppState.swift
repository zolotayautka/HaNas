import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isAuthenticated = false
    @Published var serverURL: String?
    @Published var username: String?

    private init() {
        Task {
            await checkAuthentication()
        }
    }

    func checkAuthentication() {
        if let config = ConfigManager.shared.loadConfig() {
            HaNasAPI.shared.setBaseURL(config.serverURL)
            Task {
                do {
                    let response = try await HaNasAPI.shared.login(
                        username: config.username,
                        password: config.password
                    )
                    if response.success {
                        self.serverURL = config.serverURL
                        self.username = config.username
                        self.isAuthenticated = true
                    } else {
                        self.isAuthenticated = false
                    }
                } catch {
                    self.isAuthenticated = false
                }
            }
        } else {
            isAuthenticated = false
        }
    }
    
    func logout() {
        Task {
            do {
                try await HaNasAPI.shared.logout()
            } catch {
            }
            _ = ConfigManager.shared.deleteConfig()
            self.isAuthenticated = false
            self.serverURL = nil
            self.username = nil
        }
    }
}
