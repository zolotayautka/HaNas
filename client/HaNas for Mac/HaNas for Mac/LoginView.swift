//
//  LoginView.swift
//  HaNas for Mac
//
//  Created by 신석주 on 12/4/25.
//

import SwiftUI

struct LoginView: View {
    @State private var serverURL: String = "http://localhost"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var isRegisterMode: Bool = false
    
    var onLoginSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.fill.badge.icloud")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            Text(NSLocalizedString("app_name", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(NSLocalizedString(isRegisterMode ? "register_title" : "login_title", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)
            Divider()
                .padding(.vertical)
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("server_address", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("http://localhost", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("username", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField(NSLocalizedString("username_placeholder", comment: ""), text: $username)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("password", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField(NSLocalizedString("password_placeholder", comment: ""), text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }
            
            // 로그인/회원가입 버튼
            Button(action: isRegisterMode ? attemptRegister : attemptLogin) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
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
            .padding(.top, 10)
            
            // 모드 전환 버튼
            Button(action: {
                isRegisterMode.toggle()
                showError = false
                errorMessage = ""
            }) {
                Text(isRegisterMode ? 
                     NSLocalizedString("login_title", comment: "") : 
                     NSLocalizedString("register_title", comment: ""))
                    .font(.caption)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(40)
        .frame(width: 400, height: 550)
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
                    if saved {
                        await MainActor.run {
                            isLoading = false
                            onLoginSuccess()
                        }
                    } else {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = NSLocalizedString("config_save_failed", comment: "")
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = NSLocalizedString("login_error", comment: "")
                        showError = true
                    }
                }
            } catch let error as HaNasError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription ?? NSLocalizedString("unknown_error", comment: "")
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("connection_error", comment: "")
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
                    // 회원가입 성공 후 자동 로그인
                    let saved = ConfigManager.shared.saveConfig(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                    
                    if saved {
                        await MainActor.run {
                            isLoading = false
                            onLoginSuccess()
                        }
                    } else {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = NSLocalizedString("config_save_failed", comment: "")
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = NSLocalizedString("register_error", comment: "")
                        showError = true
                    }
                }
            } catch let error as HaNasError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription ?? NSLocalizedString("unknown_error", comment: "")
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("connection_error", comment: "")
                    showError = true
                }
            }
        }
    }
}
