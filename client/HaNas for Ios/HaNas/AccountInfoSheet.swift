import SwiftUI

struct AccountInfoSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var deletePassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // 계정 아이콘
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                // 계정 이름
                if let username = appState.username {
                    Text(username)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // 로그아웃 버튼
                    Button(action: {
                        dismiss()
                        appState.logout()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text(NSLocalizedString("logout_button", comment: "Logout"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // 계정삭제 버튼
                    Button(action: {
                        deletePassword = ""
                        errorMessage = ""
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text(NSLocalizedString("delete_account", comment: "Delete Account"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
        .alert(NSLocalizedString("delete_account_confirm", comment: "Delete Account"), isPresented: $showingDeleteConfirmation) {
            SecureField(NSLocalizedString("password", comment: "Password"), text: $deletePassword)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                deletePassword = ""
                errorMessage = ""
            }
            Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(NSLocalizedString("delete_account_warning", comment: "This action cannot be undone. Please enter your password to confirm."))
        }
        .alert(NSLocalizedString("error", comment: "Error"), isPresented: $showingError) {
            Button(NSLocalizedString("ok", comment: "OK"), role: .cancel) {
                deletePassword = ""
                errorMessage = ""
                showingDeleteConfirmation = true
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func deleteAccount() {
        guard !deletePassword.isEmpty else {
            errorMessage = NSLocalizedString("password_required", comment: "Password is required")
            showingError = true
            return
        }
        
        Task {
            do {
                try await HaNasAPI.shared.deleteAccount(password: deletePassword)
                await MainActor.run {
                    dismiss()
                    appState.logout()
                }
            } catch {
                await MainActor.run {
                    if let hanasError = error as? HaNasError {
                        switch hanasError {
                        case .httpError(let statusCode):
                            if statusCode == 401 {
                                errorMessage = NSLocalizedString("incorrect_password", comment: "Incorrect password")
                            } else {
                                errorMessage = error.localizedDescription
                            }
                        case .serverError(let message):
                            if message.lowercased().contains("password") || message.lowercased().contains("incorrect") {
                                errorMessage = NSLocalizedString("incorrect_password", comment: "Incorrect password")
                            } else {
                                errorMessage = message
                            }
                        default:
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showingError = true
                }
            }
        }
    }
}
