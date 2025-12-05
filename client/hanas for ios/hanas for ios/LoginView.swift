import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL: String = "http://192.168.1.1"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isRegisterMode: Bool = false
    
    init() {
        if let config = ConfigManager.shared.loadConfig() {
            _serverURL = State(initialValue: config.serverURL)
            _username = State(initialValue: config.username)
            _password = State(initialValue: config.password)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Spacer()
                    .frame(height: 40)
                Image(systemName: "externaldrive.fill.badge.icloud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                Text(NSLocalizedString("app_name", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(NSLocalizedString(isRegisterMode ? "register_title" : "login_title", comment: ""))
                    .font(.headline)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(NSLocalizedString("server_address", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("server_placeholder", comment: ""), text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(NSLocalizedString("username", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("username_placeholder", comment: ""), text: $username)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(NSLocalizedString("password", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField(NSLocalizedString("password_placeholder", comment: ""), text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                Button(action: isRegisterMode ? attemptRegister : attemptLogin) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString(isRegisterMode ? "register_button" : "login_button", comment: ""))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || serverURL.isEmpty || username.isEmpty || password.isEmpty)
                .padding(.horizontal)
                Button(action: {
                    isRegisterMode.toggle()
                    showError = false
                    errorMessage = ""
                }) {
                    Text(NSLocalizedString(isRegisterMode ? "switch_to_login" : "switch_to_register", comment: ""))
                        .font(.caption)
                }
                Spacer()
            }
        }
    }
    
    private func attemptLogin() {
        isLoading = true
        showError = false
        errorMessage = ""
        let api = HaNasAPI.shared
        api.setBaseURL(serverURL)
        
        Task {
            do {
                let response = try await api.login(username: username, password: password)
                if response.success {
                    let saved = ConfigManager.shared.saveConfig(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                    await MainActor.run {
                        isLoading = false
                        if saved {
                            appState.isAuthenticated = true
                            appState.serverURL = serverURL
                            appState.username = username
                        } else {
                            errorMessage = NSLocalizedString("config_save_failed", comment: "")
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = NSLocalizedString("login_failed", comment: "")
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "\(NSLocalizedString("connection_error", comment: "")): \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func attemptRegister() {
        isLoading = true
        showError = false
        errorMessage = ""
        let api = HaNasAPI.shared
        api.setBaseURL(serverURL)
        
        Task {
            do {
                let response = try await api.register(username: username, password: password)
                if response.success {
                    let saved = ConfigManager.shared.saveConfig(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                    await MainActor.run {
                        isLoading = false
                        if saved {
                            appState.isAuthenticated = true
                            appState.serverURL = serverURL
                            appState.username = username
                        } else {
                            errorMessage = NSLocalizedString("config_save_failed", comment: "")
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = NSLocalizedString("register_failed", comment: "")
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "\(NSLocalizedString("connection_error", comment: "")): \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
